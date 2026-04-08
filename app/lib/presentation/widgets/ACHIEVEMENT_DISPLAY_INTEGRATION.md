// ═══════════════════════════════════════════════════════════════════
// ACHIEVEMENT DISPLAY WIDGET INSERTION FOR GAME OVER OVERLAY
// ═══════════════════════════════════════════════════════════════════
// 
// This code should be inserted into game_over_overlay.dart after the
// performance stats section (after the _statItem() widgets).
//
// Add to GameOverOverlay constructor:
// 
//   final List<Achievement>? unlockedAchievements;  // NEW
//   final List<Achievement>? progressAchievements;  // NEW (close to unlock)
//
// ═══════════════════════════════════════════════════════════════════

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/achievement_model.dart';

// Insert this widget after performance stats in the Column children:

// ── ACHIEVEMENT UNLOCKS (NEW) ──
if (unlockedAchievements != null && unlockedAchievements!.isNotEmpty) ...[
  const SizedBox(height: 16),
  _buildAchievementUnlock(unlockedAchievements!),
],

// ── ACHIEVEMENT PROGRESS (NEW) ──
if (progressAchievements != null && progressAchievements!.isNotEmpty) ...[
  const SizedBox(height: 12),
  _buildAchievementProgress(progressAchievements!),
],

// ═══════════════════════════════════════════════════════════════════
// HELPER METHODS TO ADD TO _GameOverOverlayState
// ═══════════════════════════════════════════════════════════════════

/// Build achievement unlock display with animation
Widget _buildAchievementUnlock(List<Achievement> achievements) {
  return Column(
    children: achievements.map((achievement) {
      return Container(
        width: double.infinity,
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              AppTheme.goldPrimary.withValues(alpha: 0.25),
              AppTheme.accentOrange.withValues(alpha: 0.15),
            ],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: AppTheme.goldPrimary.withValues(alpha: 0.6),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: AppTheme.goldPrimary.withValues(alpha: 0.3),
              blurRadius: 25,
              spreadRadius: 2,
            ),
          ],
        ),
        child: Column(
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.goldPrimary.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    achievement.icon,
                    style: const TextStyle(fontSize: 32),
                  ),
                )
                    .animate()
                    .scale(
                      begin: const Offset(0.0, 0.0),
                      duration: 600.ms,
                      curve: Curves.elasticOut,
                    )
                    .rotate(
                      begin: 0,
                      end: 0,
                      duration: 600.ms,
                    ),
                const SizedBox(width: 14),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        '🎉 ACHIEVEMENT UNLOCKED',
                        style: GoogleFonts.fredoka(
                          color: AppTheme.goldPrimary,
                          fontSize: 11,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2,
                        ),
                      ).animate().fadeIn(delay: 200.ms),
                      const SizedBox(height: 4),
                      Text(
                        achievement.title,
                        style: GoogleFonts.fredoka(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w800,
                        ),
                      ).animate().fadeIn(delay: 300.ms).slideX(begin: -0.2),
                      const SizedBox(height: 2),
                      Text(
                        achievement.description,
                        style: GoogleFonts.baloo2(
                          color: AppTheme.textSecondary,
                          fontSize: 12,
                          fontWeight: FontWeight.w500,
                        ),
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                      ).animate().fadeIn(delay: 350.ms),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            // Points earned
            Container(
              width: double.infinity,
              padding: const EdgeInsets.symmetric(vertical: 8),
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.center,
                children: [
                  Text(
                    '⭐ +${achievement.points} Achievement Points',
                    style: GoogleFonts.fredoka(
                      color: AppTheme.accentCyan,
                      fontSize: 13,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ],
              ),
            )
                .animate()
                .fadeIn(delay: 400.ms)
                .slideY(begin: 0.1),
          ],
        ),
      )
          .animate()
          .fadeIn(duration: 500.ms)
          .slideY(begin: 0.3, curve: Curves.easeOut);
    }).toList(),
  );
}

/// Build achievement progress display
Widget _buildAchievementProgress(List<Achievement> achievements) {
  return Container(
    width: double.infinity,
    padding: const EdgeInsets.all(14),
    decoration: BoxDecoration(
      color: AppTheme.skyBlue.withValues(alpha: 0.08),
      borderRadius: BorderRadius.circular(14),
      border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.2)),
    ),
    child: Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text(
          '📈 Getting Close To Unlocking...',
          style: GoogleFonts.fredoka(
            color: AppTheme.skyBlue,
            fontSize: 12,
            fontWeight: FontWeight.w700,
            letterSpacing: 0.5,
          ),
        ),
        const SizedBox(height: 10),
        ...achievements.map((achievement) {
          final progress = achievement.progressPercent;
          final remaining = (achievement.requiredCount ?? 1) -
              achievement.currentProgress;

          return Padding(
            padding: const EdgeInsets.only(bottom: 8),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Text(
                      achievement.icon,
                      style: const TextStyle(fontSize: 18),
                    ),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            achievement.title,
                            style: GoogleFonts.fredoka(
                              color: AppTheme.textPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.w600,
                            ),
                          ),
                          Text(
                            '${achievement.currentProgress}/${achievement.requiredCount}',
                            style: GoogleFonts.baloo2(
                              color: AppTheme.textSecondary,
                              fontSize: 11,
                              fontWeight: FontWeight.w500,
                            ),
                          ),
                        ],
                      ),
                    ),
                    Text(
                      '$remaining more',
                      style: GoogleFonts.fredoka(
                        color: AppTheme.accentCyan,
                        fontSize: 11,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
                const SizedBox(height: 4),
                ClipRRect(
                  borderRadius: BorderRadius.circular(4),
                  child: LinearProgressIndicator(
                    value: progress,
                    minHeight: 4,
                    backgroundColor:
                        AppTheme.textMuted.withValues(alpha: 0.2),
                    valueColor: AlwaysStoppedAnimation<Color>(
                      AppTheme.accentCyan.withValues(
                        alpha: progress > 0.75 ? 1.0 : 0.7,
                      ),
                    ),
                  ),
                ),
              ],
            ),
          );
        }).toList(),
      ],
    ),
  ).animate().fadeIn(delay: 600.ms).slideX(begin: 0.1);
}

// ═══════════════════════════════════════════════════════════════════
// IMPLEMENTATION IN game_over_overlay.dart CONSTRUCTOR
// ═══════════════════════════════════════════════════════════════════
//
// Add these parameters to the GameOverOverlay constructor:
//
//   final List<Achievement>? unlockedAchievements;
//   final List<Achievement>? progressAchievements;
//
// In initState or wherever GameOverOverlay is called, pass:
//
//   GameOverOverlay(
//     // existing params...
//     unlockedAchievements: [
//       // Pass achievements unlocked in THIS game
//       Achievement(id: 'mp_matchmaker', ...)
//     ],
//     progressAchievements: [
//       // Pass achievements that are close to unlocking
//       Achievement(id: 'mp_ladder_climber', currentProgress: 3, requiredCount: 5)
//     ],
//   )
//
// ═══════════════════════════════════════════════════════════════════
// EXAMPLE USAGE IN GAME SCREEN
// ═══════════════════════════════════════════════════════════════════
//
// Future<void> _showGameOver() async {
//   final achievements = await _checkAchievementUnlocks(gameResult);
//   final progressingAchievements = await _getNearAchievements();
//
//   if (!mounted) return;
//
//   showModalBottomSheet(
//     context: context,
//     builder: (ctx) => GameOverOverlay(
//       result: gameResult,
//       onPlayAgain: _playAgain,
//       onGoHome: _goHome,
//       onShare: _share,
//       unlockedAchievements: achievements,
//       progressAchievements: progressingAchievements,
//       // ... other parameters
//     ),
//   );
// }
//
// ═══════════════════════════════════════════════════════════════════
