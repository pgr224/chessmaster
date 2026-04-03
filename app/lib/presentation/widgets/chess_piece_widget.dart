import 'package:flutter/material.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../domain/engine/chess_engine.dart';

/// A unified widget for rendering chess pieces with various shapes and styles.
class ChessPieceWidget extends StatelessWidget {
  final ChessPiece piece;
  final String shape;
  final String style;
  final double size;
  final Color? whitePieceColor;
  final Color? blackPieceColor;

  const ChessPieceWidget({
    super.key,
    required this.piece,
    required this.shape,
    required this.style,
    required this.size,
    this.whitePieceColor,
    this.blackPieceColor,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _buildPieceVisual(),
    );
  }

  Widget _buildPieceVisual() {
    final isWhite = piece.color == PieceColor.white;
    final baseColor = isWhite
        ? (whitePieceColor ?? Colors.white)
        : (blackPieceColor ?? Colors.black);

    // Legacy / Special Text Styles
    if (style == 'letters') return _buildLetterPiece(baseColor);
    if (style == '8-bit') return _build8BitPiece(baseColor);

    // Asset-based Styles (Default for unknown shapes)
    final isVectorShape = PiecePathProvider.isVectorShape(shape);

    if (isVectorShape) {
      return _buildSvgPiece(isWhite);
    }

    // Custom Painted Styles
    return ObjectPiece(
      piece: piece,
      shape: shape,
      style: style,
      size: size,
      color: baseColor,
      isWhite: isWhite,
    );
  }

  Widget _buildLetterPiece(Color color) {
    return Text(
      piece.symbol.toUpperCase(),
      style: GoogleFonts.jura(
        fontSize: size * 0.7,
        fontWeight: FontWeight.bold,
        color: color,
      ),
    );
  }

  Widget _build8BitPiece(Color color) {
    return Text(
      piece.symbol.toUpperCase(),
      style: GoogleFonts.vt323(
        fontSize: size * 0.5,
        color: color,
      ),
    );
  }

  Widget _buildSvgPiece(bool isWhite) {
    String path;
    if (shape == 'iconic' || shape == 'artwork') {
      final colorStr = isWhite ? 'white' : 'black';
      final typeStr = piece.type.name.toLowerCase();
      path = 'assets/pieces/$shape/`$1_$typeStr.svg';
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
      fit: BoxFit.contain,
      errorBuilder: (context, error, stackTrace) => Icon(
          Icons.help_outline_rounded,
          color: Colors.white24,
          size: size * 0.8),
    );
  }

  String _getPychessTypeChar(PieceType type) {
    switch (type) {
      case PieceType.pawn:
        return 'p';
      case PieceType.knight:
        return 'n';
      case PieceType.bishop:
        return 'b';
      case PieceType.rook:
        return 'r';
      case PieceType.queen:
        return 'q';
      case PieceType.king:
        return 'k';
    }
  }
}

class ObjectPiece extends StatelessWidget {
  final ChessPiece piece;
  final String shape;
  final String style;
  final double size;
  final Color color;
  final bool isWhite;

  const ObjectPiece({
    super.key,
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
        painter: ChessPiecePainter(
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

class ChessPiecePainter extends CustomPainter {
  final PieceType type;
  final Color color;
  final bool isWhite;
  final String shape;
  final String style;

  ChessPiecePainter({
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
    final path = PiecePathProvider.getPath(type, shape);

    final matrix = Matrix4.identity()
      ..storage[12] = center.dx
      ..storage[13] = center.dy
      ..storage[0] = scale
      ..storage[5] = scale;

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
          ..color = color.withOpacity(0.5)
          ..maskFilter = MaskFilter.blur(BlurStyle.normal, size.width * 0.1);
        canvas.drawPath(path, glowPaint);

        // Vibrant stroke
        strokePaint.color = color;
        strokePaint.strokeWidth = size.width * 0.04;
        strokePaint.maskFilter = MaskFilter.blur(BlurStyle.outer, 4);
        canvas.drawPath(path, strokePaint);

        // Base thin bright center
        paint.color = Colors.white.withOpacity(0.8);
        canvas.drawPath(path, paint);
        break;

      case 'metal':
        final gradient = LinearGradient(
          colors: isWhite
              ? [
                  const Color(0xFFFFD700),
                  const Color(0xfff9f9f9),
                  const Color(0xFFB8860B)
                ]
              : [const Color(0xFF434343), const Color(0xFF000000)],
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
        );
        paint.shader = gradient.createShader(Offset.zero & size);
        canvas.drawPath(path, paint);

        // Specular highlight
        final highlightPath = Path();
        final rect = path.getBounds();
        highlightPath.addOval(Rect.fromLTWH(rect.left + rect.width * 0.2,
            rect.top + rect.height * 0.1, rect.width * 0.3, rect.height * 0.2));
        canvas.drawPath(
            highlightPath,
            Paint()
              ..color = Colors.white.withOpacity(0.3)
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 5));
        break;

      case 'glass':
        paint.color = color.withOpacity(0.3);
        canvas.drawPath(path, paint);

        strokePaint.color = Colors.white.withOpacity(0.5);
        canvas.drawPath(path, strokePaint);

        // Refraction highlights
        final highlightPaint = Paint()
          ..color = Colors.white.withOpacity(0.4);
        canvas.drawCircle(Offset(size.width * 0.4, size.height * 0.35),
            size.width * 0.1, highlightPaint);
        break;

      case 'wood':
        final gradient = RadialGradient(
          colors: isWhite
              ? [const Color(0xFFD2B48C), const Color(0xFF8B4513)]
              : [const Color(0xFF5D4037), const Color(0xFF212121)],
          radius: 1.2,
        );
        paint.shader = gradient.createShader(Offset.zero & size);
        canvas.drawPath(path, paint);
        break;

      case 'luxury':
        paint.color =
            isWhite ? const Color(0xFFE8D5B5) : const Color(0xFF1A1A1A);
        canvas.drawPath(path, paint);

        strokePaint.color = const Color(0xFFC5A059);
        strokePaint.strokeWidth = 2.0;
        canvas.drawPath(path, strokePaint);
        break;

      case 'royal':
        paint.color =
            isWhite ? const Color(0xFFF5F5F5) : const Color(0xFF4A148C);
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
          colors: [color.withOpacity(0.8), color],
          center: const Alignment(-0.3, -0.3),
        );
        paint.shader = gradient.createShader(Offset.zero & size);
        canvas.drawPath(path, paint);

        // Drop shadow
        canvas.drawPath(
            path.shift(const Offset(2, 2)),
            Paint()
              ..color = Colors.black26
              ..maskFilter = const MaskFilter.blur(BlurStyle.normal, 2));
        break;
    }
  }

  @override
  bool shouldRepaint(covariant ChessPiecePainter oldDelegate) =>
      oldDelegate.type != type ||
      oldDelegate.style != style ||
      oldDelegate.shape != shape;
}

class PiecePathProvider {
  static Path getPath(PieceType type, String shape) {
    switch (shape) {
      case 'modern':
        return _getModernPath(type);
      case 'angular':
        return _getAngularPath(type);
      case 'wood':
        return _getWoodPath(type);
      case 'fantasy':
        return _getFantasyPath(type);
      case 'neo':
        return _getNeoPath(type);
      case 'classic':
      default:
        return _getClassicPath(type);
    }
  }

  static Path _getClassicPath(PieceType type) {
    final p = Path();
    switch (type) {
      case PieceType.pawn:
        p.moveTo(-15, 30);
        p.lineTo(15, 30);
        p.quadraticBezierTo(10, 25, 10, 10);
        p.addOval(const Rect.fromLTWH(-12, -15, 24, 24));
        break;
      case PieceType.rook:
        p.moveTo(-18, 30);
        p.lineTo(18, 30);
        p.lineTo(15, -10);
        p.lineTo(18, -10);
        p.lineTo(18, -25);
        p.lineTo(10, -25);
        p.lineTo(10, -20);
        p.lineTo(6, -20);
        p.lineTo(6, -25);
        p.lineTo(-6, -25);
        p.lineTo(-6, -20);
        p.lineTo(-10, -20);
        p.lineTo(-10, -25);
        p.lineTo(-18, -25);
        p.lineTo(-18, -10);
        p.lineTo(-15, -10);
        p.close();
        break;
      case PieceType.knight:
        p.moveTo(-15, 30);
        p.lineTo(15, 30);
        p.quadraticBezierTo(10, 10, 15, -10);
        p.quadraticBezierTo(20, -25, 0, -30);
        p.quadraticBezierTo(-25, -25, -15, -5);
        p.lineTo(-5, -5);
        p.lineTo(-15, 10);
        p.close();
        break;
      case PieceType.bishop:
        p.moveTo(-15, 30);
        p.lineTo(15, 30);
        p.quadraticBezierTo(10, 15, 10, 0);
        p.addOval(const Rect.fromLTWH(-12, -25, 24, 30));
        p.moveTo(0, -25);
        p.lineTo(0, -32);
        break;
      case PieceType.queen:
        p.moveTo(-18, 30);
        p.lineTo(18, 30);
        p.lineTo(12, 0);
        p.lineTo(20, -15);
        p.lineTo(8, -10);
        p.lineTo(0, -30);
        p.lineTo(-8, -10);
        p.lineTo(-20, -15);
        p.lineTo(-12, 0);
        p.close();
        break;
      case PieceType.king:
        p.moveTo(-18, 30);
        p.lineTo(18, 30);
        p.lineTo(12, -10);
        p.lineTo(15, -10);
        p.lineTo(15, -20);
        p.lineTo(5, -20);
        p.lineTo(5, -30);
        p.lineTo(-5, -30);
        p.lineTo(-5, -20);
        p.lineTo(-15, -20);
        p.lineTo(-15, -10);
        p.lineTo(-12, -10);
        p.close();
        break;
    }
    return p;
  }

  static Path _getModernPath(PieceType type) {
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
        p.moveTo(-15, 30);
        p.lineTo(15, 30);
        p.lineTo(15, 0);
        p.lineTo(0, -30);
        p.lineTo(-15, 0);
        p.close();
        break;
      case PieceType.bishop:
        p.moveTo(0, -30);
        p.lineTo(15, 30);
        p.lineTo(-15, 30);
        p.close();
        break;
      case PieceType.queen:
        p.addOval(const Rect.fromLTWH(-20, -20, 40, 40));
        p.addRect(const Rect.fromLTWH(-10, 10, 20, 20));
        break;
      case PieceType.king:
        p.addRect(const Rect.fromLTWH(-20, -20, 40, 40));
        p.moveTo(0, -35);
        p.lineTo(0, -15);
        p.moveTo(-10, -25);
        p.lineTo(10, -25);
        break;
    }
    return p;
  }

  static Path _getAngularPath(PieceType type) {
    final p = Path();
    switch (type) {
      case PieceType.pawn:
        p.moveTo(0, -20);
        p.lineTo(12, 10);
        p.lineTo(8, 30);
        p.lineTo(-8, 30);
        p.lineTo(-12, 10);
        p.close();
        break;
      case PieceType.rook:
        p.moveTo(-15, 30);
        p.lineTo(15, 30);
        p.lineTo(12, -15);
        p.lineTo(18, -15);
        p.lineTo(18, -30);
        p.lineTo(-18, -30);
        p.lineTo(-18, -15);
        p.lineTo(-12, -15);
        p.close();
        break;
      default:
        return _getClassicPath(type);
    }
    return p;
  }

  static Path _getWoodPath(PieceType type) {
    final p = Path();
    switch (type) {
      case PieceType.pawn:
        p.addOval(const Rect.fromLTWH(-15, 5, 30, 25));
        p.addOval(Rect.fromCircle(center: const Offset(0, -10), radius: 12));
        break;
      default:
        return _getClassicPath(type);
    }
    return p;
  }

  static Path _getFantasyPath(PieceType type) {
    final p = Path();
    switch (type) {
      case PieceType.knight:
        p.moveTo(-10, 30);
        p.lineTo(10, 30);
        p.lineTo(20, -10);
        p.lineTo(5, -35);
        p.lineTo(-15, -10);
        p.close();
        break;
      default:
        return _getClassicPath(type);
    }
    return p;
  }

  static Path _getNeoPath(PieceType type) {
    final p = Path();
    switch (type) {
      case PieceType.rook:
        p.addRect(const Rect.fromLTWH(-10, -30, 20, 60));
        p.addRect(const Rect.fromLTWH(-15, -35, 30, 5));
        break;
      default:
        return _getClassicPath(type);
    }
    return p;
  }

  static const List<String> pychessShapes = [
    'alfonso',
    'alila',
    'alpha',
    'california',
    'cardinal',
    'cburnett',
    'chess7',
    'chessicons',
    'chessmonk',
    'chessnut',
    'companion',
    'dubrovny',
    'fantasy',
    'freestaunton',
    'fresca',
    'gioco',
    'governor',
    'horsey',
    'icpieces',
    'kilfiger',
    'kosal',
    'leipzig',
    'libra',
    'maestro',
    'magnetic',
    'makruk',
    'merida',
    'merida_new',
    'metaltops',
    'pirat',
    'pirouetti',
    'pixel',
    'regular',
    'riohacha',
    'sittuyin',
    'staunty',
    'tatiana'
  ];

  static final Set<String> _customPathShapes = {
    'classic',
    'modern',
    'angular',
    'wood',
    'fantasy',
    'neo'
  };

  static bool isVectorShape(String shape) {
    // These are the shapes we handle via CustomPaint/Paths
    if (_customPathShapes.contains(shape)) return false;
    // Everything else is treated as a vector asset (Iconic, Artwork, PyChess, or future packs)
    return true;
  }
}
