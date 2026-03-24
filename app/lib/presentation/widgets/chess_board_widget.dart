import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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
  final bool showCoordinates;
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
    this.showCoordinates = true,
    this.onSquareTap,
    this.isInteractive = true,
  });

  @override
  State<ChessBoardWidget> createState() => _ChessBoardWidgetState();
}

class _ChessBoardWidgetState extends State<ChessBoardWidget>
    with TickerProviderStateMixin {
  late AnimationController _moveAnimController;
  Square? _animatingPieceSrc;
  Square? _animatingPieceDst;

  @override
  void initState() {
    super.initState();
    _moveAnimController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 200),
    );
  }

  @override
  void dispose() {
    _moveAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return LayoutBuilder(
      builder: (context, constraints) {
        final size = constraints.maxWidth < constraints.maxHeight 
            ? constraints.maxWidth 
            : constraints.maxHeight;
        final sqSize = size / 8;
        return Container(
          width: size,
          height: size,
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(8),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withOpacity(0.5),
                  blurRadius: 24,
                  offset: const Offset(0, 12),
                ),
              ],
            ),
            child: ClipRRect(
              borderRadius: BorderRadius.circular(8),
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
          );
        },
      ),
    );
  }

  Widget _buildBoardGrid(double sqSize) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
      itemCount: 64,
      itemBuilder: (context, index) {
        final file = index % 8;
        final rank = 7 - (index ~/ 8);
        final isLight = (file + rank) % 2 == 1;
        return _squareColor(isLight, widget.boardTheme);
      },
    );
  }

  Widget _squareColor(bool isLight, String theme) {
    Color light, dark;
    switch (theme) {
      case 'neon':
        light = AppTheme.neonLight;
        dark = AppTheme.neonDark;
        break;
      case 'wood':
        light = AppTheme.woodLight;
        dark = AppTheme.woodDark;
        break;
      case 'minimal':
        light = const Color(0xFFEEEEEE);
        dark = const Color(0xFF555555);
        break;
      default:
        light = AppTheme.lightSquare;
        dark = AppTheme.darkSquare;
    }
    return ColoredBox(color: isLight ? light : dark);
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
          _highlight(widget.hintMove!.to, sqSize, AppTheme.hintSq.withOpacity(0.9)),
        ],
        // Selected piece
        if (widget.selectedSquare != null)
          _highlight(widget.selectedSquare!, sqSize, AppTheme.selectedSq.withOpacity(0.7)),
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
    return Positioned(
      left: x, top: y, width: sqSize, height: sqSize,
      child: Container(color: AppTheme.checkSq)
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .fadeIn(duration: 500.ms)
          .then()
          .fadeOut(duration: 500.ms),
    );
  }

  Widget _buildPieces(double sqSize) {
    final pieces = <Widget>[];
    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        final piece = widget.board[r][f];
        if (piece == null) continue;
        final sq = Square(f, r);
        final (x, y) = _squareToPixel(sq, sqSize);
        pieces.add(
          Positioned(
            key: ValueKey('${piece.color.name}${piece.type.name}$f$r'),
            left: x,
            top: y,
            width: sqSize,
            height: sqSize,
            child: _PieceWidget(
              piece: piece,
              theme: widget.pieceTheme,
              size: sqSize * 0.9,
            ).animate().scale(
              duration: 150.ms,
              curve: Curves.easeOutBack,
            ),
          ),
        );
      }
    }
    return Stack(children: pieces);
  }

  Widget _buildCoordinates(double sqSize) {
    return Stack(
      children: [
        // Files (a-h)
        ...List.generate(8, (f) {
          final flipF = widget.perspective == PieceColor.black ? 7 - f : f;
          return Positioned(
            left: flipF * sqSize + sqSize * 0.04,
            bottom: 2,
            child: Text(
              String.fromCharCode(97 + f),
              style: TextStyle(
                fontSize: sqSize * 0.18,
                fontWeight: FontWeight.bold,
                color: (f + 0) % 2 == 0
                    ? AppTheme.lightSquare.withOpacity(0.8)
                    : AppTheme.darkSquare.withOpacity(0.8),
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
                fontWeight: FontWeight.bold,
                color: (r + 0) % 2 == 1
                    ? AppTheme.lightSquare.withOpacity(0.8)
                    : AppTheme.darkSquare.withOpacity(0.8),
              ),
            ),
          );
        }),
      ],
    );
  }

  Widget _buildTapOverlay(double sqSize) {
    return GridView.builder(
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(crossAxisCount: 8),
      itemCount: 64,
      itemBuilder: (context, index) {
        final file = index % 8;
        final rank = 7 - index ~/ 8;
        final sq = widget.perspective == PieceColor.white
            ? Square(file, rank)
            : Square(7 - file, 7 - rank);
        return GestureDetector(
          onTap: () => widget.onSquareTap?.call(sq),
          behavior: HitTestBehavior.translucent,
          child: const SizedBox.expand(),
        );
      },
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

  const _PieceWidget({
    required this.piece,
    required this.theme,
    required this.size,
  });

  @override
  Widget build(BuildContext context) {
    return Center(
      child: _buildPieceVisual(),
    );
  }

  Widget _buildPieceVisual() {
    final isWhite = piece.color == PieceColor.white;
    return Text(
      piece.symbol,
      style: TextStyle(
        fontFamily: 'ChessMerida',
        fontSize: size * 0.85,
        color: isWhite ? Colors.white : Colors.black, // Ensure good contrast
        shadows: [
          Shadow(
            color: isWhite ? Colors.black.withValues(alpha: 0.3) : Colors.white.withValues(alpha: 0.1),
            blurRadius: 2,
            offset: const Offset(1, 1),
          ),
        ],
      ),
    );
  }
}
