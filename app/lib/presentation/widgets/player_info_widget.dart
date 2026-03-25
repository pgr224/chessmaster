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
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.surface.withValues(alpha: 0.95)
            : AppTheme.navyCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive ? AppTheme.goldPrimary.withValues(alpha: 0.8) : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isActive ? [
          BoxShadow(color: AppTheme.goldPrimary.withValues(alpha: 0.1), blurRadius: 8)
        ] : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar / piece color indicator
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: color == PieceColor.white 
                  ? const LinearGradient(colors: [Colors.white, Color(0xFFF5E6CA)])
                  : const LinearGradient(colors: [Color(0xFF2D1B69), AppTheme.midnight]),
              border: Border.all(
                color: isActive ? AppTheme.goldPrimary : (color == PieceColor.white ? AppTheme.goldDark : AppTheme.textMuted),
                width: 2,
              ),
            ),
            child: Icon(
              isThinking ? Icons.psychology_rounded : (isAI ? Icons.smart_toy_rounded : Icons.person_rounded),
              color: color == PieceColor.white ? AppTheme.midnight : Colors.white,
              size: 20,
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(name, style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 15,
              )),
              if (isThinking)
                Row(
                  mainAxisSize: MainAxisSize.min,
                  children: [
                    const SizedBox(
                      width: 12, height: 12,
                      child: CircularProgressIndicator(
                        strokeWidth: 2,
                        color: AppTheme.goldPrimary,
                      ),
                    ),
                    const SizedBox(width: 6),
                    Text('Thinking...', style: GoogleFonts.baloo2(
                      color: AppTheme.goldPrimary, fontSize: 12, fontWeight: FontWeight.w700,
                    )),
                  ],
                ).animate(onPlay: (c) => c.repeat(reverse: true)).fadeIn(duration: 500.ms)
              else
                Text(
                  color == PieceColor.white ? '⚪ White' : '⚫ Black',
                  style: GoogleFonts.baloo2(
                    color: isActive ? AppTheme.textSecondary : AppTheme.textMuted, 
                    fontSize: 12, fontWeight: FontWeight.w600,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
