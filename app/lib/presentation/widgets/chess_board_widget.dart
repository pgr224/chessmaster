import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_svg/flutter_svg.dart';
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
  final String pieceShape;
  final String pieceStyle;
  final String moveAnimationSpeed;
  final bool showCoordinates;
  final bool showSquareLabels;
  final Color whitePieceColor;
  final Color blackPieceColor;
  final Function(Square)? onSquareTap;
  final bool isInteractive;
  final PieceColor currentTurn;
  final Move? lastCorrectMove;

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
    this.pieceShape = 'classic',
    this.pieceStyle = '3d',
    this.moveAnimationSpeed = 'normal',
    this.showCoordinates = true,
    this.showSquareLabels = false,
    this.whitePieceColor = Colors.white,
    this.blackPieceColor = Colors.black,
    this.onSquareTap,
    this.isInteractive = true,
    this.currentTurn = PieceColor.white,
    this.lastCorrectMove,
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
                      if (widget.showSquareLabels) _buildSquareLabels(sqSize),
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
        // Correct Move Glow
        if (widget.lastCorrectMove != null) ...[
          _glowHighlight(widget.lastCorrectMove!.from, sqSize),
          _glowHighlight(widget.lastCorrectMove!.to, sqSize),
        ],
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

  Widget _glowHighlight(Square sq, double sqSize) {
    final (x, y) = _squareToPixel(sq, sqSize);
    return Positioned(
      left: x,
      top: y,
      width: sqSize,
      height: sqSize,
      child: Container(
        decoration: BoxDecoration(
          color: Colors.green.withValues(alpha: 0.3),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withValues(alpha: 0.5),
              blurRadius: 15,
              spreadRadius: 2,
            ),
          ],
        ),
      ).animate().fadeIn(duration: 300.ms).then().fadeOut(delay: 600.ms),
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
    // Find the king that is in check - it's the king whose turn it is
    // (they need to get out of check)
    final checkedColor = widget.currentTurn;
    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        final p = widget.board[r][f];
        if (p?.type == PieceType.king && p?.color == checkedColor) {
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
          shape: widget.pieceShape,
          style: widget.pieceStyle,
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

  Widget _buildSquareLabels(double sqSize) {
    final themeData = AppTheme.boardThemes[widget.boardTheme] ?? AppTheme.boardThemes['classic']!;
    final notationColor = themeData.notation.withValues(alpha: 0.35); // Subtle

    return Positioned.fill(
      child: Stack(
        children: List.generate(64, (index) {
          final r = index ~/ 8;
          final f = index % 8;
          final rank = 7 - r;
          final file = f;
          
          // Logical coordinates based on perspective
          int displayFile, displayRank;
          if (widget.perspective == PieceColor.white) {
            displayFile = file;
            displayRank = r;
          } else {
            displayFile = 7 - file;
            displayRank = 7 - r;
          }

          final label = '${String.fromCharCode(97 + file)}${rank + 1}';
          
          return Positioned(
            left: displayFile * sqSize + 2,
            top: displayRank * sqSize + 2,
            child: Text(
              label,
              style: GoogleFonts.jura(
                fontSize: sqSize * 0.14,
                fontWeight: FontWeight.bold,
                color: notationColor,
              ),
            ),
          );
        }),
      ),
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
  final String shape;
  final String style;
  final double size;
  final Color whitePieceColor;
  final Color blackPieceColor;

  const _PieceWidget({
    required this.piece,
    required this.shape,
    required this.style,
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

    // Filter special text themes (legacy)
    if (style == 'letters') return _buildLetterPiece(isWhite, baseColor);
    if (style == '8-bit') return _build8BitPiece(isWhite, baseColor);

    // Support Pychess SVGs
    final isVectorShape = shape == 'iconic' || 
                         shape == 'artwork' || 
                         _PiecePathProvider._isPyChessShape(shape);

    if (isVectorShape) {
      return _buildSvgPiece(isWhite);
    }

    return _ObjectPiece(
      piece: piece,
      shape: shape,
      style: style,
      size: size,
      color: baseColor,
      isWhite: isWhite,
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

  Widget _buildSvgPiece(bool isWhite) {
    String path;
    if (shape == 'iconic' || shape == 'artwork') {
      final colorStr = isWhite ? 'white' : 'black';
      final typeStr = piece.type.name;
      path = 'assets/pieces/$shape/${colorStr}_$typeStr.svg';
    } else {
      // Pychess logic
      final colorStr = isWhite ? 'w' : 'b';
      final typeStr = _getPychessTypeChar(piece.type);
      path = 'assets/pieces/pychess/$shape/$colorStr$typeStr.svg';
    }
    
    return SvgPicture.asset(
      path,
      width: size,
      height: size,
    );
  }

  String _getPychessTypeChar(PieceType type) {
    switch (type) {
      case PieceType.pawn: return 'p';
      case PieceType.knight: return 'n';
      case PieceType.bishop: return 'b';
      case PieceType.rook: return 'r';
      case PieceType.queen: return 'q';
      case PieceType.king: return 'k';
    }
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
  final String shape;
  final String style;
  final double size;
  final Color color;
  final bool isWhite;

  const _ObjectPiece({
    required this.piece,
    required this.shape,
    required this.style,
    required this.size,
    required this.color,
    required this.isWhite,
  });

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      width: size,
      height: size,
      child: CustomPaint(
        size: Size(size, size),
        painter: _ChessPiecePainter(
          type: piece.type,
          color: color,
          isWhite: isWhite,
          shape: shape,
          style: style,
        ),
      ),
    );
  }
}

class _ChessPiecePainter extends CustomPainter {
  final PieceType type;
  final Color color;
  final bool isWhite;
  final String shape;
  final String style;

  _ChessPiecePainter({
    required this.type,
    required this.color,
    required this.isWhite,
    required this.shape,
    required this.style,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final scale = size.width / 100;
    
    // 1. Get Path based on Shape
    final path = _PiecePathProvider.getPath(type, shape);
    
    // Scale and center the path with legacy matrix ops (ignoring deprecation for 2D safety)
    final matrix = Matrix4.identity()
      // ignore: deprecated_member_use
      ..translate(center.dx, center.dy)
      // ignore: deprecated_member_use
      ..scale(scale);


    final finalPath = path.transform(matrix.storage);

    // 2. Apply Style logic
    _drawStyledPiece(canvas, finalPath, size);
  }

  void _drawStyledPiece(Canvas canvas, Path path, Size size) {
    final paint = Paint()..style = PaintingStyle.fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = size.width * 0.02;

    switch (style) {
      case 'neon':
        // Inner glow
        final glowPaint = Paint()
          ..color = color.withValues(alpha: 0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.1);
        canvas.drawPath(path, glowPaint);
        
        // Vibrant stroke
        strokePaint.color = color;
        strokePaint.strokeWidth = size.width * 0.04;
        strokePaint.maskFilter = MaskFilter.blur(BlurStyle.outer, 4);
        canvas.drawPath(path, strokePaint);
        
        // Base thin bright center
        paint.color = Colors.white.withValues(alpha: 0.8);
        canvas.drawPath(path, paint);
        break;

      case 'metal':
        final gradient = LinearGradient(
          colors: isWhite 
              ? [const Color(0xFFFFD700), const Color(0xfff9f9f9), const Color(0xFFB8860B)]
              : [const Color(0xFF434343), const Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        paint.shader = gradient.createShader(Offset.zero & size);
        canvas.drawPath(path, paint);
        
        // Specular highlight
        final highlightPath = Path();
        final rect = path.getBounds();
        highlightPath.addOval(Rect.fromLTWH(rect.left + rect.width*0.2, rect.top + rect.height*0.1, rect.width*0.3, rect.height*0.2));
        canvas.drawPath(highlightPath, Paint()..color = Colors.white.withValues(alpha: 0.3)..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        break;

      case 'glass':
        paint.color = color.withValues(alpha: 0.3);
        canvas.drawPath(path, paint);
        
        strokePaint.color = Colors.white.withValues(alpha: 0.5);
        canvas.drawPath(path, strokePaint);
        
        // Refraction highlights
        final highlightPaint = Paint()..color = Colors.white.withValues(alpha: 0.4);
        canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.35), size.width * 0.1, highlightPaint);
        break;

      case 'wood':
        final gradient = RadialGradient(
          colors: isWhite ? [const Color(0xFFD2B48C), const Color(0xFF8B4513)] : [const Color(0xFF5D4037), const Color(0xFF212121)],
          radius: 1.2,
        );
        paint.shader = gradient.createShader(Offset.zero & size);
        canvas.drawPath(path, paint);
        break;

      case 'luxury':
        paint.color = isWhite ? const Color(0xFFE8D5B5) : const Color(0xFF1A1A1A);
        canvas.drawPath(path, paint);
        
        strokePaint.color = const Color(0xFFC5A059);
        strokePaint.strokeWidth = 2.0;
        canvas.drawPath(path, strokePaint);
        break;

      case 'royal':
        paint.color = isWhite ? const Color(0xFFF5F5F5) : const Color(0xFF4A148C);
        canvas.drawPath(path, paint);
        
        // Gold trim
        strokePaint.color = const Color(0xFFFFD700);
        strokePaint.strokeWidth = size.width * 0.05;
        canvas.drawPath(path, strokePaint);
        break;

      case '3d':
      default:
        // Default shaded look
        final gradient = RadialGradient(
          colors: [color.withValues(alpha: 0.8), color],
          center: const Alignment(-0.3, -0.3),
        );
        paint.shader = gradient.createShader(Offset.zero & size);
        canvas.drawPath(path, paint);
        
        // Drop shadow
        canvas.drawPath(path.shift(const Offset(2, 2)), Paint()..color=Colors.black26..maskFilter=const MaskFilter.blur(BlurStyle.normal, 2));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant _ChessPiecePainter oldDelegate) => 
    oldDelegate.type != type || oldDelegate.style != style || oldDelegate.shape != shape;
}

class _PiecePathProvider {
  static Path getPath(PieceType type, String shape) {
    switch (shape) {
      case 'modern': return _getModernPath(type);
      case 'angular': return _getAngularPath(type);
      case 'wood': return _getWoodPath(type);
      case 'fantasy': return _getFantasyPath(type);
      case 'neo': return _getNeoPath(type);
      case 'classic':
      default: return _getClassicPath(type);
    }
  }

  static Path _getClassicPath(PieceType type) {
    final p = Path();
    switch (type) {
      case PieceType.pawn:
        p.moveTo(-15, 30); p.lineTo(15, 30);
        p.quadraticBezierTo(10, 25, 10, 10);
        p.addOval(const Rect.fromLTWH(-12, -15, 24, 24));
        break;
      case PieceType.rook:
        p.moveTo(-18, 30); p.lineTo(18, 30);
        p.lineTo(15, -10); p.lineTo(18, -10); p.lineTo(18, -25);
        p.lineTo(10, -25); p.lineTo(10, -20); p.lineTo(6, -20); p.lineTo(6, -25);
        p.lineTo(-6, -25); p.lineTo(-6, -20); p.lineTo(-10, -20); p.lineTo(-10, -25);
        p.lineTo(-18, -25); p.lineTo(-18, -10); p.lineTo(-15, -10); p.close();
        break;
      case PieceType.knight:
        p.moveTo(-15, 30); p.lineTo(15, 30);
        p.quadraticBezierTo(10, 10, 15, -10);
        p.quadraticBezierTo(20, -25, 0, -30);
        p.quadraticBezierTo(-25, -25, -15, -5);
        p.lineTo(-5, -5); p.lineTo(-15, 10); p.close();
        break;
      case PieceType.bishop:
        p.moveTo(-15, 30); p.lineTo(15, 30);
        p.quadraticBezierTo(10, 15, 10, 0);
        p.addOval(const Rect.fromLTWH(-12, -25, 24, 30));
        p.moveTo(0, -25); p.lineTo(0, -32);
        break;
      case PieceType.queen:
        p.moveTo(-18, 30); p.lineTo(18, 30);
        p.lineTo(12, 0);
        p.lineTo(20, -15); p.lineTo(8, -10); p.lineTo(0, -30); p.lineTo(-8, -10); p.lineTo(-20, -15);
        p.lineTo(-12, 0); p.close();
        break;
      case PieceType.king:
        p.moveTo(-18, 30); p.lineTo(18, 30);
        p.lineTo(12, -10); p.lineTo(15, -10); p.lineTo(15, -20);
        p.lineTo(5, -20); p.lineTo(5, -30); p.lineTo(-5, -30); p.lineTo(-5, -20);
        p.lineTo(-15, -20); p.lineTo(-15, -10); p.lineTo(-12, -10); p.close();
        break;
    }
    return p;
  }

  static Path _getModernPath(PieceType type) {
    // Minimalist shapes
    final p = Path();
    switch (type) {
      case PieceType.pawn:
        p.addRect(const Rect.fromLTWH(-10, 0, 20, 30));
        p.addOval(Rect.fromCircle(center: const Offset(0, -10), radius: 10));
        break;
      case PieceType.rook:
        p.addRect(const Rect.fromLTWH(-15, -20, 30, 50));
        break;
      case PieceType.knight:
        p.moveTo(-15, 30); p.lineTo(15, 30); p.lineTo(15, 0); p.lineTo(0, -30); p.lineTo(-15, 0); p.close();
        break;
      case PieceType.bishop:
        p.moveTo(0, -30); p.lineTo(15, 30); p.lineTo(-15, 30); p.close();
        break;
      case PieceType.queen:
        p.addOval(const Rect.fromLTWH(-20, -20, 40, 40));
        p.addRect(const Rect.fromLTWH(-10, 10, 20, 20));
        break;
      case PieceType.king:
        p.addRect(const Rect.fromLTWH(-20, -20, 40, 40));
        p.moveTo(0, -35); p.lineTo(0, -15); p.moveTo(-10, -25); p.lineTo(10, -25);
        break;
    }
    return p;
  }

  static Path _getAngularPath(PieceType type) {
    // Sharp faceted geometry
    final p = Path();
    switch (type) {
      case PieceType.pawn:
        p.moveTo(0, -20); p.lineTo(12, 10); p.lineTo(8, 30); p.lineTo(-8, 30); p.lineTo(-12, 10); p.close();
        break;
      case PieceType.rook:
        p.moveTo(-15, 30); p.lineTo(15, 30); p.lineTo(12, -15); p.lineTo(18, -15); p.lineTo(18, -30);
        p.lineTo(-18, -30); p.lineTo(-18, -15); p.lineTo(-12, -15); p.close();
        break;
      default: return _getClassicPath(type); // Fallback for brevity in this step
    }
    return p;
  }

  static Path _getWoodPath(PieceType type) {
    // Soft, rounded silhouettes
    final p = Path();
    switch (type) {
      case PieceType.pawn:
        p.addOval(const Rect.fromLTWH(-15, 5, 30, 25));
        p.addOval(Rect.fromCircle(center: const Offset(0, -10), radius: 12));
        break;
      default: return _getClassicPath(type);
    }
    return p;
  }
  
  static Path _getFantasyPath(PieceType type) {
    // Spartan / Gothic
    final p = Path();
    switch (type) {
      case PieceType.knight:
        p.moveTo(-10, 30); p.lineTo(10, 30); p.lineTo(20, -10); p.lineTo(5, -35); p.lineTo(-15, -10); p.close();
        break;
      default: return _getClassicPath(type);
    }
    return p;
  }

  static Path _getNeoPath(PieceType type) {
    // Sleek and tall
    final p = Path();
    switch (type) {
      case PieceType.rook:
        p.addRect(const Rect.fromLTWH(-10, -30, 20, 60));
        p.addRect(const Rect.fromLTWH(-15, -35, 30, 5));
        break;
      default: return _getClassicPath(type);
    }
    return p;
  }

  static final Set<String> _pychessShapes = {
    'alfonso', 'alila', 'alpha', 'atopdown', 'california', 'cardinal', 'cburnett',
    'celtic', 'chess7', 'chessicons', 'chessmonk', 'chessnut', 'companion',
    'dubrovny', 'eyes', 'fantasy', 'fantasy_alt', 'freak', 'freestaunton',
    'fresca', 'gioco', 'governor', 'horsey', 'icpieces', 'kilfiger', 'kosal',
    'leipzig', 'letter', 'libra', 'maestro', 'magnetic', 'makruk', 'maya',
    'merida', 'merida_new', 'metaltops', 'pirat', 'pirouetti', 'pixel', 'prmi',
    'regular', 'reillycraig', 'riohacha', 'shapes', 'sittuyin', 'skulls',
    'spatial', 'staunty', 'tatiana'
  };

  static bool _isPyChessShape(String s) => _pychessShapes.contains(s);
}


