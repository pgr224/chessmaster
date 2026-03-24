import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
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
    final types = [PieceType.queen, PieceType.rook, PieceType.bishop, PieceType.knight];

    return Container(
      color: Colors.black.withValues(alpha: 0.82),
      child: Center(
        child: Container(
          margin: const EdgeInsets.symmetric(horizontal: 24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
            borderRadius: BorderRadius.circular(32),
            border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.6), width: 2),
            boxShadow: [
              BoxShadow(color: AppTheme.goldPrimary.withValues(alpha: 0.25), blurRadius: 40, spreadRadius: 4),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text(
                '✨ Level Up!',
                style: GoogleFonts.fredoka(
                  color: AppTheme.goldPrimary, fontSize: 32, fontWeight: FontWeight.w800,
                ),
              ),
              const SizedBox(height: 10),
              Text(
                'Pick a powerful new piece for your pawn! 🚀',
                style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                textAlign: TextAlign.center,
              ),
              const SizedBox(height: 32),
              Wrap(
                spacing: 12, runSpacing: 12,
                alignment: WrapAlignment.center,
                children: types.map((type) => _pieceOption(type, color)).toList(),
              ),
            ],
          ),
        ),
      ).animate().scale(begin: const Offset(0.7, 0.7), curve: Curves.elasticOut, duration: 600.ms).fadeIn(),
    );
  }

  Widget _pieceOption(PieceType type, PieceColor color) {
    final piece = ChessPiece(type: type, color: color);
    return GestureDetector(
      onTap: () => onSelect(type),
      child: Container(
        width: 84,
        height: 100,
        decoration: BoxDecoration(
          gradient: const LinearGradient(
            colors: [AppTheme.surface, AppTheme.navyCard],
            begin: Alignment.topCenter, end: Alignment.bottomCenter,
          ),
          borderRadius: BorderRadius.circular(22),
          border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.2)),
          boxShadow: [
            BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(piece.symbol, style: const TextStyle(fontSize: 48)),
            const SizedBox(height: 4),
            Text(
              type.name.capitalize(),
              style: GoogleFonts.fredoka(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
            ),
          ],
        ),
      ).animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(0.98, 0.98), end: const Offset(1.02, 1.02), duration: 2.seconds, curve: Curves.easeInOut),
    );
  }
}

extension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
