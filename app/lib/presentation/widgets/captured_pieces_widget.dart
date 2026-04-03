import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
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
    if (pieces.isEmpty) return const SizedBox(height: 32);

    // Sort by value: queen > rook > bishop > knight > pawn
    final sorted = List<ChessPiece>.from(pieces)
      ..sort((a, b) => _pieceValue(b.type) - _pieceValue(a.type));

    // Calculate material advantage
    final totalValue = pieces.fold(0, (sum, p) => sum + _pieceValue(p.type));

    return Container(
      height: 32,
      margin: const EdgeInsets.symmetric(vertical: 4),
      padding: const EdgeInsets.symmetric(horizontal: 20),
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Row(
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.surface.withOpacity(0.4),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  ...sorted.take(12).map((p) => Text(
                        p.unicodeSymbol,
                        style: TextStyle(
                          fontSize: 18,
                          color: color == PieceColor.white
                              ? Colors.white
                              : AppTheme.textPrimary.withOpacity(0.9),
                          shadows: const [
                            Shadow(
                              color: Colors.black26,
                              blurRadius: 2,
                              offset: Offset(1, 1),
                            )
                          ],
                        ),
                      )),
                  if (pieces.length > 12)
                    Text(' +${pieces.length - 12}',
                        style: GoogleFonts.baloo2(
                            color: AppTheme.textMuted,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            const SizedBox(width: 10),
            if (totalValue > 0)
              Container(
                padding:
                    const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                decoration: BoxDecoration(
                  color: AppTheme.accentCyan.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '+$totalValue',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.accentCyan,
                    fontSize: 13,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }

  int _pieceValue(PieceType type) => switch (type) {
        PieceType.queen => 9,
        PieceType.rook => 5,
        PieceType.bishop => 3,
        PieceType.knight => 3,
        PieceType.pawn => 1,
        PieceType.king => 0,
      };
}
