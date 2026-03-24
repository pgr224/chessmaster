import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';

class PromotionDialog extends StatelessWidget {
  final PieceColor color;
  final void Function(PieceType) onSelect;

  const PromotionDialog({
    super.key,
    required this.color,
    required this.onSelect,
  });

  @override
  Widget build(BuildContext context) {
    final pieces = [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight];

    return Container(
      color: Colors.black.withOpacity(0.8),
      child: Center(
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.5)),
            boxShadow: AppTheme.goldShadow,
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Text(
                'Promote Pawn',
                style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 8),
              const Text(
                'Select a piece to promote to',
                style: TextStyle(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 24),
              Row(
                mainAxisSize: MainAxisSize.min,
                children: pieces.map((type) => _pieceOption(type, color)).toList(),
              ),
            ],
          ),
        ),
      ).animate().fadeIn(duration: 200.ms).scale(begin: const Offset(0.8, 0.8)),
    );
  }

  Widget _pieceOption(PieceType type, PieceColor color) {
    final piece = ChessPiece(type: type, color: color);
    return GestureDetector(
      onTap: () => onSelect(type),
      child: Container(
        width: 68,
        height: 68,
        margin: const EdgeInsets.symmetric(horizontal: 6),
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.surface, AppTheme.navyCard],
          ),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.3)),
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(piece.symbol, style: const TextStyle(fontSize: 32)),
            Text(
              type.name.capitalize(),
              style: const TextStyle(color: AppTheme.textMuted, fontSize: 10),
            ),
          ],
        ),
      ).animate().scale(
        begin: const Offset(0.9, 0.9),
        duration: 200.ms,
        curve: Curves.easeOutBack,
      ),
    );
  }
}

extension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
