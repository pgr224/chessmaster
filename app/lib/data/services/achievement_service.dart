import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../../core/router/app_router.dart';
import '../../core/theme/app_theme.dart';
import '../models/achievement_model.dart';
import '../models/user_model.dart';
import '../../presentation/blocs/game/game_bloc.dart';
import '../../domain/engine/chess_engine.dart'; // For PieceType
import '../repositories/auth_repository.dart';

class AchievementService {
  final SharedPreferences _prefs;
  final AuthRepository? _authRepository;
  List<Achievement> _achievements = [];
  bool _serverSyncAvailable = true;

  AchievementService(this._prefs, [this._authRepository]) {
    _loadAchievements();
  }

  List<Achievement> get achievements => _achievements;

  void _loadAchievements() {
    final savedData = _prefs.getString('achievements');
    if (savedData != null) {
      try {
        final List<dynamic> saved = jsonDecode(savedData) as List<dynamic>;
        final savedMap = <String, Map<String, dynamic>>{};
        for (final item in saved) {
          if (item is Map<String, dynamic>) {
            savedMap[item['id'] as String] = item;
          }
        }
        _achievements = allAchievements.map((template) {
          final saved = savedMap[template.id];
          if (saved != null) {
            return Achievement.fromSavedJson(saved, template);
          }
          return template;
        }).toList();
      } catch (_) {
        _achievements = List.from(allAchievements);
      }
    } else {
      _achievements = List.from(allAchievements);
    }
  }

  Future<void> _saveAchievements() async {
    final list = _achievements.map((a) => a.toJson()).toList();
    await _prefs.setString('achievements', jsonEncode(list));
  }

  int unlockAchievement(String id, {bool syncToServer = true}) {
    final index = _achievements.indexWhere((a) => a.id == id);
    if (index != -1 && !_achievements[index].isUnlocked) {
      final achievement = _achievements[index];
      _achievements[index] = achievement.copyWith(
        isUnlocked: true,
        unlockedAt: DateTime.now(),
        currentProgress: achievement.requiredCount ?? 0,
      );
      _saveAchievements();
      _showUnlockNotification(_achievements[index]);

      if (syncToServer) {
        _syncUnlockWithServer(_achievements[index]);
      }
      return achievement.points;
    }
    return 0;
  }

  Future<void> _syncUnlockWithServer(Achievement achievement) async {
    if (_authRepository == null || !_serverSyncAvailable) return;

    try {
      final userData = _prefs.getString('user_data');
      if (userData == null) return;

      final userMap = jsonDecode(userData);
      if (userMap is! Map<String, dynamic>) return;
      final userId = userMap['id'] as String?;
      if (userId == null || userId.isEmpty) return;

      final synced = await _authRepository.unlockAchievement(
        userId: userId,
        achievementId: achievement.id,
        points: achievement.points,
      );
      if (!synced) {
        _serverSyncAvailable = false;
      }
    } catch (e) {
      debugPrint('Error syncing achievement to server: $e');
    }
  }

  /// Reconciles local achievements with those stored on the server.
  /// Called after successful login/profile fetch.
  void syncAchievements(List<String> serverAchievementIds) {
    _serverSyncAvailable = true;
    bool changed = false;
    for (final id in serverAchievementIds) {
      final index = _achievements.indexWhere((a) => a.id == id);
      if (index != -1 && !_achievements[index].isUnlocked) {
        _achievements[index] = _achievements[index].copyWith(
          isUnlocked: true,
          unlockedAt: DateTime.now(),
          currentProgress: _achievements[index].requiredCount ?? 0,
        );
        changed = true;
      }
    }

    if (changed) {
      _saveAchievements();
    }
  }

  int updateProgress(String id, int currentProgress, {bool syncToServer = true}) {
    final index = _achievements.indexWhere((a) => a.id == id);
    if (index != -1 && !_achievements[index].isUnlocked) {
      if (currentProgress > _achievements[index].currentProgress) {
        final requiredCount = _achievements[index].requiredCount ?? 1;
        if (currentProgress >= requiredCount) {
          return unlockAchievement(id, syncToServer: syncToServer);
        } else {
          _achievements[index] = _achievements[index].copyWith(
            currentProgress: currentProgress,
          );
          _saveAchievements();
        }
      }
    }
    return 0;
  }

  void _showUnlockNotification(Achievement achievement) {
    final context = AppRouter.rootNavigatorKey.currentContext;
    if (context != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          elevation: 8,
          behavior: SnackBarBehavior.floating,
          backgroundColor: AppTheme.navyCard,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(16),
            side: BorderSide(
              color: AppTheme.goldPrimary.withValues(alpha: 0.5),
              width: 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          margin: const EdgeInsets.only(top: 50, left: 16, right: 16),
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.goldPrimary.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(12),
                ),
                child: Center(
                  child: Text(achievement.icon,
                      style: const TextStyle(fontSize: 24)),
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    Text(
                      'Achievement Unlocked!',
                      style: GoogleFonts.fredoka(
                        color: AppTheme.goldPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.bold,
                        letterSpacing: 0.5,
                      ),
                    ),
                    const SizedBox(height: 2),
                    Text(
                      achievement.title,
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.goldPrimary.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+${achievement.points} XP',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.goldPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
        ),
      );
    }
  }

  int evaluatePostGame(GameState state, UserStats stats, {bool syncToServer = true}) {
    int totalPoints = 0;
    // Beginner
    if (state.moveHistory.isNotEmpty) {
      totalPoints += unlockAchievement('first_move', syncToServer: syncToServer);
    }
    if (stats.wins > 0) {
      totalPoints += unlockAchievement('first_win', syncToServer: syncToServer);
    }
    // first_capture: check that the PLAYER captured an opponent piece
    final playerCapturedOpponent = state.playerColor == PieceColor.white
        ? state.capturedBlack.isNotEmpty
        : state.capturedWhite.isNotEmpty;
    if (playerCapturedOpponent) {
      totalPoints += unlockAchievement('first_capture', syncToServer: syncToServer);
    }
    final playerMoves = state.moveHistory.asMap().entries
        .where((entry) => _isPlayerMove(entry.key, state.playerColor))
        .map((entry) => entry.value)
        .toList();
    final playerNotation = playerMoves
        .map((m) => m.algebraic ?? m.toAlgebraic())
        .join(' ');
    if (playerNotation.contains('+') || playerNotation.contains('#')) {
      totalPoints += unlockAchievement('first_check', syncToServer: syncToServer);
    }
    if (playerMoves.any((m) => m.isCastle)) {
      totalPoints += unlockAchievement('first_castle', syncToServer: syncToServer);
    }
    totalPoints += updateProgress('play_5_games', stats.gamesPlayed, syncToServer: syncToServer);
    if (stats.gamesPlayed >= 5) {
      totalPoints += unlockAchievement('play_5_games', syncToServer: syncToServer);
    }
    totalPoints += updateProgress('play_100_games', stats.gamesPlayed, syncToServer: syncToServer);
    if (stats.gamesPlayed >= 100) {
      totalPoints += unlockAchievement('play_100_games', syncToServer: syncToServer);
    }

    if (state.hintsUsed > 0) {
      totalPoints += unlockAchievement('use_hint', syncToServer: syncToServer);
    }
    // first_undo is evaluated on actual undo, or if they have undos locally

    final isPlayerWin = (state.result == GameResult.whiteWins &&
            state.playerColor == PieceColor.white) ||
        (state.result == GameResult.blackWins &&
            state.playerColor == PieceColor.black);

    if (isPlayerWin) {
      final playerLostQueen = state.playerColor == PieceColor.white
          ? state.capturedWhite.any((p) => p.type == PieceType.queen)
          : state.capturedBlack.any((p) => p.type == PieceType.queen);
      if (playerLostQueen) {
        totalPoints += unlockAchievement('queen_sacrifice', syncToServer: syncToServer);
      }

      // Strategy: no_pieces_lost — works in ALL modes, not just singlePlayer
      if (state.playerColor == PieceColor.white &&
          state.capturedWhite.isEmpty) {
        totalPoints += unlockAchievement('no_pieces_lost', syncToServer: syncToServer);
      } else if (state.playerColor == PieceColor.black &&
          state.capturedBlack.isEmpty) {
        totalPoints += unlockAchievement('no_pieces_lost', syncToServer: syncToServer);
      }
    }
    
    // Bounty Hunter (Capture Opposition Queen in Multiplayer)
    if (state.mode == GameMode.multiplayer) {
      final capturedOppPieces = state.playerColor == PieceColor.white ? state.capturedBlack : state.capturedWhite;
      if (capturedOppPieces.any((p) => p.type == PieceType.queen)) {
         int queensCount = _prefs.getInt('mp_queens_captured') ?? 0;
         queensCount++;
         _prefs.setInt('mp_queens_captured', queensCount);
         totalPoints += updateProgress('bounty_hunter', queensCount, syncToServer: syncToServer);
      }
    }

    // Combat
    totalPoints += updateProgress('win_10', stats.wins, syncToServer: syncToServer);
    totalPoints += updateProgress('win_50', stats.wins, syncToServer: syncToServer);
    totalPoints += updateProgress('win_100', stats.wins, syncToServer: syncToServer);
    if (stats.wins >= 10) {
      totalPoints += unlockAchievement('win_10', syncToServer: syncToServer);
    }
    if (stats.wins >= 50) {
      totalPoints += unlockAchievement('win_50', syncToServer: syncToServer);
    }
    if (stats.wins >= 100) {
      totalPoints += unlockAchievement('win_100', syncToServer: syncToServer);
    }

    if (stats.currentStreak >= 3) {
      totalPoints += unlockAchievement('win_streak_3', syncToServer: syncToServer);
    }
    if (stats.currentStreak >= 5) {
      totalPoints += unlockAchievement('win_streak_5', syncToServer: syncToServer);
    }
    if (stats.currentStreak >= 10) {
      totalPoints += unlockAchievement('win_streak_10', syncToServer: syncToServer);
    }

    // Beating AIs
    if (isPlayerWin && state.mode == GameMode.singlePlayer) {
      if (state.aiDifficulty == AIDifficulty.basic) {
        totalPoints += unlockAchievement('beat_ai_basic', syncToServer: syncToServer);
      }
      if (state.aiDifficulty == AIDifficulty.intermediate) {
        totalPoints += unlockAchievement('beat_ai_intermediate', syncToServer: syncToServer);
      }
      if (state.aiDifficulty == AIDifficulty.advanced ||
          state.aiDifficulty == AIDifficulty.aiMode) {
        totalPoints += unlockAchievement('beat_ai_advanced', syncToServer: syncToServer);
      }
      if (state.aiDifficulty == AIDifficulty.impossible) {
        totalPoints += unlockAchievement('beat_ai_impossible', syncToServer: syncToServer);
      }
    }

    // Accuracy
    if (state.accuracy >= 90.0) {
      totalPoints += unlockAchievement('accuracy_90', syncToServer: syncToServer);
    }
    if (state.accuracy >= 95.0) {
      totalPoints += unlockAchievement('accuracy_95', syncToServer: syncToServer);
    }
    if (state.blunders == 0 && isPlayerWin) {
      totalPoints += unlockAchievement('zero_blunders', syncToServer: syncToServer);
    }

    // Promotions — only credit the PLAYER's promotions, not opponent's
    for (final entry in state.moveHistory.asMap().entries) {
      if (!_isPlayerMove(entry.key, state.playerColor)) continue;
      final move = entry.value;
      if (move.promotion == PieceType.queen) {
        totalPoints += unlockAchievement('pawn_promotion', syncToServer: syncToServer);
      } else if (move.promotion == PieceType.knight) {
        totalPoints += unlockAchievement('promote_knight', syncToServer: syncToServer);
      }
      // En passant detection
      if (move.isEnPassant) {
        totalPoints += unlockAchievement('en_passant', syncToServer: syncToServer);
      }
    }

    // Fast checkmate — MUST be player's win, not opponent's
    if (state.status == GameStatus.checkmate && isPlayerWin) {
      if (state.moveHistory.length <= 40) {
        totalPoints += unlockAchievement('checkmate_fast', syncToServer: syncToServer); // Under 20 full moves
      }
      if (state.moveHistory.length <= 8) {
        totalPoints += unlockAchievement('scholars_mate', syncToServer: syncToServer); // Under 4 full moves
      }
    }

    // Long game — 100+ total moves (200 half-moves)
    if (state.moveHistory.length >= 200) {
      totalPoints += unlockAchievement('long_game', syncToServer: syncToServer);
    }

    // Depth Over Speed — Win a game with 50+ moves (100 half-moves)
    if (isPlayerWin && state.moveHistory.length >= 100) {
      totalPoints += unlockAchievement('tc_depth_over_speed', syncToServer: syncToServer);
    }

    // Social / Multiplayer
    if (stats.multiplayerWins > 0) {
      totalPoints += unlockAchievement('mp_first_win', syncToServer: syncToServer);
    }
    totalPoints += updateProgress('mp_win_10', stats.multiplayerWins, syncToServer: syncToServer);
    totalPoints += updateProgress('mp_win_50', stats.multiplayerWins, syncToServer: syncToServer);
    if (stats.multiplayerWins >= 50) {
      totalPoints += unlockAchievement('mp_win_50', syncToServer: syncToServer);
    }

    // Daily Warrior (Play 3 multiplayer games in one day)
    if (state.mode == GameMode.multiplayer) {
      final lastDate = _prefs.getString('last_mp_date');
      final todayStr = DateTime.now().toIso8601String().split('T')[0];
      int dailyMpCount = _prefs.getInt('daily_mp_count') ?? 0;
      if (lastDate != todayStr) {
        dailyMpCount = 1;
      } else {
        dailyMpCount++;
      }
      _prefs.setString('last_mp_date', todayStr);
      _prefs.setInt('daily_mp_count', dailyMpCount);
      totalPoints += updateProgress('daily_warrior', dailyMpCount, syncToServer: syncToServer);
    }
    
    // Speed Demon (Win any MP game in under 2 minutes)
    if (state.mode == GameMode.multiplayer && isPlayerWin && state.gameDurationSeconds > 0 && state.gameDurationSeconds < 120) {
       totalPoints += unlockAchievement('speed_demon_mp', syncToServer: syncToServer);
    }

    // Win on time — opponent ran out of clock
    if (isPlayerWin && state.gameReason != null && state.gameReason!.toLowerCase().contains('time')) {
      totalPoints += unlockAchievement('win_on_time', syncToServer: syncToServer);
    }

    // Survive low time — Win with less than 10 seconds remaining
    if (isPlayerWin && state.mode != GameMode.twoPlayer) {
      final playerTimeMs = state.playerColor == PieceColor.white
          ? state.whiteTimeMs
          : state.blackTimeMs;
      if (playerTimeMs > 0 && playerTimeMs < 10000) {
        totalPoints += unlockAchievement('survive_low_time', syncToServer: syncToServer);
      }
    }

    // Mastery
    // elo_1200: use > 0 since default starting ELO IS 0 now
    if (stats.eloRating > 0) {
      totalPoints += unlockAchievement('elo_1200', syncToServer: syncToServer);
    }
    if (stats.eloRating >= 1500) {
      totalPoints += unlockAchievement('elo_1500', syncToServer: syncToServer);
    }
    if (stats.eloRating >= 1800) {
      totalPoints += unlockAchievement('elo_1800', syncToServer: syncToServer);
    }
    if (stats.eloRating >= 2000) {
      totalPoints += unlockAchievement('elo_2000', syncToServer: syncToServer);
    }
    if (stats.eloRating >= 2200) {
      totalPoints += unlockAchievement('elo_2200', syncToServer: syncToServer);
    }

    // Puzzles
    if (stats.puzzlesSolved > 0) {
      totalPoints += updateProgress('puzzle_10', stats.puzzlesSolved, syncToServer: syncToServer);
      totalPoints += updateProgress('puzzle_50', stats.puzzlesSolved, syncToServer: syncToServer);
      if (stats.puzzlesSolved >= 10) {
        totalPoints += unlockAchievement('puzzle_10', syncToServer: syncToServer);
      }
      if (stats.puzzlesSolved >= 50) {
        totalPoints += unlockAchievement('puzzle_50', syncToServer: syncToServer);
      }
    }
    if (state.isPuzzleRush) {
      totalPoints += unlockAchievement('puzzle_rush_survive', syncToServer: syncToServer);
    }
    
    // Tournament Star
    if (state.mode == GameMode.multiplayer && state.isTournamentGame) {
       int tournamentGames = _prefs.getInt('tournament_games_played') ?? 0;
       tournamentGames++;
       _prefs.setInt('tournament_games_played', tournamentGames);
       totalPoints += updateProgress('tournament_star', tournamentGames, syncToServer: syncToServer);
    }
    return totalPoints;
  }

  bool _isPlayerMove(int moveIndex, PieceColor? playerColor) {
    if (playerColor == null) return true;
    final isWhiteMove = moveIndex % 2 == 0;
    return (playerColor == PieceColor.white) == isWhiteMove;
  }

  int evaluateSpecialActions(String action, {bool syncToServer = true}) {
    int points = 0;
    if (action == 'undo') {
      points += unlockAchievement('first_undo', syncToServer: syncToServer);
    }
    if (action == 'tutorial') {
      points += unlockAchievement('complete_tutorial', syncToServer: syncToServer);
    }
    if (action == 'donate_xp') {
      points += unlockAchievement('donate_xp', syncToServer: syncToServer);
    }
    if (action == 'chat') {
      int chatCount = _prefs.getInt('chat_messages_sent') ?? 0;
      chatCount++;
      _prefs.setInt('chat_messages_sent', chatCount);
      points += updateProgress('gg_champion', chatCount, syncToServer: syncToServer);
      points += unlockAchievement('chat_game', syncToServer: syncToServer);
    }
    if (action == 'puzzle_rush') {
      points += unlockAchievement('puzzle_rush_survive', syncToServer: syncToServer);
    }
    return points;
  }
}

