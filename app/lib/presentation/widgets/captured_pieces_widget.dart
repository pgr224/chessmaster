import 'package:flutter/material.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';

class CapturedPiecesWidget extends StatelessWidget {
  final List<ChessPiece> pieces;
  final PieceColor color;

  const CapturedPiecesWidget({
    super.key,
    required this.pieces,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    if (pieces.isEmpty) return const SizedBox(height: 24);

    // Sort by value: queen > rook > bishop > knight > pawn
    final sorted = List<ChessPiece>.from(pieces)
      ..sort((a, b) => _pieceValue(b.type) - _pieceValue(a.type));

    // Calculate material advantage
    final totalValue = pieces.fold(0, (sum, p) => sum + _pieceValue(p.type));

    return Container(
      height: 28,
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        children: [
          ...sorted.take(10).map((p) => Text(
            p.symbol,
            style: TextStyle(
              fontSize: 16,
              shadows: [Shadow(
                color: Colors.black.withOpacity(0.5),
                blurRadius: 2, offset: const Offset(1, 1),
              )],
            ),
          )),
          if (pieces.length > 10)
            Text(' +${pieces.length - 10}',
                style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          const SizedBox(width: 8),
          if (totalValue > 0)
            Text(
              '+$totalValue',
              style: const TextStyle(
                color: AppTheme.accentGreen, fontSize: 13, fontWeight: FontWeight.w700,
              ),
            ),
        ],
      ),
    );
  }

  int _pieceValue(PieceType type) => switch (type) {
    PieceType.queen  => 9,
    PieceType.rook   => 5,
    PieceType.bishop => 3,
    PieceType.knight => 3,
    PieceType.pawn   => 1,
    PieceType.king   => 0,
  };
}
