import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';
import 'chess_piece_widget.dart';

class ChessBoardWidget extends StatefulWidget {
  final List<List<ChessPiece?>> board;
  final PieceColor perspective;
  final Square? selectedSquare;
  final List<Move> legalMoves;
  final Move? lastMove;
  final Move? hintMove;
  final Move? preMove;
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
  final Square? lastUndoPenaltySquare;

  const ChessBoardWidget({
    super.key,
    required this.board,
    required this.perspective,
    this.selectedSquare,
    this.legalMoves = const [],
    this.lastMove,
    this.hintMove,
    this.preMove,
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
    this.lastUndoPenaltySquare,
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
                    color: Colors.black.withOpacity(0.5),
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
                      if (widget.lastUndoPenaltySquare != null)
                        _buildUndoPenalty(
                            widget.lastUndoPenaltySquare!, sqSize),
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
    final themeData =
        AppTheme.boardThemes[theme] ?? AppTheme.boardThemes['classic']!;
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
          _highlight(
              widget.hintMove!.to, sqSize, AppTheme.hintSq.withOpacity(0.9)),
        ],
        // Selected piece
        if (widget.selectedSquare != null)
          _highlight(widget.selectedSquare!, sqSize,
              AppTheme.selectedSq.withOpacity(0.7)),
        // Legal moves
        ...widget.legalMoves.map((m) => _legalMoveIndicator(m, sqSize)),
        // Check highlight
        if (widget.status == GameStatus.check) _buildCheckHighlight(sqSize),
        // Correct Move Glow
        if (widget.lastCorrectMove != null) ...[
          _glowHighlight(widget.lastCorrectMove!.from, sqSize),
          _glowHighlight(widget.lastCorrectMove!.to, sqSize),
        ],
        // Pre Move Glow
        if (widget.preMove != null) ...[
          _highlight(
              widget.preMove!.from, sqSize, Colors.redAccent.withOpacity(0.6)),
          _highlight(
              widget.preMove!.to, sqSize, Colors.redAccent.withOpacity(0.6)),
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
          color: Colors.green.withOpacity(0.3),
          boxShadow: [
            BoxShadow(
              color: Colors.greenAccent.withOpacity(0.5),
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

  Widget _buildUndoPenalty(Square sq, double sqSize) {
    final (x, y) = _squareToPixel(sq, sqSize);
    return Positioned(
      left: x,
      top: y - (sqSize * 0.5), // Float above the square
      width: sqSize,
      height: sqSize,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.redAccent.withOpacity(0.9),
            borderRadius: BorderRadius.circular(12),
            boxShadow: [
              BoxShadow(
                color: Colors.black.withOpacity(0.3),
                blurRadius: 8,
                offset: const Offset(0, 4),
              ),
            ],
          ),
          child: Text(
            '-25 XP',
            style: GoogleFonts.outfit(
              color: Colors.white,
              fontWeight: FontWeight.bold,
              fontSize: sqSize * 0.25,
            ),
          ),
        ),
      )
          .animate()
          .fadeIn(duration: 200.ms)
          .slideY(
              begin: 0.5, end: -0.5, duration: 800.ms, curve: Curves.easeOut)
          .fadeOut(delay: 1000.ms, duration: 400.ms),
    );
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
      left: x,
      top: y,
      width: sqSize,
      height: sqSize,
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
        final pieceChild = ChessPieceWidget(
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
    final themeData = AppTheme.boardThemes[widget.boardTheme] ??
        AppTheme.boardThemes['classic']!;
    final notationColor = themeData.notation.withOpacity(0.8);

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
    final themeData = AppTheme.boardThemes[widget.boardTheme] ??
        AppTheme.boardThemes['classic']!;
    final notationColor = themeData.notation.withOpacity(0.35); // Subtle

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
