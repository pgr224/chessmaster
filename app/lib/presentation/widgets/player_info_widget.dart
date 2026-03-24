import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
      duration: 300.ms,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.surface.withOpacity(0.8)
            : AppTheme.navyCard.withOpacity(0.4),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(
          color: isActive ? AppTheme.goldPrimary.withOpacity(0.5) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Row(
        children: [
          // Avatar / piece color indicator
          Container(
            width: 36,
            height: 36,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: color == PieceColor.white ? Colors.white : AppTheme.midnight,
              border: Border.all(
                color: color == PieceColor.white ? AppTheme.goldPrimary : AppTheme.textMuted,
                width: 2,
              ),
            ),
            child: Icon(
              isAI ? Icons.smart_toy_rounded : Icons.person_rounded,
              color: color == PieceColor.white ? AppTheme.midnight : Colors.white,
              size: 18,
            ),
          ),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(name, style: const TextStyle(
                  color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 14,
                )),
                if (isThinking)
                  Row(
                    children: [
                      SizedBox(
                        width: 12, height: 12,
                        child: CircularProgressIndicator(
                          strokeWidth: 1.5,
                          color: AppTheme.goldPrimary,
                        ),
                      ),
                      const SizedBox(width: 6),
                      const Text('Thinking...', style: TextStyle(
                        color: AppTheme.goldPrimary, fontSize: 11,
                      )),
                    ],
                  )
                else
                  Text(
                    color == PieceColor.white ? 'White' : 'Black',
                    style: const TextStyle(color: AppTheme.textMuted, fontSize: 11),
                  ),
              ],
            ),
          ),
          // Active turn indicator
          if (isActive)
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                gradient: const LinearGradient(colors: [AppTheme.goldDark, AppTheme.goldPrimary]),
                borderRadius: BorderRadius.circular(12),
              ),
              child: const Text('YOUR TURN', style: TextStyle(
                color: AppTheme.midnight, fontSize: 9, fontWeight: FontWeight.w800, letterSpacing: 0.5,
              )),
            ).animate(onPlay: (c) => c.repeat(reverse: true))
                .fade(begin: 0.7, end: 1.0, duration: 800.ms),
        ],
      ),
    );
  }
}
