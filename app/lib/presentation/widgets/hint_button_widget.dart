import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';

class HintButtonWidget extends StatelessWidget {
  final int hintsRemaining;
  final VoidCallback? onTap;

  const HintButtonWidget({
    super.key,
    required this.hintsRemaining,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final isEnabled = onTap != null;
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 300.ms,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: isEnabled
              ? AppTheme.goldPrimary.withOpacity(0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Stack(
              clipBehavior: Clip.none,
              children: [
                Icon(
                  Icons.lightbulb_rounded,
                  color: isEnabled ? AppTheme.goldPrimary : AppTheme.textMuted,
                  size: 26,
                  shadows: isEnabled
                      ? [
                          const Shadow(
                              color: AppTheme.goldPrimary, blurRadius: 10),
                        ]
                      : null,
                )
                    .animate(
                        onPlay: (c) =>
                            isEnabled ? c.repeat(reverse: true) : c.stop())
                    .scale(
                        begin: const Offset(1, 1),
                        end: const Offset(1.1, 1.1),
                        duration: 1.seconds),
                if (hintsRemaining > 0)
                  Positioned(
                    top: -8,
                    right: -8,
                    child: Container(
                      width: 18,
                      height: 18,
                      decoration: const BoxDecoration(
                        gradient: AppTheme.cyanGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                              color: Colors.black26,
                              blurRadius: 4,
                              offset: Offset(0, 2))
                        ],
                      ),
                      child: Center(
                        child: Text(
                          '$hintsRemaining',
                          style: GoogleFonts.fredoka(
                            color: AppTheme.midnight,
                            fontSize: 11,
                            fontWeight: FontWeight.w800,
                          ),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            Text(
              'HINT ✨',
              style: GoogleFonts.fredoka(
                color: isEnabled ? AppTheme.textSecondary : AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
