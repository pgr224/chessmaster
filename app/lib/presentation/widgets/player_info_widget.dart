import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';

class PlayerInfoWidget extends StatelessWidget {
  final String name;
  final PieceColor color;
  final bool isActive;
  final bool isAI;
  final bool isThinking;

  const PlayerInfoWidget({
    super.key,
    required this.name,
    required this.color,
    required this.isActive,
    required this.isAI,
    required this.isThinking,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 400.ms,
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.surface.withValues(alpha: 0.95)
            : AppTheme.navyCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isActive ? AppTheme.goldPrimary : Colors.transparent,
          width: 2,
        ),
        boxShadow: isActive ? [
          BoxShadow(color: AppTheme.goldPrimary.withValues(alpha: 0.2), blurRadius: 12, spreadRadius: 2)
        ] : null,
      ),
      child: Row(
        children: [
          // Avatar / piece color indicator — larger and colorful
          Container(
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: color == PieceColor.white 
                  ? const LinearGradient(colors: [Colors.white, Color(0xFFF5E6CA)])
                  : const LinearGradient(colors: [Color(0xFF2D1B69), AppTheme.midnight]),
              border: Border.all(
                color: isActive ? AppTheme.goldPrimary : (color == PieceColor.white ? AppTheme.goldDark : AppTheme.textMuted),
                width: 2.5,
              ),
              boxShadow: [
                 BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 4, offset: const Offset(0, 2)),
              ],
            ),
            child: Icon(
              isThinking ? Icons.psychology_rounded : (isAI ? Icons.smart_toy_rounded : Icons.person_rounded),
              color: color == PieceColor.white ? AppTheme.midnight : Colors.white,
              size: 24,
            ),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(name, style: GoogleFonts.fredoka(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 17,
                )),
                if (isThinking)
                  Row(
                    children: [
                      const SizedBox(
                        width: 14, height: 14,
                        child: CircularProgressIndicator(
                          strokeWidth: 2,
                          color: AppTheme.goldPrimary,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text('Thinking...', style: GoogleFonts.baloo2(
                        color: AppTheme.goldPrimary, fontSize: 13, fontWeight: FontWeight.w700,
                      )),
                    ],
                  ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 500.ms)
                else
                  Text(
                    color == PieceColor.white ? '⚪ White Player' : '⚫ Black Player',
                    style: GoogleFonts.baloo2(
                      color: isActive ? AppTheme.textSecondary : AppTheme.textMuted, 
                      fontSize: 13, fontWeight: FontWeight.w600,
                    ),
                  ),
              ],
            ),
          ),
          // Active turn indicator — bubbly
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
              decoration: BoxDecoration(
                gradient: AppTheme.goldGradient,
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(color: AppTheme.goldPrimary.withValues(alpha: 0.3), blurRadius: 8, offset: const Offset(0, 3)),
                ],
              ),
              child: Text('YOUR TURN!', style: GoogleFonts.fredoka(
                color: AppTheme.midnight, fontSize: 11, fontWeight: FontWeight.w800, letterSpacing: 0.5,
              )),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
                .scale(begin: const Offset(0.95, 0.95), end: const Offset(1.05, 1.05), duration: 800.ms)
                .fade(begin: 0.8, end: 1.0),
        ],
      ),
    );
  }
}
