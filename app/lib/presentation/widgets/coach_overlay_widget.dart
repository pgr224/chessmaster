import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';
import '../../data/models/coach_model.dart';

/// A premium, animated AI Coach overlay that appears after each move
/// with classification badge, feedback message, and contextual explanation.
class CoachOverlayWidget extends StatefulWidget {
  final CoachFeedback? feedback;
  final VoidCallback? onDismiss;
  final VoidCallback? onUndo;
  final CoachPersonality personality;
  final bool compact; // true = during game, false = post-game detail

  const CoachOverlayWidget({
    super.key,
    required this.feedback,
    this.onDismiss,
    this.onUndo,
    this.personality = CoachPersonality.friendly,
    this.compact = true,
  });

  @override
  State<CoachOverlayWidget> createState() => _CoachOverlayWidgetState();
}

class _CoachOverlayWidgetState extends State<CoachOverlayWidget> {
  Timer? _autoDismissTimer;

  @override
  void initState() {
    super.initState();
    _startAutoDismiss();
  }

  @override
  void didUpdateWidget(CoachOverlayWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (widget.feedback != oldWidget.feedback && widget.feedback != null) {
      _startAutoDismiss();
    }
  }

  void _startAutoDismiss() {
    _autoDismissTimer?.cancel();
    if (widget.compact && widget.feedback != null) {
      // Base: 4s. Add 1s for every 10 words in explanation for psychological comfort.
      int wordCount = widget.feedback!.explanation?.split(' ').length ?? 0;
      int extraSeconds = (wordCount / 10).floor();

      final duration = Duration(seconds: (4 + extraSeconds).clamp(4, 10));

      _autoDismissTimer = Timer(duration, () {
        if (mounted) widget.onDismiss?.call();
      });
    }
  }

  @override
  void dispose() {
    _autoDismissTimer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final feedback = widget.feedback;
    if (feedback == null) return const SizedBox.shrink();

    return Positioned(
      // Positioning adapted to avoid obstructing central gameboard area
      top: MediaQuery.of(context).size.height * 0.12,
      left: 16,
      right: 16,
      child: Center(
        child: GestureDetector(
          onTap: widget.onDismiss,
          child: _buildCard(feedback),
        ),
      ),
    );
  }

  Widget _buildCard(CoachFeedback feedback) {
    final classification = feedback.classification;
    final color = _classificationColor(classification);
    final bgColor = color.withValues(alpha: 0.15);
    final borderColor = color.withValues(alpha: 0.6);

    return Container(
      constraints: const BoxConstraints(maxWidth: 400),
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.navyCard.withValues(alpha: 0.95),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: borderColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.3),
            blurRadius: 20,
            spreadRadius: 2,
            offset: const Offset(0, 4),
          ),
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 10,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Top row: badge + message
          Row(
            children: [
              // Classification Badge
              _buildBadge(classification, color, bgColor),
              const SizedBox(width: 12),
              // Main message
              Expanded(
                child: Text(
                  feedback.message,
                  style: GoogleFonts.fredoka(
                    color: AppTheme.textPrimary,
                    fontSize: 15,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              // Coach avatar
              Text(
                widget.personality.avatar,
                style: const TextStyle(fontSize: 28),
              ),
            ],
          ),
          // Explanation (if available)
          if (feedback.explanation != null) ...[
            const SizedBox(height: 8),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: bgColor,
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: borderColor.withValues(alpha: 0.3)),
              ),
              child: Text(
                feedback.explanation!,
                style: GoogleFonts.baloo2(
                  color: AppTheme.textSecondary,
                  fontSize: 13,
                  height: 1.4,
                ),
              ),
            ),
          ],
          // Undo button for blunders
          if (feedback.showUndo && widget.onUndo != null) ...[
            const SizedBox(height: 10),
            Row(
              children: [
                Expanded(
                  child: _miniButton(
                    icon: Icons.undo_rounded,
                    label: 'TAKE BACK',
                    color: AppTheme.goldPrimary,
                    onTap: widget.onUndo!,
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _miniButton(
                    icon: Icons.arrow_forward_rounded,
                    label: 'CONTINUE',
                    color: AppTheme.textMuted,
                    onTap: () => widget.onDismiss?.call(),
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    )
        .animate()
        .slideY(begin: -0.3, duration: 350.ms, curve: Curves.easeOutCubic)
        .fadeIn(duration: 250.ms)
        .then()
        .shimmer(
          duration: 800.ms,
          color:
              _classificationColor(feedback.classification).withValues(alpha: 0.15),
        );
  }

  Widget _buildBadge(MoveClassification c, Color color, Color bgColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: bgColor,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.5)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(c.emoji, style: const TextStyle(fontSize: 16)),
          const SizedBox(width: 4),
          Text(
            c.label,
            style: GoogleFonts.fredoka(
              color: color,
              fontSize: 11,
              fontWeight: FontWeight.w700,
              letterSpacing: 0.5,
            ),
          ),
        ],
      ),
    );
  }

  Widget _miniButton({
    required IconData icon,
    required String label,
    required Color color,
    required VoidCallback onTap,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: color.withValues(alpha: 0.3)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: color, size: 16),
            const SizedBox(width: 6),
            Text(
              label,
              style: GoogleFonts.fredoka(
                color: color,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ),
      ),
    );
  }

  Color _classificationColor(MoveClassification c) => switch (c) {
        MoveClassification.brilliant => const Color(0xFFA855F7), // purple
        MoveClassification.best => const Color(0xFF22C55E), // green
        MoveClassification.good => const Color(0xFF4ECDC4), // teal
        MoveClassification.needsImprovement => const Color(0xFFF59E0B), // amber
        MoveClassification.mistake => const Color(0xFFF97316), // orange
        MoveClassification.blunder => const Color(0xFFEF4444), // red
      };
}

/// Widget displaying the hint result with explanation and best move.
class HintOverlayWidget extends StatelessWidget {
  final HintResult hint;
  final VoidCallback? onDismiss;
  final VoidCallback? onNextLevel;

  const HintOverlayWidget({
    super.key,
    required this.hint,
    this.onDismiss,
    this.onNextLevel,
  });

  @override
  Widget build(BuildContext context) {
    return Positioned(
      bottom: 160,
      left: 20,
      right: 20,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 380),
          padding: const EdgeInsets.all(16),
          decoration: BoxDecoration(
            color: AppTheme.navyCard.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
              color: AppTheme.skyBlue.withValues(alpha: 0.6),
              width: 2,
            ),
            boxShadow: [
              BoxShadow(
                color: AppTheme.skyBlue.withValues(alpha: 0.2),
                blurRadius: 20,
                spreadRadius: 2,
              ),
              BoxShadow(
                color: Colors.black.withValues(alpha: 0.4),
                blurRadius: 15,
                offset: const Offset(0, 8),
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Header with Progress
              Row(
                children: [
                  Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.skyBlue.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: const Icon(
                      Icons.lightbulb_rounded,
                      color: AppTheme.skyBlue,
                      size: 22,
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          'AI COACH HINT',
                          style: GoogleFonts.fredoka(
                            color: AppTheme.skyBlue,
                            fontSize: 11,
                            fontWeight: FontWeight.w700,
                            letterSpacing: 1.2,
                          ),
                        ),
                        const SizedBox(height: 4),
                        // Level Indicator
                        Row(
                          children: List.generate(4, (index) {
                            final isActive = index < hint.currentLevel;
                            return Container(
                              width: 30,
                              height: 4,
                              margin: const EdgeInsets.only(right: 4),
                              decoration: BoxDecoration(
                                color: isActive
                                    ? AppTheme.skyBlue
                                    : Colors.white.withValues(alpha: 0.1),
                                borderRadius: BorderRadius.circular(2),
                              ),
                            );
                          }),
                        ),
                      ],
                    ),
                  ),
                  if (hint.xpCost > 0)
                    Text(
                      '-${hint.xpCost} XP',
                      style: GoogleFonts.fredoka(
                        color: AppTheme.accentRed.withValues(alpha: 0.8),
                        fontSize: 10,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  const SizedBox(width: 10),
                  GestureDetector(
                    onTap: onDismiss,
                    child: Container(
                      padding: const EdgeInsets.all(4),
                      decoration: BoxDecoration(
                        color: Colors.white.withValues(alpha: 0.1),
                        shape: BoxShape.circle,
                      ),
                      child: const Icon(
                        Icons.close_rounded,
                        color: AppTheme.textMuted,
                        size: 18,
                      ),
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 18),
              // Hint Content
              Text(
                hint.currentHintText,
                style: GoogleFonts.baloo2(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600,
                  height: 1.4,
                ),
              )
                  .animate(key: ValueKey(hint.currentLevel))
                  .fadeIn()
                  .slideX(begin: 0.1),

              const SizedBox(height: 16),

              // Actions
              Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (hint.currentLevel < 4)
                    TextButton.icon(
                      onPressed: onNextLevel,
                      icon: const Icon(Icons.add_circle_outline_rounded,
                          size: 18),
                      label: Text(
                        'NEED MORE?',
                        style: GoogleFonts.fredoka(fontWeight: FontWeight.w700),
                      ),
                      style: TextButton.styleFrom(
                        foregroundColor: AppTheme.skyBlue,
                        padding: const EdgeInsets.symmetric(horizontal: 16),
                      ),
                    ),
                  if (hint.currentLevel == 4)
                    Text(
                      'Full Move Revealed!',
                      style: GoogleFonts.baloo2(
                        color: AppTheme.goldPrimary,
                        fontSize: 12,
                        fontWeight: FontWeight.w700,
                      ),
                    ).animate().shimmer(),
                ],
              ),

              // Pattern badge (only for levels 1 & 4)
              if (hint.pattern != TacticalPattern.none &&
                  (hint.currentLevel == 1 || hint.currentLevel == 4)) ...[
                const SizedBox(height: 12),
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  decoration: BoxDecoration(
                    color: AppTheme.goldPrimary.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(
                      color: AppTheme.goldPrimary.withValues(alpha: 0.3),
                    ),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(hint.pattern.emoji,
                          style: const TextStyle(fontSize: 14)),
                      const SizedBox(width: 8),
                      Text(
                        hint.pattern.label,
                        style: GoogleFonts.baloo2(
                          color: AppTheme.goldPrimary,
                          fontSize: 12,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                    ],
                  ),
                ),
              ],
            ],
          ),
        )
            .animate()
            .scale(
                begin: const Offset(0.95, 0.95),
                duration: 250.ms,
                curve: Curves.easeOutBack)
            .fadeIn(duration: 200.ms),
      ),
    );
  }
}

/// Small persistent evaluation indicator at the side of the board.
class CoachEvalIndicator extends StatelessWidget {
  final MoveClassification? lastClassification;
  final int moveNumber;

  const CoachEvalIndicator({
    super.key,
    this.lastClassification,
    this.moveNumber = 0,
  });

  @override
  Widget build(BuildContext context) {
    if (lastClassification == null || moveNumber == 0) {
      return const SizedBox.shrink();
    }

    final color = _classColor(lastClassification!);

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(lastClassification!.emoji, style: const TextStyle(fontSize: 12)),
          const SizedBox(width: 4),
          Text(
            lastClassification!.label,
            style: GoogleFonts.fredoka(
              color: color,
              fontSize: 10,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    ).animate().fadeIn(duration: 200.ms).scale(
          begin: const Offset(0.8, 0.8),
          duration: 200.ms,
        );
  }

  Color _classColor(MoveClassification c) => switch (c) {
        MoveClassification.brilliant => const Color(0xFFA855F7),
        MoveClassification.best => const Color(0xFF22C55E),
        MoveClassification.good => const Color(0xFF4ECDC4),
        MoveClassification.needsImprovement => const Color(0xFFF59E0B),
        MoveClassification.mistake => const Color(0xFFF97316),
        MoveClassification.blunder => const Color(0xFFEF4444),
      };
}

