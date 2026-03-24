import 'package:flutter/material.dart';
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
            duration: const Duration(milliseconds: 200),
            curve: Curves.easeOut,
          );
        }
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    if (widget.moves.isEmpty) {
      return const Center(
        child: Text('No moves yet', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
      );
    }

    return ListView.builder(
      controller: _scrollController,
      scrollDirection: Axis.horizontal,
      itemCount: (widget.moves.length / 2).ceil(),
      itemBuilder: (context, index) {
        final whiteMove = widget.moves.length > index * 2 ? widget.moves[index * 2] : null;
        final blackMove = widget.moves.length > index * 2 + 1 ? widget.moves[index * 2 + 1] : null;

        return Container(
          margin: const EdgeInsets.only(right: 4),
          padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
          decoration: BoxDecoration(
            color: AppTheme.surface.withOpacity(0.6),
            borderRadius: BorderRadius.circular(8),
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('${index + 1}.', style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
              const SizedBox(width: 4),
              if (whiteMove != null)
                Text(
                  whiteMove.algebraic ?? '?',
                  style: const TextStyle(color: AppTheme.textPrimary, fontSize: 12, fontWeight: FontWeight.w600),
                ),
              if (blackMove != null) ...[
                const SizedBox(width: 6),
                Text(
                  blackMove.algebraic ?? '?',
                  style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12),
                ),
              ],
            ],
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
