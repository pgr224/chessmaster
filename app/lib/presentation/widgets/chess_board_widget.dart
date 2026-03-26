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

    // Filter themes
    if (theme == 'letters') return _buildLetterPiece(isWhite, baseColor);
    if (theme == '8-bit') return _build8BitPiece(isWhite, baseColor);

    return _ObjectPiece(
      piece: piece,
      theme: theme,
      size: size,
      color: baseColor,
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
}

class _ObjectPiece extends StatelessWidget {
  final ChessPiece piece;
  final String theme;
  final double size;
  final Color color;

  const _ObjectPiece({
    required this.piece,
    required this.theme,
    required this.size,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        painter: _ObjectPiecePainter(
          piece: piece,
          theme: theme,
          color: color,
        ),
      ),
    );
  }
}

class _ObjectPiecePainter extends CustomPainter {
  final ChessPiece piece;
  final String theme;
  final Color color;

  _ObjectPiecePainter({
    required this.piece,
    required this.theme,
    required this.color,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final w = size.width;
    final h = size.height;

    // 1. Shadow
    final shadowPaint = Paint()
      ..color = Colors.black.withValues(alpha: 0.3)
      ..maskFilter = MaskFilter.blur(BlurStyle.normal, w * 0.08);
    canvas.drawOval(
      Rect.fromCenter(center: Offset(w/2, h*0.9), width: w * 0.5, height: h * 0.1),
      shadowPaint,
    );

    // 2. Select material / theme
    switch (theme) {
      case 'lewis':
        _drawLewis(canvas, size);
        break;
      case 'mexico':
        _drawMexico(canvas, size);
        break;
      case 'angular':
        _drawAngular(canvas, size);
        break;
      default:
        _drawClassic(canvas, size);
    }
  }

  void _drawLewis(Canvas canvas, Size s) {
    final w = s.width; final h = s.height;
    final isWhite = piece.color == PieceColor.white;
    final baseColor = isWhite ? const Color(0xFFF5E6CA) : const Color(0xFF8B6B4A);
    final highlightColor = isWhite ? Colors.white : const Color(0xFFD4B483);
    final shadeColor = isWhite ? const Color(0xFFD7C4A5) : const Color(0xFF4A3728);

    final mainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [highlightColor, baseColor, shadeColor],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final path = _getLewisPath(piece.type, s);
    canvas.drawPath(path, mainPaint);
    
    final detailPaint = Paint()..style = PaintingStyle.stroke..strokeWidth = 0.8..color = shadeColor.withValues(alpha: 0.4);
    canvas.drawPath(path, detailPaint);
  }

  void _drawMexico(Canvas canvas, Size s) {
    final w = s.width; final h = s.height;
    final isWhite = piece.color == PieceColor.white;
    final baseColor = isWhite ? const Color(0xFFE6B325) : const Color(0xFF0F3D3E);
    final highlightColor = isWhite ? const Color(0xFFFFD93D) : const Color(0xFF2ECC71);

    final mainPaint = Paint()
      ..shader = RadialGradient(
        colors: [highlightColor, baseColor, Colors.black],
        center: const Alignment(-0.3, -0.4),
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final path = _getMexicoPath(piece.type, s);
    canvas.drawPath(path, mainPaint);
  }

  void _drawAngular(Canvas canvas, Size s) {
    final w = s.width; final h = s.height;
    final isWhite = piece.color == PieceColor.white;
    final baseColor = isWhite ? const Color(0xFFBFC8D6) : const Color(0xFF2C3E50);
    
    final mainPaint = Paint()
      ..shader = LinearGradient(
        begin: Alignment.topLeft, end: Alignment.bottomRight,
        colors: [Colors.white.withValues(alpha: 0.9), baseColor, Colors.black.withValues(alpha: 0.8)],
        stops: const [0.0, 0.4, 1.0],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final path = _getAngularPath(piece.type, s);
    canvas.drawPath(path, mainPaint);
  }

  void _drawClassic(Canvas canvas, Size s) {
    final w = s.width; final h = s.height;
    final isWhite = piece.color == PieceColor.white;
    final baseColor = color;
    final light = isWhite ? Colors.white : color.withValues(alpha: 0.8);
    final dark = Colors.black.withValues(alpha: 0.8);

    final mainPaint = Paint()
      ..shader = RadialGradient(
        center: const Alignment(-0.25, -0.35),
        radius: 0.8,
        colors: [light, baseColor, dark],
      ).createShader(Rect.fromLTWH(0, 0, w, h));

    final path = _getPathForType(piece.type, s);
    canvas.drawPath(path, mainPaint);
  }

  Path _getLewisPath(PieceType type, Size s) {
    final w = s.width; final h = s.height;
    final p = Path();
    switch (type) {
      case PieceType.king:
        // King on throne with cross crown
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w*0.2, h*0.25, w*0.6, h*0.65), 12, 12));
        p.addRect(Rect.fromLTWH(w*0.35, h*0.12, w*0.3, h*0.15)); // crown base
        p.moveTo(w*0.5, h*0.02); p.lineTo(w*0.5, h*0.12); // cross vertical
        p.moveTo(w*0.42, h*0.07); p.lineTo(w*0.58, h*0.07); // cross horizontal
        break;
      case PieceType.queen:
        // Queen with hand on cheek pose (characteristic of Lewis)
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w*0.25, h*0.28, w*0.5, h*0.62), 14, 14));
        p.addOval(Rect.fromCircle(center: Offset(w*0.5, h*0.18), radius: w*0.12)); // crown
        break;
      case PieceType.bishop:
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w*0.3, h*0.32, w*0.4, h*0.58), 10, 10));
        p.moveTo(w*0.4, h*0.1); p.lineTo(w*0.5, h*0.32); p.lineTo(w*0.6, h*0.1); p.close(); // mitre
        break;
      case PieceType.knight:
        // Knight on small horse
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w*0.42, h*0.45, w*0.25, h*0.45), 4, 4)); // body
        p.moveTo(w*0.35, h*0.35); // head
        p.quadraticBezierTo(w*0.28, h*0.4, w*0.35, h*0.55); // neck
        p.lineTo(w*0.55, h*0.45); p.lineTo(w*0.5, h*0.25); // snout/ears
        p.close();
        break;
      case PieceType.rook:
        // Warder with shield
        p.addRect(Rect.fromLTWH(w*0.32, h*0.22, w*0.36, h*0.68));
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w*0.22, h*0.4, w*0.2, h*0.45), 2, 2)); // shield
        break;
      case PieceType.pawn:
        p.addOval(Rect.fromCenter(center: Offset(w*0.5, h*0.65), width: w*0.45, height: h*0.55));
        break;
    }
    return p;
  }

  Path _getMexicoPath(PieceType type, Size s) {
    final w = s.width; final h = s.height;
    final p = Path();
    switch (type) {
      case PieceType.king:
        p.addRect(Rect.fromLTWH(w*0.25, h*0.25, w*0.5, h*0.65));
        p.addPolygon([Offset(w*0.25, h*0.25), Offset(w*0.5, h*0.05), Offset(w*0.75, h*0.25)], true);
        break;
      case PieceType.queen:
        p.addRect(Rect.fromLTWH(w*0.3, h*0.3, w*0.4, h*0.6));
        p.addOval(Rect.fromCircle(center: Offset(w*0.5, h*0.15), radius: w*0.15));
        break;
      case PieceType.knight:
        // Stylized jaguar/serpent head
        p.moveTo(w*0.35, h*0.8); p.lineTo(w*0.65, h*0.8); p.lineTo(w*0.65, h*0.4);
        p.lineTo(w*0.4, h*0.25); p.lineTo(w*0.25, h*0.4); p.close();
        break;
      case PieceType.bishop:
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w*0.35, h*0.4, w*0.3, h*0.5), 6, 6));
        p.addPolygon([Offset(w*0.4, h*0.3), Offset(w*0.5, h*0.15), Offset(w*0.6, h*0.3)], true);
        break;
      case PieceType.rook:
        p.addRect(Rect.fromLTWH(w*0.3, h*0.2, w*0.4, h*0.75));
        p.addRect(Rect.fromLTWH(w*0.25, h*0.15, w*0.12, h*0.12));
        p.addRect(Rect.fromLTWH(w*0.63, h*0.15, w*0.12, h*0.12));
        break;
      case PieceType.pawn:
        p.addRect(Rect.fromLTWH(w*0.35, h*0.5, w*0.3, h*0.4));
        p.addOval(Rect.fromCircle(center: Offset(w*0.5, h*0.4), radius: w*0.15));
        break;
    }
    return p;
  }

  Path _getAngularPath(PieceType type, Size s) {
    final w = s.width; final h = s.height;
    final p = Path();
    switch (type) {
      case PieceType.king:
        p.moveTo(w*0.5, h*0.05); p.lineTo(w*0.85, h*0.85); p.lineTo(w*0.15, h*0.85); p.close();
        p.addRect(Rect.fromLTWH(w*0.48, h*0.1, w*0.04, h*0.15)); // cross
        p.addRect(Rect.fromLTWH(w*0.43, h*0.14, w*0.14, h*0.04));
        break;
      case PieceType.queen:
        p.addPolygon([Offset(w*0.5, h*0.1), Offset(w*0.8, h*0.3), Offset(w*0.7, h*0.85), Offset(w*0.3, h*0.85), Offset(w*0.2, h*0.3)], true);
        p.addOval(Rect.fromCircle(center: Offset(w*0.5, h*0.1), radius: w*0.05));
        break;
      case PieceType.knight:
        p.moveTo(w*0.4, h*0.85); p.lineTo(w*0.7, h*0.85); p.lineTo(w*0.7, h*0.4);
        p.lineTo(w*0.3, h*0.25); p.lineTo(w*0.4, h*0.4); p.close();
        break;
      case PieceType.bishop:
        p.addPolygon([Offset(w*0.5, h*0.2), Offset(w*0.7, h*0.5), Offset(w*0.5, h*0.85), Offset(w*0.3, h*0.5)], true);
        p.moveTo(w*0.5, h*0.3); p.lineTo(w*0.6, h*0.4); // mitre slit
        break;
      case PieceType.rook:
        p.addRect(Rect.fromLTWH(w*0.3, h*0.3, w*0.4, h*0.6));
        p.addRect(Rect.fromLTWH(w*0.25, h*0.15, w*0.15, h*0.2));
        p.addRect(Rect.fromLTWH(w*0.6, h*0.15, w*0.15, h*0.2));
        break;
      case PieceType.pawn:
        p.moveTo(w*0.5, h*0.4); p.lineTo(w*0.75, h*0.85); p.lineTo(w*0.25, h*0.85); p.close();
        p.addOval(Rect.fromCircle(center: Offset(w*0.5, h*0.35), radius: w*0.12));
        break;
    }
    return p;
  }

  Path _getPathForType(PieceType type, Size s) {
    final w = s.width; final h = s.height;
    final p = Path();
    switch (type) {
      case PieceType.king:
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w*0.3, h*0.25, w*0.4, h*0.65), 10, 10));
        p.addRect(Rect.fromLTWH(w*0.45, h*0.08, w*0.1, h*0.15));
        p.addRect(Rect.fromLTWH(w*0.4, h*0.12, w*0.2, h*0.07));
        break;
      case PieceType.queen:
        p.addOval(Rect.fromCircle(center: Offset(w*0.5, h*0.3), radius: w*0.25));
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w*0.3, h*0.5, w*0.4, h*0.4), 8, 8));
        p.addOval(Rect.fromCircle(center: Offset(w*0.5, h*0.15), radius: w*0.08));
        break;
      case PieceType.knight:
        p.moveTo(w*0.35, h*0.85); p.lineTo(w*0.65, h*0.85); p.lineTo(w*0.6, h*0.5);
        p.quadraticBezierTo(w*0.8, h*0.4, w*0.55, h*0.2); // head & ears
        p.lineTo(w*0.5, h*0.25); p.lineTo(w*0.3, h*0.35); // snout
        p.quadraticBezierTo(w*0.25, h*0.45, w*0.4, h*0.5); // neck
        p.close();
        break;
      case PieceType.bishop:
        p.addOval(Rect.fromCenter(center: Offset(w*0.5, h*0.35), width: w*0.3, height: h*0.45));
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w*0.35, h*0.6, w*0.3, h*0.3), 5, 5));
        p.moveTo(w*0.52, h*0.2); p.lineTo(w*0.43, h*0.3); // slit
        break;
      case PieceType.rook:
        p.addRect(Rect.fromLTWH(w*0.3, h*0.25, w*0.4, h*0.6));
        p.addRect(Rect.fromLTWH(w*0.28, h*0.18, w * 0.44, h * 0.1)); // top plate
        // Battlement gaps
        p.addRect(Rect.fromLTWH(w*0.32, h*0.1, w*0.06, h*0.1));
        p.addRect(Rect.fromLTWH(w*0.47, h*0.1, w*0.06, h*0.1));
        p.addRect(Rect.fromLTWH(w*0.62, h*0.1, w*0.06, h*0.1));
        break;
      case PieceType.pawn:
        p.addOval(Rect.fromCircle(center: Offset(w * 0.5, h * 0.35), radius: w * 0.15));
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w * 0.35, h * 0.55, w * 0.3, h * 0.35), 8, 8));
        break;
    }
    return p;
  }

  @override
  bool shouldRepaint(covariant _ObjectPiecePainter oldDelegate) => true;
}
