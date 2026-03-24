import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';

class MoveHistoryWidget extends StatefulWidget {
  final List<Move> moves;
  const MoveHistoryWidget({super.key, required this.moves});

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
        child: Text('⏰ Waiting for moves...', 
          style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w500)),
      );
    }

    final moveCount = (widget.moves.length / 2).ceil();
    return ListView.builder(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      physics: const BouncingScrollPhysics(),
      padding: const EdgeInsets.symmetric(horizontal: 16),
      itemCount: moveCount,
      itemBuilder: (context, index) {
        final whiteMove = widget.moves.length > index * 2 ? widget.moves[index * 2] : null;
        final blackMove = widget.moves.length > index * 2 + 1 ? widget.moves[index * 2 + 1] : null;

        return Center(
          child: Container(
            margin: const EdgeInsets.only(right: 8),
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('${index + 1}.', style: GoogleFonts.fredoka(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600)),
                const SizedBox(width: 6),
                if (whiteMove != null)
                  Text(
                    whiteMove.algebraic ?? '?',
                    style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                  ),
                if (blackMove != null) ...[
                  const SizedBox(width: 8),
                  Text(
                    blackMove.algebraic ?? '?',
                    style: GoogleFonts.fredoka(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                  ),
                ],
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
