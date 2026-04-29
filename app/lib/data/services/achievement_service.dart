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

  void unlockAchievement(String id) {
    final index = _achievements.indexWhere((a) => a.id == id);
    if (index != -1 && !_achievements[index].isUnlocked) {
      _achievements[index] = _achievements[index].copyWith(
        isUnlocked: true,
        unlockedAt: DateTime.now(),
        currentProgress: _achievements[index].requiredCount ?? 0,
      );
      _saveAchievements();
      _showUnlockNotification(_achievements[index]);

      // NEW: Sync with server if repository is available
      _syncUnlockWithServer(_achievements[index]);
    }
  }

  Future<void> _syncUnlockWithServer(Achievement achievement) async {
    if (_authRepository == null) return;

    try {
      final userData = _prefs.getString('user_data');
      if (userData == null) return;

      final userMap = jsonDecode(userData);
      final userId = userMap['id'] as String;

      await _authRepository.unlockAchievement(
        userId: userId,
        achievementId: achievement.id,
        points: achievement.points,
      );
    } catch (e) {
      debugPrint('Error syncing achievement to server: $e');
    }
  }

  /// Reconciles local achievements with those stored on the server.
  /// Called after successful login/profile fetch.
  void syncAchievements(List<String> serverAchievementIds) {
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

  void updateProgress(String id, int currentProgress) {
    final index = _achievements.indexWhere((a) => a.id == id);
    if (index != -1 && !_achievements[index].isUnlocked) {
      if (currentProgress > _achievements[index].currentProgress) {
        final requiredCount = _achievements[index].requiredCount ?? 1;
        if (currentProgress >= requiredCount) {
          unlockAchievement(id);
        } else {
          _achievements[index] = _achievements[index].copyWith(
            currentProgress: currentProgress,
          );
          _saveAchievements();
        }
      }
    }
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

  void evaluatePostGame(GameState state, UserStats stats) {
    // Beginner
    if (state.moveHistory.isNotEmpty) {
      unlockAchievement('first_move');
    }
    if (stats.wins > 0) {
      unlockAchievement('first_win');
    }
    // first_capture: check that the PLAYER captured an opponent piece
    final playerCapturedOpponent = state.playerColor == PieceColor.white
        ? state.capturedBlack.isNotEmpty
        : state.capturedWhite.isNotEmpty;
    if (playerCapturedOpponent) {
      unlockAchievement('first_capture');
    }
    final playerMoves = state.moveHistory.asMap().entries
        .where((entry) => _isPlayerMove(entry.key, state.playerColor))
        .map((entry) => entry.value)
        .toList();
    final playerNotation = playerMoves
        .map((m) => m.algebraic ?? m.toAlgebraic())
        .join(' ');
    if (playerNotation.contains('+') || playerNotation.contains('#')) {
      unlockAchievement('first_check');
    }
    if (playerMoves.any((m) => m.isCastle)) {
      unlockAchievement('first_castle');
    }
    updateProgress('play_5_games', stats.gamesPlayed);
    if (stats.gamesPlayed >= 5) {
      unlockAchievement('play_5_games');
    }
    updateProgress('play_100_games', stats.gamesPlayed);
    if (stats.gamesPlayed >= 100) {
      unlockAchievement('play_100_games');
    }

    if (state.hintsUsed > 0) {
      unlockAchievement('use_hint');
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
        unlockAchievement('queen_sacrifice');
      }

      // Strategy: no_pieces_lost — works in ALL modes, not just singlePlayer
      if (state.playerColor == PieceColor.white &&
          state.capturedWhite.isEmpty) {
        unlockAchievement('no_pieces_lost');
      } else if (state.playerColor == PieceColor.black &&
          state.capturedBlack.isEmpty) {
        unlockAchievement('no_pieces_lost');
      }
    }
    
    // Bounty Hunter (Capture Opposition Queen in Multiplayer)
    if (state.mode == GameMode.multiplayer) {
      final capturedOppPieces = state.playerColor == PieceColor.white ? state.capturedBlack : state.capturedWhite;
      if (capturedOppPieces.any((p) => p.type == PieceType.queen)) {
         int queensCount = _prefs.getInt('mp_queens_captured') ?? 0;
         queensCount++;
         _prefs.setInt('mp_queens_captured', queensCount);
         updateProgress('bounty_hunter', queensCount);
      }
    }

    // Combat
    updateProgress('win_10', stats.wins);
    updateProgress('win_50', stats.wins);
    updateProgress('win_100', stats.wins);
    if (stats.wins >= 10) {
      unlockAchievement('win_10');
    }
    if (stats.wins >= 50) {
      unlockAchievement('win_50');
    }
    if (stats.wins >= 100) {
      unlockAchievement('win_100');
    }

    if (stats.currentStreak >= 3) {
      unlockAchievement('win_streak_3');
    }
    if (stats.currentStreak >= 5) {
      unlockAchievement('win_streak_5');
    }
    if (stats.currentStreak >= 10) {
      unlockAchievement('win_streak_10');
    }

    // Beating AIs
    if (isPlayerWin && state.mode == GameMode.singlePlayer) {
      if (state.aiDifficulty == AIDifficulty.basic) {
        unlockAchievement('beat_ai_basic');
      }
      if (state.aiDifficulty == AIDifficulty.intermediate) {
        unlockAchievement('beat_ai_intermediate');
      }
      if (state.aiDifficulty == AIDifficulty.advanced) {
        unlockAchievement('beat_ai_advanced');
      }
      if (state.aiDifficulty == AIDifficulty.impossible) {
        unlockAchievement('beat_ai_impossible');
      }
    }

    // Accuracy
    if (state.accuracy >= 90.0) {
      unlockAchievement('accuracy_90');
    }
    if (state.accuracy >= 95.0) {
      unlockAchievement('accuracy_95');
    }
    if (state.blunders == 0 && isPlayerWin) {
      unlockAchievement('zero_blunders');
    }

    // Promotions — only credit the PLAYER's promotions, not opponent's
    for (final entry in state.moveHistory.asMap().entries) {
      if (!_isPlayerMove(entry.key, state.playerColor)) continue;
      final move = entry.value;
      if (move.promotion == PieceType.queen) {
        unlockAchievement('pawn_promotion');
      } else if (move.promotion == PieceType.knight) {
        unlockAchievement('promote_knight');
      }
      // En passant detection
      if (move.isEnPassant) {
        unlockAchievement('en_passant');
      }
    }

    // Fast checkmate — MUST be player's win, not opponent's
    if (state.status == GameStatus.checkmate && isPlayerWin) {
      if (state.moveHistory.length <= 40) {
        unlockAchievement('checkmate_fast'); // Under 20 full moves
      }
      if (state.moveHistory.length <= 8) {
        unlockAchievement('scholars_mate'); // Under 4 full moves
      }
    }

    // Long game — 100+ total moves (200 half-moves)
    if (state.moveHistory.length >= 200) {
      unlockAchievement('long_game');
    }

    // Depth Over Speed — Win a game with 50+ moves (100 half-moves)
    if (isPlayerWin && state.moveHistory.length >= 100) {
      unlockAchievement('tc_depth_over_speed');
    }

    // Social / Multiplayer
    if (stats.multiplayerWins > 0) {
      unlockAchievement('mp_first_win');
    }
    updateProgress('mp_win_10', stats.multiplayerWins);
    updateProgress('mp_win_50', stats.multiplayerWins);
    if (stats.multiplayerWins >= 50) {
      unlockAchievement('mp_win_50');
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
      updateProgress('daily_warrior', dailyMpCount);
    }
    
    // Speed Demon (Win any MP game in under 2 minutes)
    if (state.mode == GameMode.multiplayer && isPlayerWin && state.gameDurationSeconds > 0 && state.gameDurationSeconds < 120) {
       unlockAchievement('speed_demon_mp');
    }

    // Win on time — opponent ran out of clock
    if (isPlayerWin && state.gameReason != null && state.gameReason!.toLowerCase().contains('time')) {
      unlockAchievement('win_on_time');
    }

    // Survive low time — Win with less than 10 seconds remaining
    if (isPlayerWin && state.mode != GameMode.twoPlayer) {
      final playerTimeMs = state.playerColor == PieceColor.white
          ? state.whiteTimeMs
          : state.blackTimeMs;
      if (playerTimeMs > 0 && playerTimeMs < 10000) {
        unlockAchievement('survive_low_time');
      }
    }

    // Mastery
    // elo_1200: use > 1200 since default starting ELO IS 1200
    if (stats.eloRating > 1200) {
      unlockAchievement('elo_1200');
    }
    if (stats.eloRating >= 1500) {
      unlockAchievement('elo_1500');
    }
    if (stats.eloRating >= 1800) {
      unlockAchievement('elo_1800');
    }
    if (stats.eloRating >= 2000) {
      unlockAchievement('elo_2000');
    }
    if (stats.eloRating >= 2200) {
      unlockAchievement('elo_2200');
    }

    // Puzzles
    if (stats.puzzlesSolved > 0) {
      updateProgress('puzzle_10', stats.puzzlesSolved);
      updateProgress('puzzle_50', stats.puzzlesSolved);
      if (stats.puzzlesSolved >= 10) {
        unlockAchievement('puzzle_10');
      }
      if (stats.puzzlesSolved >= 50) {
        unlockAchievement('puzzle_50');
      }
    }
    if (state.isPuzzleRush) {
      unlockAchievement('puzzle_rush_survive');
    }
    
    // Tournament Star
    if (state.mode == GameMode.multiplayer && state.isTournamentGame) {
       int tournamentGames = _prefs.getInt('tournament_games_played') ?? 0;
       tournamentGames++;
       _prefs.setInt('tournament_games_played', tournamentGames);
       updateProgress('tournament_star', tournamentGames);
    }
  }

  bool _isPlayerMove(int moveIndex, PieceColor? playerColor) {
    if (playerColor == null) return true;
    final isWhiteMove = moveIndex % 2 == 0;
    return (playerColor == PieceColor.white) == isWhiteMove;
  }

  void evaluateSpecialActions(String action) {
    if (action == 'undo') {
      unlockAchievement('first_undo');
    }
    if (action == 'tutorial') {
      unlockAchievement('complete_tutorial');
    }
    if (action == 'donate_xp') {
      unlockAchievement('donate_xp');
    }
    if (action == 'chat') {
      int chatCount = _prefs.getInt('chat_messages_sent') ?? 0;
      chatCount++;
      _prefs.setInt('chat_messages_sent', chatCount);
      updateProgress('gg_champion', chatCount);
      unlockAchievement('chat_game');
    }
    if (action == 'puzzle_rush') {
      unlockAchievement('puzzle_rush_survive');
    }
  }
}

