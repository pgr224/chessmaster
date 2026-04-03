import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';
import '../blocs/game/game_bloc.dart';

class MoveHistoryWidget extends StatefulWidget {
  final List<Move> moves;
  final Axis scrollDirection;
  final String? currentFen; // Required to explain historical moves
  final List<String> fens; // Historical FENs

  const MoveHistoryWidget({
    super.key,
    required this.moves,
    this.scrollDirection = Axis.vertical,
    this.currentFen,
    this.fens = const [],
  });

  @override
  State<MoveHistoryWidget> createState() => _MoveHistoryWidgetState();
}

class _MoveHistoryWidgetState extends State<MoveHistoryWidget> {
  final _scrollController = ScrollController();

  @override
  void didUpdateWidget(MoveHistoryWidget old) {
    super.didUpdateWidget(old);
    if (widget.moves.length != old.moves.length) {
      WidgetsBinding.instance.addPostFrameCallback((_) {
        if (_scrollController.hasClients) {
          _scrollController.animateTo(
            _scrollController.position.maxScrollExtent,
            duration: const Duration(milliseconds: 300),
            curve: Curves.easeOutCubic,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.moves.isEmpty) {
      return Center(
        child: Text('Waiting for moves...',
            style: GoogleFonts.baloo2(
                color: AppTheme.textMuted,
                fontSize: 13,
                fontWeight: FontWeight.w500)),
      );
    }

    final moveCount = (widget.moves.length / 2).ceil();
    return ListView.builder(
      controller: _scrollController,
      scrollDirection: widget.scrollDirection,
      physics: const BouncingScrollPhysics(),
      padding: widget.scrollDirection == Axis.horizontal
          ? const EdgeInsets.symmetric(horizontal: 16)
          : const EdgeInsets.symmetric(vertical: 8),
      itemCount: moveCount,
      itemBuilder: (context, index) {
        final whiteMove =
            widget.moves.length > index * 2 ? widget.moves[index * 2] : null;
        final blackMove = widget.moves.length > index * 2 + 1
            ? widget.moves[index * 2 + 1]
            : null;

        return Padding(
          padding: widget.scrollDirection == Axis.horizontal
              ? const EdgeInsets.only(right: 8)
              : const EdgeInsets.only(bottom: 8),
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: AppTheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withOpacity(0.05)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                SizedBox(
                  width: 24,
                  child: Text('${index + 1}.',
                      style: GoogleFonts.fredoka(
                          color: AppTheme.textMuted,
                          fontSize: 11,
                          fontWeight: FontWeight.w600)),
                ),
                const SizedBox(width: 4),
                if (whiteMove != null)
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        final fen = widget.fens.length > index * 2
                            ? widget.fens[index * 2]
                            : widget.currentFen;
                        if (fen != null) {
                          context.read<GameBloc>().add(
                              GameExplainMoveEvent(move: whiteMove, fen: fen));
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Text(
                          whiteMove.algebraic ?? '?',
                          style: GoogleFonts.fredoka(
                              color: AppTheme.textPrimary,
                              fontSize: 14,
                              fontWeight: FontWeight.w700),
                        ),
                      ),
                    ),
                  ),
                if (blackMove != null)
                  Expanded(
                    child: InkWell(
                      onTap: () {
                        final fen = widget.fens.length > index * 2 + 1
                            ? widget.fens[index * 2 + 1]
                            : widget.currentFen;
                        if (fen != null) {
                          context.read<GameBloc>().add(
                              GameExplainMoveEvent(move: blackMove, fen: fen));
                        }
                      },
                      borderRadius: BorderRadius.circular(4),
                      child: Padding(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 4, vertical: 2),
                        child: Text(
                          blackMove.algebraic ?? '?',
                          style: GoogleFonts.fredoka(
                              color: AppTheme.textSecondary,
                              fontSize: 14,
                              fontWeight: FontWeight.w600),
                        ),
                      ),
                    ),
                  ),
              ],
            ),
          ),
        );
      },
    );
  }

  @override
  void dispose() {
    _scrollController.dispose();
    super.dispose();
  }
}
