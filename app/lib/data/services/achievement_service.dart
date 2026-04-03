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

class AchievementService {
  final SharedPreferences _prefs;
  List<Achievement> _achievements = [];

  AchievementService(this._prefs) {
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
              color: AppTheme.goldPrimary.withOpacity(0.5),
              width: 2,
            ),
          ),
          padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
          duration: const Duration(seconds: 4),
          content: Row(
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: AppTheme.goldPrimary.withOpacity(0.2),
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
                  color: AppTheme.goldPrimary.withOpacity(0.15),
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
    if (state.moveHistory.isNotEmpty) unlockAchievement('first_move');
    if (stats.wins > 0) unlockAchievement('first_win');
    if (state.capturedWhite.isNotEmpty || state.capturedBlack.isNotEmpty) {
      unlockAchievement('first_capture');
    }
    final checkString = state.moveHistory.map((m) => m.toAlgebraic()).join(' ');
    if (checkString.contains('+') || checkString.contains('#')) {
      unlockAchievement('first_check');
    }
    if (checkString.contains('O-O') || checkString.contains('O-O-O')) {
      unlockAchievement('first_castle');
    }
    updateProgress('play_5_games', stats.gamesPlayed);
    if (stats.gamesPlayed >= 5) unlockAchievement('play_5_games');
    updateProgress('play_100_games', stats.gamesPlayed);
    if (stats.gamesPlayed >= 100) unlockAchievement('play_100_games');

    if (state.hintsUsed > 0) unlockAchievement('use_hint');
    // first_undo is evaluated on actual undo, or if they have undos locally

    // Combat
    updateProgress('win_10', stats.wins);
    updateProgress('win_50', stats.wins);
    updateProgress('win_100', stats.wins);
    if (stats.wins >= 10) unlockAchievement('win_10');
    if (stats.wins >= 50) unlockAchievement('win_50');
    if (stats.wins >= 100) unlockAchievement('win_100');

    if (stats.currentStreak >= 3) unlockAchievement('win_streak_3');
    if (stats.currentStreak >= 5) unlockAchievement('win_streak_5');
    if (stats.currentStreak >= 10) unlockAchievement('win_streak_10');

    // Beating AIs
    final isPlayerWin = (state.result == GameResult.whiteWins &&
            state.playerColor == PieceColor.white) ||
        (state.result == GameResult.blackWins &&
            state.playerColor == PieceColor.black);

    if (isPlayerWin && state.mode == GameMode.singlePlayer) {
      // Player won!
      if (state.aiDifficulty == AIDifficulty.basic)
        unlockAchievement('beat_ai_basic');
      if (state.aiDifficulty == AIDifficulty.intermediate)
        unlockAchievement('beat_ai_intermediate');
      if (state.aiDifficulty == AIDifficulty.advanced)
        unlockAchievement('beat_ai_advanced');
      if (state.aiDifficulty == AIDifficulty.impossible)
        unlockAchievement('beat_ai_impossible');

      // Strategy
      if (state.playerColor == PieceColor.white &&
          state.capturedWhite.isEmpty) {
        unlockAchievement('no_pieces_lost');
      } else if (state.playerColor == PieceColor.black &&
          state.capturedBlack.isEmpty) {
        unlockAchievement('no_pieces_lost');
      }
    }

    // Accuracy
    if (state.accuracy >= 90.0) unlockAchievement('accuracy_90');
    if (state.accuracy >= 95.0) unlockAchievement('accuracy_95');
    if (state.blunders == 0 && isPlayerWin) {
      unlockAchievement('zero_blunders');
    }

    // Promotions
    for (final move in state.moveHistory) {
      if (move.promotion == PieceType.queen) {
        unlockAchievement('pawn_promotion');
      } else if (move.promotion == PieceType.knight) {
        unlockAchievement('promote_knight');
      }
    }

    // Fast checkmate
    if (state.status == GameStatus.checkmate) {
      if (state.moveHistory.length <= 40)
        unlockAchievement('checkmate_fast'); // Under 20 full moves
      if (state.moveHistory.length <= 8)
        unlockAchievement('scholars_mate'); // Under 4 full moves
    }

    // Social / Multiplayer
    if (stats.multiplayerWins > 0) unlockAchievement('mp_first_win');
    updateProgress('mp_win_10', stats.multiplayerWins);
    updateProgress('mp_win_50', stats.multiplayerWins);
    if (stats.multiplayerWins >= 10) unlockAchievement('mp_win_10');
    if (stats.multiplayerWins >= 50) unlockAchievement('mp_win_50');

    // Mastery
    if (stats.eloRating >= 1200) unlockAchievement('elo_1200');
    if (stats.eloRating >= 1500) unlockAchievement('elo_1500');
    if (stats.eloRating >= 1800) unlockAchievement('elo_1800');
    if (stats.eloRating >= 2000) unlockAchievement('elo_2000');
    if (stats.eloRating >= 2200) unlockAchievement('elo_2200');

    // Puzzles
    if (stats.puzzlesSolved > 0) {
      updateProgress('puzzle_10', stats.puzzlesSolved);
      updateProgress('puzzle_50', stats.puzzlesSolved);
      if (stats.puzzlesSolved >= 10) unlockAchievement('puzzle_10');
      if (stats.puzzlesSolved >= 50) unlockAchievement('puzzle_50');
    }
    if (state.isPuzzleRush) {
      unlockAchievement('puzzle_rush_survive');
    }
  }

  void evaluateSpecialActions(String action) {
    if (action == 'undo') unlockAchievement('first_undo');
    if (action == 'tutorial') unlockAchievement('complete_tutorial');
    if (action == 'donate_xp') unlockAchievement('donate_xp');
    if (action == 'chat') unlockAchievement('chat_game');
    if (action == 'puzzle_rush') unlockAchievement('puzzle_rush_survive');
  }
}
