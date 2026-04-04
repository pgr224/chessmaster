part of 'reacting_robot_widget.dart';

extension ReactingRobotBubble on _ReactingRobotWidgetState {
  // ═══════════════════════════════════════════════
  // QUOTE BUBBLE
  // ═══════════════════════════════════════════════
  Widget _buildQuoteBubble({
    required BuildContext context,
    required String text,
    required String? subtext,
    required HintResult? hint,
    required bool isThinking,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withValues(alpha: 0.97),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(22),
        ),
        border: Border.all(
          color: _moodColor.withValues(alpha: 0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _moodColor.withValues(alpha: 0.12),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mood indicator pill
          _buildMoodPill(hint),

          const SizedBox(height: 6),

          // Main text with animated switcher
          AnimatedSwitcher(
            duration: 350.ms,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: anim.drive(Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                )),
                child: child,
              ),
            ),
            child: Text(
              text,
              key: ValueKey(text),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),

          // Subtext explanation
          if (subtext != null && subtext.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              subtext,
              style: GoogleFonts.outfit(
                color: Colors.white.withValues(alpha: 0.8),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // Thinking indicator
          if (isThinking) ...[
            const SizedBox(height: 6),
            _buildThinkingDots(),
          ],

          // Dismiss for hints
          if (hint != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () =>
                  context.read<GameBloc>().add(const GameDismissHintEvent()),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.close_rounded,
                      size: 11, color: Colors.white30),
                  const SizedBox(width: 3),
                  Text(
                    'Dismiss',
                    style: GoogleFonts.outfit(
                      color: Colors.white30,
                      fontSize: 10,
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
        .slideX(begin: 0.15, end: 0, duration: 280.ms, curve: Curves.easeOut)
        .fadeIn();
  }

  Widget _buildMoodPill(HintResult? hint) {
    final String label;
    final IconData icon;

    if (hint != null) {
      label =
          'HINT LVL ${hint.currentLevel} — ${hint.currentLevelLabel.toUpperCase()}';
      icon = Icons.lightbulb_rounded;
    } else {
      label = switch (_mood) {
        RobotMood.thinking => 'THINKING',
        RobotMood.happy || RobotMood.impressed => 'NICE MOVE',
        RobotMood.worried => 'STRONG PLAY',
        RobotMood.disappointed => 'CAREFUL!',
        RobotMood.hinting => 'HINT',
        RobotMood.celebrating => 'GAME OVER',
        _ => 'AI COACH',
      };
      icon = switch (_mood) {
        RobotMood.thinking => Icons.psychology_rounded,
        RobotMood.happy || RobotMood.impressed => Icons.thumb_up_alt_rounded,
        RobotMood.worried => Icons.warning_amber_rounded,
        RobotMood.disappointed => Icons.error_outline_rounded,
        RobotMood.celebrating => Icons.emoji_events_rounded,
        _ => Icons.smart_toy_rounded,
      };
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _moodColor.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _moodColor.withValues(alpha: 0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: _moodColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: _moodColor,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          if (hint != null && hint.pattern != TacticalPattern.none) ...[
            const SizedBox(width: 5),
            Text(
              hint.pattern.emoji,
              style: const TextStyle(fontSize: 9),
            ),
            const SizedBox(width: 2),
            Text(
              hint.pattern.label.toUpperCase(),
              style: GoogleFonts.outfit(
                color: _moodColor.withValues(alpha: 0.6),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThinkingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation<Color>(_moodColor.withValues(alpha: 0.7)),
          ),
        ),
        const SizedBox(width: 8),
        _AnimatedThinkingDots(color: _moodColor),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // HINT UPGRADE BAR
  // ═══════════════════════════════════════════════
  Widget _buildHintUpgradeBar(BuildContext context, HintResult hint) {
    if (!hint.canUpgrade) {
      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 13, color: AppTheme.accentGreen),
            const SizedBox(width: 5),
            Text(
              'Full hint revealed',
              style: GoogleFonts.outfit(
                color: AppTheme.accentGreen,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final nextEmoji = hint.currentLevel == 1 ? '🎯' : '♟️';
    final nextLabel = hint.currentLevel == 1 ? 'Direction' : 'Best Move';
    final xpCost = hint.nextLevelXpCost;

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level progress dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final level = i + 1;
              final isActive = level <= hint.currentLevel;
              final dotColor = _hintLevelColor(level);
              return Container(
                margin: const EdgeInsets.only(right: 3),
                width: isActive ? 18 : 8,
                height: 3,
                decoration: BoxDecoration(
                  color: isActive ? dotColor : dotColor.withValues(alpha: 0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          const SizedBox(height: 5),
          // Upgrade button
          GestureDetector(
            onTap: () => _showUpgradeConfirm(context, nextLabel, xpCost),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.goldPrimary.withValues(alpha: 0.18),
                    AppTheme.accentOrange.withValues(alpha: 0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.goldPrimary.withValues(alpha: 0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: Colors.amberAccent, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '$nextEmoji $nextLabel',
                    style: GoogleFonts.outfit(
                      color: Colors.amberAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withValues(alpha: 0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '-$xpCost XP',
                      style: GoogleFonts.outfit(
                        color: Colors.amberAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeConfirm(
      BuildContext context, String nextLevelLabel, int xpCost) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HintUpgradeSheet(
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
        1 => const Color(0xFF64B5F6),
        2 => Colors.amberAccent,
        3 => const Color(0xFF81C784),
        _ => Colors.amberAccent,
      };
}

// ═══════════════════════════════════════════════
// ANIMATED THINKING DOTS
// ═══════════════════════════════════════════════
class _AnimatedThinkingDots extends StatefulWidget {
  final Color color;
  const _AnimatedThinkingDots({required this.color});

  @override
  State<_AnimatedThinkingDots> createState() => _AnimatedThinkingDotsState();
}

class _AnimatedThinkingDotsState extends State<_AnimatedThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: 1200.ms)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        int dots = ((_controller.value * 4).floor()) % 4;
        return SizedBox(
          width: 20,
          child: Text(
            '.' * dots,
            style: GoogleFonts.fredoka(
              color: widget.color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════
// SMILE / FROWN PAINTERS
// ═══════════════════════════════════════════════
class _SmilePainter extends CustomPainter {
  final Color color;
  _SmilePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(
          size.width / 2, size.height * 1.2, size.width, size.height * 0.2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FrownPainter extends CustomPainter {
  final Color color;
  _FrownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(
          size.width / 2, -size.height * 0.2, size.width, size.height * 0.8);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════
// HINT UPGRADE CONFIRMATION SHEET
// ═══════════════════════════════════════════════
class _HintUpgradeSheet extends StatelessWidget {
  final String nextLevelLabel;
  final int xpCost;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _HintUpgradeSheet({
    required this.nextLevelLabel,
    required this.xpCost,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isFullReveal = nextLevelLabel == 'Best Move';
    final accentColor =
        isFullReveal ? const Color(0xFF81C784) : Colors.amberAccent;

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
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isFullReveal
                      ? Icons.emoji_events_rounded
                      : Icons.lightbulb_rounded,
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
    )
        .animate()
        .slideY(begin: 0.3, duration: 350.ms, curve: Curves.easeOutBack)
        .fadeIn();
  }
}
