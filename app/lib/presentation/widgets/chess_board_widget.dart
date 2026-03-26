import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';

class ChessBoardWidget extends StatefulWidget {
  final List<List<ChessPiece?>> board;
  final PieceColor perspective;
  final Square? selectedSquare;
  final List<Move> legalMoves;
  final Move? lastMove;
  final Move? hintMove;
  final GameStatus status;
  final bool isFlipped;
  final String boardTheme;
  final String pieceTheme;
  final String moveAnimationSpeed;
  final bool showCoordinates;
  final Color whitePieceColor;
  final Color blackPieceColor;
  final Function(Square)? onSquareTap;
  final bool isInteractive;

  const ChessBoardWidget({
    super.key,
    required this.board,
    required this.perspective,
    this.selectedSquare,
    this.legalMoves = const [],
    this.lastMove,
    this.hintMove,
    this.status = GameStatus.active,
    this.isFlipped = false,
    this.boardTheme = 'classic',
    this.pieceTheme = 'classic',
    this.moveAnimationSpeed = 'normal',
    this.showCoordinates = true,
    this.whitePieceColor = Colors.white,
    this.blackPieceColor = Colors.black,
    this.onSquareTap,
    this.isInteractive = true,
  });

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget> {

  @override
  Widget build(BuildContext context) {
    return Center(
      child: LayoutBuilder(
        builder: (context, constraints) {
          final size = math.min(constraints.maxWidth, constraints.maxHeight);
          final sqSize = size / 8;
          
          return SizedBox(
            width: size,
            height: size,
            child: Container(
              decoration: BoxDecoration(
                borderRadius: BorderRadius.circular(16),
                boxShadow: [
                  BoxShadow(
                    color: Colors.black.withValues(alpha: 0.5),
                    blurRadius: 24,
                    offset: const Offset(0, 12),
                  ),
                ],
              ),
              child: ClipRRect(
                borderRadius: BorderRadius.circular(16),
                child: AspectRatio(
                  aspectRatio: 1.0,
                  child: Stack(
                    children: [
                      _buildBoardGrid(sqSize),
                      _buildHighlights(sqSize),
                      _buildPieces(sqSize),
                      if (widget.showCoordinates) _buildCoordinates(sqSize),
                      if (widget.isInteractive) _buildTapOverlay(sqSize),
                    ],
                  ),
                ),
              ),
            ),
          );
        },
      ),
    );
  }

  Widget _buildBoardGrid(double sqSize) {
    return Column(
      children: List.generate(8, (r) {
        final rank = 7 - r;
        return Row(
          children: List.generate(8, (f) {
            final file = f;
            final isLight = (file + rank) % 2 == 1;
            return SizedBox(
              width: sqSize,
              height: sqSize,
              child: _squareColor(isLight, widget.boardTheme),
            );
          }),
        );
      }),
    );
  }

  Widget _squareColor(bool isLight, String theme) {
    final themeData = AppTheme.boardThemes[theme] ?? AppTheme.boardThemes['classic']!;
    return ColoredBox(color: isLight ? themeData.light : themeData.dark);
  }

  Widget _buildHighlights(double sqSize) {
    return Stack(
      children: [
        // Last move highlight
        if (widget.lastMove != null) ...[
          _highlight(widget.lastMove!.from, sqSize, AppTheme.lastMoveSq),
          _highlight(widget.lastMove!.to, sqSize, AppTheme.lastMoveSq),
        ],
        // Hint highlight
        if (widget.hintMove != null) ...[
          _highlight(widget.hintMove!.from, sqSize, AppTheme.hintSq),
          _highlight(widget.hintMove!.to, sqSize, AppTheme.hintSq.withValues(alpha: 0.9)),
        ],
        // Selected piece
        if (widget.selectedSquare != null)
          _highlight(widget.selectedSquare!, sqSize, AppTheme.selectedSq.withValues(alpha: 0.7)),
        // Legal moves
        ...widget.legalMoves.map((m) => _legalMoveIndicator(m, sqSize)),
        // Check highlight
        if (widget.status == GameStatus.check) _buildCheckHighlight(sqSize),
      ],
    );
  }

  Widget _highlight(Square sq, double sqSize, Color color) {
    final (x, y) = _squareToPixel(sq, sqSize);
    return Positioned(
      left: x,
      top: y,
      width: sqSize,
      height: sqSize,
      child: ColoredBox(color: color),
    );
  }

  Widget _legalMoveIndicator(Move move, double sqSize) {
    final (x, y) = _squareToPixel(move.to, sqSize);
    final hasPiece = widget.board[move.to.rank][move.to.file] != null;
    return Positioned(
      left: x,
      top: y,
      width: sqSize,
      height: sqSize,
      child: hasPiece
          ? _captureRingIndicator(sqSize)
          : Center(
              child: Container(
                width: sqSize * 0.33,
                height: sqSize * 0.33,
                decoration: BoxDecoration(
                  color: AppTheme.legalMoveSq,
                  shape: BoxShape.circle,
                ),
              ),
            ),
    );
  }

  Widget _captureRingIndicator(double sqSize) {
    return Container(
      decoration: BoxDecoration(
        border: Border.all(
          color: AppTheme.legalMoveSq,
          width: sqSize * 0.1,
        ),
        shape: BoxShape.circle,
      ),
    );
  }

  Widget _buildCheckHighlight(double sqSize) {
    // Find the king in check
    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        final p = widget.board[r][f];
        if (p?.type == PieceType.king) {
          // Find which king is in check based on current turn
          final sq = Square(f, r);
          return _buildPulsingCheck(sq, sqSize);
        }
      }
    }
    return const SizedBox.shrink();
  }

  Widget _buildPulsingCheck(Square sq, double sqSize) {
    final (x, y) = _squareToPixel(sq, sqSize);
    final checkLayer = Container(color: AppTheme.checkSq);

    if (widget.moveAnimationSpeed == 'off') {
      return Positioned(
        left: x,
        top: y,
        width: sqSize,
        height: sqSize,
        child: checkLayer,
      );
    }

    return Positioned(
      left: x, top: y, width: sqSize, height: sqSize,
      child: checkLayer
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 500.ms)
          .then()
          .fadeOut(duration: 500.ms),
    );
  }

  Widget _buildPieces(double sqSize) {
    final animDuration = _pieceAnimDuration(widget.moveAnimationSpeed);
    final pieces = <Widget>[];
    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        final piece = widget.board[r][f];
        if (piece == null) continue;
        final sq = Square(f, r);
        final (x, y) = _squareToPixel(sq, sqSize);
        final pieceChild = _PieceWidget(
          piece: piece,
          theme: widget.pieceTheme,
          size: sqSize * 0.9,
          whitePieceColor: widget.whitePieceColor,
          blackPieceColor: widget.blackPieceColor,
        );
        pieces.add(
          Positioned(
            key: ValueKey('${piece.color.name}${piece.type.name}$f$r'),
            left: x,
            top: y,
            width: sqSize,
            height: sqSize,
            child: widget.moveAnimationSpeed == 'off'
                ? pieceChild
                : pieceChild.animate().scale(
                    duration: animDuration,
                    curve: Curves.easeOutBack,
                  ),
          ),
        );
      }
    }
    return Stack(children: pieces);
  }

  Duration _pieceAnimDuration(String speed) {
    switch (speed) {
      case 'off':
        return Duration.zero;
      case 'fast':
        return 80.ms;
      default:
        return 150.ms;
    }
  }

  Widget _buildCoordinates(double sqSize) {
    final themeData = AppTheme.boardThemes[widget.boardTheme] ?? AppTheme.boardThemes['classic']!;
    final notationColor = themeData.notation.withValues(alpha: 0.8);
    
    return Stack(
      children: [
        // Files (a-h)
        ...List.generate(8, (f) {
          final flipF = widget.perspective == PieceColor.black ? 7 - f : f;
          return Positioned(
            left: flipF * sqSize + sqSize * 0.05,
            bottom: 2,
            child: Text(
              String.fromCharCode(97 + f),
              style: TextStyle(
                fontSize: sqSize * 0.18,
                fontFamily: GoogleFonts.jura().fontFamily,
                fontWeight: FontWeight.bold,
                color: notationColor,
              ),
            ),
          );
        }),
        // Ranks (1-8)
        ...List.generate(8, (r) {
          final screenRank = widget.perspective == PieceColor.white ? 7 - r : r;
          return Positioned(
            top: screenRank * sqSize + 2,
            right: 4,
            child: Text(
              '${r + 1}',
              style: TextStyle(
                fontSize: sqSize * 0.18,
                fontFamily: GoogleFonts.jura().fontFamily,
                fontWeight: FontWeight.bold,
                color: notationColor,
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTapOverlay(double sqSize) {
    return Column(
      children: List.generate(8, (r) {
        final displayRank = r;
        return Row(
          children: List.generate(8, (f) {
            final displayFile = f;
            final sq = widget.perspective == PieceColor.white
                ? Square(displayFile, 7 - displayRank)
                : Square(7 - displayFile, displayRank);
            return GestureDetector(
              onTap: () => widget.onSquareTap?.call(sq),
              behavior: HitTestBehavior.translucent,
              child: SizedBox(
                width: sqSize,
                height: sqSize,
              ),
            );
          }),
        );
      }),
    );
  }

  (double, double) _squareToPixel(Square sq, double sqSize) {
    int displayFile, displayRank;
    if (widget.perspective == PieceColor.white) {
      displayFile = sq.file;
      displayRank = 7 - sq.rank;
    } else {
      displayFile = 7 - sq.file;
      displayRank = sq.rank;
    }
    return (displayFile * sqSize, displayRank * sqSize);
  }
}

class _PieceWidget extends StatelessWidget {
  final ChessPiece piece;
  final String theme;
  final double size;
  final Color whitePieceColor;
  final Color blackPieceColor;

  const _PieceWidget({
    required this.piece,
    required this.theme,
    required this.size,
    required this.whitePieceColor,
    required this.blackPieceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _buildPieceVisual(),
    );
  }

  Widget _buildPieceVisual() {
    final isWhite = piece.color == PieceColor.white;
    final baseColor = isWhite ? whitePieceColor : blackPieceColor;
    final style = _styleForTheme(theme, baseColor);

    // Filter themes
    if (theme == 'letters') return _buildLetterPiece(isWhite, baseColor);
    if (theme == '8-bit') return _build8BitPiece(isWhite, baseColor);
    if (theme == 'angular') return _buildAngularPiece(isWhite, baseColor);
    if (theme == 'mexico') return _buildMexicoPiece(isWhite, baseColor);
    if (theme == 'lewis') return _buildLewisPiece(isWhite, baseColor);
    if (theme == 'video') return _buildVideoPiece(isWhite, baseColor);

    // Default: Classic 3D
    return SizedBox(
      width: size * 0.85,
      height: size * 0.85,
      child: Stack(
        alignment: Alignment.center,
        children: [
          Positioned(
            bottom: size * 0.02,
            child: Container(
              width: size * 0.55,
              height: size * 0.1,
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: style.shadowOpacity),
                borderRadius: BorderRadius.circular(size * 0.05),
              ),
            ),
          ),
          Container(
            width: size * 0.8,
            height: size * 0.8,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              gradient: RadialGradient(
                center: const Alignment(-0.25, -0.3),
                radius: 0.9,
                colors: [style.light, style.mid, style.dark],
                stops: const [0.0, 0.6, 1.0],
              ),
              border: Border.all(color: style.rim, width: 1.2),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.25),
                  blurRadius: 6,
                  offset: const Offset(0, 3),
                ),
              ],
            ),
          ),
          CustomPaint(
            size: Size.square(size * 0.6),
            painter: _PieceSilhouettePainter(
              type: piece.type,
              fill: style.silhouetteFill,
              stroke: style.silhouetteStroke,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildLetterPiece(bool isWhite, Color color) {
    return Center(
      child: Text(
        piece.symbol.toUpperCase(),
        style: GoogleFonts.jura(
          fontSize: size * 0.7,
          fontWeight: FontWeight.bold,
          color: color,
        ),
      ),
    );
  }

  Widget _build8BitPiece(bool isWhite, Color color) {
    return Center(
      child: Text(
        piece.symbol.toUpperCase(),
        style: GoogleFonts.vt323(
          fontSize: size * 0.5,
          color: color,
        ),
      ),
    );
  }

  Widget _buildAngularPiece(bool isWhite, Color color) {
    return Center(
      child: Icon(
        _iconDataForType(piece.type),
        size: size * 0.8,
        color: color,
      ),
    );
  }

  Widget _buildMexicoPiece(bool isWhite, Color color) {
    return Center(
      child: Text(
        piece.symbol.toUpperCase(),
        style: GoogleFonts.monoton(
          fontSize: size * 0.65,
          color: color,
        ),
      ),
    );
  }

  Widget _buildLewisPiece(bool isWhite, Color color) {
    return Center(
      child: Text(
        piece.symbol.toUpperCase(),
        style: GoogleFonts.notoSerif(
          fontSize: size * 0.75,
          fontWeight: FontWeight.w900,
          color: color,
        ),
      ),
    );
  }

  Widget _buildVideoPiece(bool isWhite, Color color) {
    return Center(
      child: Text(
        piece.symbol.toUpperCase(),
        style: GoogleFonts.orbitron(
          fontSize: size * 0.55,
          fontWeight: FontWeight.bold,
          color: color,
          shadows: [
            Shadow(color: color.withValues(alpha: 0.5), blurRadius: 10),
          ],
        ),
      ),
    );
  }

  IconData _iconDataForType(PieceType type) {
    switch (type) {
      case PieceType.pawn:   return Icons.change_history;
      case PieceType.rook:   return Icons.crop_square;
      case PieceType.knight: return Icons.details;
      case PieceType.bishop: return Icons.architecture;
      case PieceType.queen:  return Icons.brightness_high;
      case PieceType.king:   return Icons.star;
    }
  }

  _PieceMaterialStyle _styleForTheme(String rawTheme, Color baseColor) {
    final normalized = rawTheme == 'classic' ? 'classic3d' : rawTheme;
    final contrast = _bestTextColor(baseColor);

    switch (normalized) {
      case 'marble3d':
        final marbleBase = Color.lerp(baseColor, const Color(0xFFE5E8ED), 0.45)!;
        return _PieceMaterialStyle(
          light: _lighten(marbleBase, 0.18),
          mid: marbleBase,
          dark: _darken(marbleBase, 0.26),
          rim: contrast.withValues(alpha: 0.18),
          silhouetteFill: contrast.withValues(alpha: 0.88),
          silhouetteStroke: Colors.white.withValues(alpha: 0.2),
          highlightOpacity: 0.38,
          shadowOpacity: 0.2,
        );
      case 'metal3d':
        final metalBase = Color.lerp(baseColor, const Color(0xFF8A94A6), 0.5)!;
        return _PieceMaterialStyle(
          light: _lighten(metalBase, 0.26),
          mid: metalBase,
          dark: _darken(metalBase, 0.33),
          rim: Colors.white.withValues(alpha: 0.2),
          silhouetteFill: Colors.white.withValues(alpha: 0.9),
          silhouetteStroke: const Color(0xFF1E2733).withValues(alpha: 0.22),
          highlightOpacity: 0.46,
          shadowOpacity: 0.28,
        );
      default:
        return _PieceMaterialStyle(
          light: _lighten(baseColor, 0.22),
          mid: baseColor,
          dark: _darken(baseColor, 0.28),
          rim: contrast.withValues(alpha: 0.22),
          silhouetteFill: contrast.withValues(alpha: 0.92),
          silhouetteStroke: contrast.withValues(alpha: 0.25),
          highlightOpacity: 0.32,
          shadowOpacity: 0.24,
        );
    }
  }

  Color _lighten(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness + amount).clamp(0.0, 1.0)).toColor();
  }

  Color _darken(Color c, double amount) {
    final hsl = HSLColor.fromColor(c);
    return hsl.withLightness((hsl.lightness - amount).clamp(0.0, 1.0)).toColor();
  }

  Color _bestTextColor(Color background) {
    return background.computeLuminance() > 0.5 ? Colors.black : Colors.white;
  }
}

class _PieceMaterialStyle {
  final Color light;
  final Color mid;
  final Color dark;
  final Color rim;
  final Color silhouetteFill;
  final Color silhouetteStroke;
  final double highlightOpacity;
  final double shadowOpacity;

  const _PieceMaterialStyle({
    required this.light,
    required this.mid,
    required this.dark,
    required this.rim,
    required this.silhouetteFill,
    required this.silhouetteStroke,
    required this.highlightOpacity,
    required this.shadowOpacity,
  });
}

class _PieceSilhouettePainter extends CustomPainter {
  final PieceType type;
  final Color fill;
  final Color stroke;

  const _PieceSilhouettePainter({
    required this.type,
    required this.fill,
    required this.stroke,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02
      ..color = stroke;

    final path = switch (type) {
      PieceType.pawn => _pawnPath(size),
      PieceType.knight => _knightPath(size),
      PieceType.bishop => _bishopPath(size),
      PieceType.rook => _rookPath(size),
      PieceType.queen => _queenPath(size),
      PieceType.king => _kingPath(size),
    };

    canvas.drawPath(path, fillPaint);
    canvas.drawPath(path, strokePaint);
  }

  Path _pawnPath(Size s) {
    final w = s.width;
    final h = s.height;
    final p = Path();
    p.addOval(Rect.fromCircle(center: Offset(w * 0.5, h * 0.27), radius: w * 0.12));
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.39, h * 0.36, w * 0.22, h * 0.22),
      Radius.circular(w * 0.09),
    ));
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.3, h * 0.57, w * 0.4, h * 0.12),
      Radius.circular(w * 0.06),
    ));
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.22, h * 0.72, w * 0.56, h * 0.12),
      Radius.circular(w * 0.06),
    ));
    return p;
  }

  Path _rookPath(Size s) {
    final w = s.width;
    final h = s.height;
    final p = Path();
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.24, h * 0.24, w * 0.52, h * 0.12),
      Radius.circular(w * 0.03),
    ));
    p.addRect(Rect.fromLTWH(w * 0.28, h * 0.18, w * 0.08, h * 0.08));
    p.addRect(Rect.fromLTWH(w * 0.46, h * 0.16, w * 0.08, h * 0.1));
    p.addRect(Rect.fromLTWH(w * 0.64, h * 0.18, w * 0.08, h * 0.08));
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.33, h * 0.36, w * 0.34, h * 0.3),
      Radius.circular(w * 0.05),
    ));
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.27, h * 0.68, w * 0.46, h * 0.13),
      Radius.circular(w * 0.06),
    ));
    return p;
  }

  Path _bishopPath(Size s) {
    final w = s.width;
    final h = s.height;
    final p = Path();
    p.addOval(Rect.fromCenter(center: Offset(w * 0.5, h * 0.25), width: w * 0.2, height: h * 0.22));
    p.moveTo(w * 0.52, h * 0.18);
    p.lineTo(w * 0.44, h * 0.32);
    p.lineTo(w * 0.48, h * 0.34);
    p.close();
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.37, h * 0.34, w * 0.26, h * 0.28),
      Radius.circular(w * 0.12),
    ));
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.28, h * 0.66, w * 0.44, h * 0.14),
      Radius.circular(w * 0.06),
    ));
    return p;
  }

  Path _knightPath(Size s) {
    final w = s.width;
    final h = s.height;
    final p = Path();
    p.moveTo(w * 0.3, h * 0.78);
    p.lineTo(w * 0.68, h * 0.78);
    p.lineTo(w * 0.63, h * 0.64);
    p.quadraticBezierTo(w * 0.72, h * 0.52, w * 0.66, h * 0.39);
    p.quadraticBezierTo(w * 0.58, h * 0.2, w * 0.41, h * 0.23);
    p.lineTo(w * 0.48, h * 0.34);
    p.lineTo(w * 0.36, h * 0.42);
    p.lineTo(w * 0.42, h * 0.52);
    p.lineTo(w * 0.3, h * 0.62);
    p.close();
    p.addOval(Rect.fromCircle(center: Offset(w * 0.56, h * 0.34), radius: w * 0.018));
    return p;
  }

  Path _queenPath(Size s) {
    final w = s.width;
    final h = s.height;
    final p = Path();
    p.addOval(Rect.fromCircle(center: Offset(w * 0.3, h * 0.21), radius: w * 0.05));
    p.addOval(Rect.fromCircle(center: Offset(w * 0.42, h * 0.17), radius: w * 0.05));
    p.addOval(Rect.fromCircle(center: Offset(w * 0.58, h * 0.17), radius: w * 0.05));
    p.addOval(Rect.fromCircle(center: Offset(w * 0.7, h * 0.21), radius: w * 0.05));
    p.moveTo(w * 0.24, h * 0.27);
    p.lineTo(w * 0.76, h * 0.27);
    p.lineTo(w * 0.66, h * 0.59);
    p.lineTo(w * 0.34, h * 0.59);
    p.close();
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.27, h * 0.61, w * 0.46, h * 0.18),
      Radius.circular(w * 0.06),
    ));
    return p;
  }

  Path _kingPath(Size s) {
    final w = s.width;
    final h = s.height;
    final p = Path();
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.45, h * 0.08, w * 0.1, h * 0.16),
      Radius.circular(w * 0.03),
    ));
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.4, h * 0.12, w * 0.2, h * 0.08),
      Radius.circular(w * 0.03),
    ));
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.35, h * 0.24, w * 0.3, h * 0.34),
      Radius.circular(w * 0.08),
    ));
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.27, h * 0.62, w * 0.46, h * 0.18),
      Radius.circular(w * 0.06),
    ));
    return p;
  }

  @override
  bool shouldRepaint(covariant _PieceSilhouettePainter oldDelegate) {
    return oldDelegate.type != type || oldDelegate.fill != fill || oldDelegate.stroke != stroke;
  }
}
