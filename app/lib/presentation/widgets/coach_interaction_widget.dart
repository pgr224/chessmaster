import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:chess_master/presentation/blocs/game/game_bloc.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/data/models/coach_model.dart';
import './animated_robot_coach.dart';

class CoachInteractionWidget extends StatelessWidget {
  final GameState state;

  const CoachInteractionWidget({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    final isThinking = state.isAIThinking;
    final feedback = state.coachFeedback;
    final hint = state.activeHint;
    final aiMessage = state.aiMessage;

    // Priority: Thinking > Hint > Feedback
    String title = '';
    String? subtext;
    Color accentColor = Colors.blueAccent;
    bool show = false;

    if (isThinking) {
      title = aiMessage ?? 'Hmm, let me think... 🧐';
      accentColor = Colors.cyanAccent;
      show = true;
    } else if (hint != null) {
      title = '${hint.currentLevelEmoji} ${hint.currentLevelLabel}';
      subtext = hint.currentHintText;
      accentColor = _hintLevelColor(hint.currentLevel);
      show = true;
    } else if (feedback != null) {
      title = feedback.message;
      subtext = feedback.explanation;
      accentColor = feedback.isNegative
          ? Colors.orangeAccent
          : (feedback.classification.index <= 1
              ? Colors.purpleAccent
              : Colors.greenAccent);
      show = true;
    }

    if (!show) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 🤖 ANIMATED ROBOT AVATAR
        AnimatedRobotCoach(
          isThinking: isThinking,
          isHint: hint != null,
          classification: feedback?.classification,
        )
            .animate()
            .slideX(
                begin: -0.5, end: 0, duration: 400.ms, curve: Curves.easeOutBack)
            .fadeIn(),

        const SizedBox(width: 4),

        // 💬 TALK BUBBLE
        Flexible(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Main bubble
              _buildTalkBubble(
                context: context,
                title: title,
                subtext: subtext,
                accentColor: accentColor,
                hint: hint,
                isThinking: isThinking,
              ),
              // XP upgrade bar — only when hint is active
              if (hint != null && !isThinking)
                _buildHintUpgradeBar(context, hint),
            ],
          ),
        ),
      ],
    );
  }

  Widget _buildTalkBubble({
    required BuildContext context,
    required String title,
    required String? subtext,
    required Color accentColor,
    required HintResult? hint,
    required bool isThinking,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.97),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(24),
          topRight: Radius.circular(24),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(24),
        ),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.6),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.15),
            blurRadius: 20,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level pill badge — only for hints
          if (hint != null) ...[
            _buildLevelPill(hint, accentColor),
            const SizedBox(height: 8),
          ],

          // Title
          Text(
            title,
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontSize: 14,
              fontWeight: FontWeight.w800,
              letterSpacing: 0.3,
            ),
          ),

          // Hint text / explanation
          if (subtext != null) ...[
            const SizedBox(height: 6),
            Text(
              subtext,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.88),
                fontSize: 13,
                height: 1.45,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // Dismiss hint row
          if (hint != null) ...[
            const SizedBox(height: 8),
            GestureDetector(
              onTap: () => context.read<GameBloc>().add(const GameDismissHintEvent()),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.close_rounded,
                      size: 12, color: Colors.white38),
                  const SizedBox(width: 4),
                  Text(
                    'Dismiss',
                    style: GoogleFonts.outfit(
                      color: Colors.white38,
                      fontSize: 11,
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
        .slideX(begin: 0.2, end: 0, duration: 300.ms, curve: Curves.easeOut)
        .fadeIn();
  }

  /// The level progress bar + upgrade confirmation button
  Widget _buildHintUpgradeBar(BuildContext context, HintResult hint) {
    if (!hint.canUpgrade) {
      // Already at max — show completion indicator
      return Padding(
        padding: const EdgeInsets.only(top: 6),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 14, color: AppTheme.accentGreen),
            const SizedBox(width: 6),
            Text(
              'Full hint revealed',
              style: GoogleFonts.outfit(
                color: AppTheme.accentGreen,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final nextLevelEmoji = hint.currentLevel == 1 ? '🎯' : '♟️';
    final nextLevelLabel = hint.currentLevel == 1 ? 'Direction' : 'Best Move';
    final xpCost = hint.nextLevelXpCost;

    return Padding(
      padding: const EdgeInsets.only(top: 6),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level progress dots
          _buildLevelDots(hint.currentLevel),
          const SizedBox(height: 6),
          // Upgrade button with inline XP cost
          _buildUpgradeButton(
            context: context,
            nextLevelEmoji: nextLevelEmoji,
            nextLevelLabel: nextLevelLabel,
            xpCost: xpCost,
          ),
        ],
      ),
    );
  }

  Widget _buildLevelDots(int currentLevel) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(3, (i) {
        final level = i + 1;
        final isActive = level <= currentLevel;
        final color = _hintLevelColor(level);
        return Container(
          margin: const EdgeInsets.only(right: 4),
          width: isActive ? 20 : 10,
          height: 4,
          decoration: BoxDecoration(
            color: isActive ? color : color.withValues(alpha: 0.25),
            borderRadius: BorderRadius.circular(2),
          ),
        );
      }),
    );
  }

  Widget _buildUpgradeButton({
    required BuildContext context,
    required String nextLevelEmoji,
    required String nextLevelLabel,
    required int xpCost,
  }) {
    return GestureDetector(
      onTap: () => _showUpgradeConfirm(context, nextLevelLabel, xpCost),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
        decoration: BoxDecoration(
          gradient: LinearGradient(
            colors: [
              Colors.amberAccent.withValues(alpha: 0.2),
              Colors.orangeAccent.withValues(alpha: 0.1),
            ],
          ),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(
            color: Colors.amberAccent.withValues(alpha: 0.6),
          ),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.bolt_rounded,
                color: Colors.amberAccent, size: 14),
            const SizedBox(width: 6),
            Text(
              '$nextLevelEmoji $nextLevelLabel',
              style: GoogleFonts.outfit(
                color: Colors.amberAccent,
                fontSize: 11,
                fontWeight: FontWeight.w800,
              ),
            ),
            const SizedBox(width: 8),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
              decoration: BoxDecoration(
                color: Colors.amberAccent.withValues(alpha: 0.2),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(
                '-$xpCost XP',
                style: GoogleFonts.outfit(
                  color: Colors.amberAccent,
                  fontSize: 10,
                  fontWeight: FontWeight.w900,
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildLevelPill(HintResult hint, Color accentColor) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: accentColor.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: accentColor.withValues(alpha: 0.4)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            hint.currentLevelEmoji,
            style: const TextStyle(fontSize: 10),
          ),
          const SizedBox(width: 4),
          Text(
            'HINT LVL ${hint.currentLevel} — ${hint.currentLevelLabel.toUpperCase()}',
            style: GoogleFonts.outfit(
              color: accentColor,
              fontSize: 9,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.5,
            ),
          ),
          if (hint.pattern != TacticalPattern.none) ...[
            const SizedBox(width: 6),
            Text(
              hint.pattern.emoji,
              style: const TextStyle(fontSize: 10),
            ),
            const SizedBox(width: 3),
            Text(
              hint.pattern.label.toUpperCase(),
              style: GoogleFonts.outfit(
                color: accentColor.withValues(alpha: 0.7),
                fontSize: 9,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.3,
              ),
            ),
          ],
        ],
      ),
    );
  }

  /// Shows the XP confirmation bottom sheet before upgrading the hint level
  void _showUpgradeConfirm(
      BuildContext context, String nextLevelLabel, int xpCost) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HintUpgradeConfirmSheet(
        nextLevelLabel: nextLevelLabel,
        xpCost: xpCost,
        onConfirm: () {
          Navigator.of(ctx).pop();
          context.read<GameBloc>().add(const GameRequestHintEvent());
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Color _hintLevelColor(int level) => switch (level) {
        1 => const Color(0xFF64B5F6), // blue — concept
        2 => Colors.amberAccent,      // amber — direction
        3 => const Color(0xFF81C784), // green — best move
        _ => Colors.amberAccent,
      };
}

/// Bottom sheet that asks the user to confirm XP spend before revealing more
class _HintUpgradeConfirmSheet extends StatelessWidget {
  final String nextLevelLabel;
  final int xpCost;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _HintUpgradeConfirmSheet({
    required this.nextLevelLabel,
    required this.xpCost,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isFullReveal = nextLevelLabel == 'Best Move';
    final accentColor = isFullReveal
        ? const Color(0xFF81C784)
        : Colors.amberAccent;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: accentColor.withValues(alpha: 0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withValues(alpha: 0.1),
            blurRadius: 30,
            spreadRadius: 4,
          ),
          const BoxShadow(color: Colors.black54, blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Header
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isFullReveal ? Icons.emoji_events_rounded : Icons.lightbulb_rounded,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reveal $nextLevelLabel?',
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isFullReveal
                          ? 'Shows the exact best move from the engine'
                          : 'Shows which piece to move and where',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),

          const SizedBox(height: 20),

          // XP Cost Banner
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: accentColor.withValues(alpha: 0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withValues(alpha: 0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt_rounded,
                    color: Colors.amberAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Costs $xpCost XP',
                  style: GoogleFonts.fredoka(
                    color: Colors.amberAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),

          const SizedBox(height: 20),

          // Action buttons
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withValues(alpha: 0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      'Not now',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fredoka(
                        color: Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withValues(alpha: 0.9),
                          accentColor.withValues(alpha: 0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded,
                            color: Colors.black87, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Yes, reveal it!',
                          style: GoogleFonts.fredoka(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    ).animate().slideY(begin: 0.3, duration: 350.ms, curve: Curves.easeOutBack).fadeIn();
  }
}
