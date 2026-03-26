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
    final center = Offset(w / 2, h / 2);

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
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w*0.25, h*0.2, w*0.5, h*0.7), 4, 4));
        p.addRect(Rect.fromLTWH(w*0.35, h*0.1, w*0.3, h*0.15));
        break;
      case PieceType.pawn:
        p.addOval(Rect.fromCenter(center: Offset(w*0.5, h*0.6), width: w*0.4, height: h*0.5));
        break;
      default:
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w*0.3, h*0.3, w*0.4, h*0.6), 8, 8));
    }
    return p;
  }

  Path _getMexicoPath(PieceType type, Size s) {
    final w = s.width; final h = s.height;
    final p = Path();
    p.addRRect(RRect.fromRectAndRadius(Rect.fromLTWH(w*0.3, h*0.3, w*0.4, h*0.6), Radius.circular(w*0.05)));
    return p;
  }

  Path _getAngularPath(PieceType type, Size s) {
    final w = s.width; final h = s.height;
    final p = Path();
    p.moveTo(w*0.5, h*0.1); p.lineTo(w*0.8, h*0.8); p.lineTo(w*0.2, h*0.8); p.close();
    return p;
  }

  Path _getPathForType(PieceType type, Size s) {
    final w = s.width; final h = s.height;
    final p = Path();
    switch (type) {
      case PieceType.pawn:
        p.addOval(Rect.fromCircle(center: Offset(w * 0.5, h * 0.3), radius: w * 0.15));
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w * 0.3, h * 0.45, w * 0.4, h * 0.45), 8, 8));
        break;
      case PieceType.rook:
        p.addRRect(RRect.fromRectXY(Rect.fromLTWH(w * 0.25, h * 0.2, w * 0.5, h * 0.75), 4, 4));
        break;
      default:
        p.addOval(Rect.fromCircle(center: Offset(w * 0.5, h * 0.5), radius: w * 0.4));
    }
    return p;
  }

  @override
  bool shouldRepaint(covariant _ObjectPiecePainter oldDelegate) => true;
}
