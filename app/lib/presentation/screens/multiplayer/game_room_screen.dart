import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/multiplayer/multiplayer_bloc.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../game/game_screen.dart';
import '../../widgets/chat_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';

class GameRoomScreen extends StatelessWidget {
  final String gameId;
  const GameRoomScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MultiplayerBloc, MultiplayerState>(
      listenWhen: (prev, current) => 
          prev.opponentLeft != current.opponentLeft || 
          prev.status != current.status ||
          prev.gameEndCause != current.gameEndCause,
      listener: (context, mpState) {
        if (mpState.opponentLeft) {
          final cause = _friendlyCause(mpState.gameEndCause);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Opponent left: $cause')),
          );
        }
        if (mpState.status == MultiplayerStatus.gameOver && mpState.gameEndCause != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Match ended: ${_friendlyCause(mpState.gameEndCause)}')),
          );
        }
        if (mpState.status == MultiplayerStatus.disconnected) {
          context.go('/home');
        }
      },
      builder: (context, mpState) {
        if (mpState.status != MultiplayerStatus.inGame) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final config = GameConfig(
          mode: GameMode.multiplayer,
          playerColor: mpState.playerColor?.name ?? 'white',
          boardTheme: context.read<ThemeBloc>().state.boardTheme,
          pieceTheme: context.read<ThemeBloc>().state.pieceTheme,
        );

        return MultiBlocListener(
          listeners: [
            // Sync Multiplayer -> Game (Opponent made a move)
            BlocListener<MultiplayerBloc, MultiplayerState>(
              listenWhen: (prev, current) => 
                prev.lastOpponentMove != current.lastOpponentMove && 
                current.lastOpponentMove != null,
              listener: (context, state) {
                final move = state.lastOpponentMove!;
                context.read<GameBloc>().add(GameMakeMoveEvent(
                  Square.fromString(move.from),
                  Square.fromString(move.to),
                  promotion: move.promotion != null ? PieceType.values.byName(move.promotion!) : null,
                ));
              },
            ),
            // Sync Game -> Multiplayer (Player made a move)
            BlocListener<GameBloc, GameState>(
              listenWhen: (prev, current) => 
                prev.moveHistory.length < current.moveHistory.length &&
                current.currentTurn != current.playerColor, // Means player just moved
              listener: (context, state) {
                if (state.moveHistory.isNotEmpty && state.mode == GameMode.multiplayer) {
                  final lastMove = state.moveHistory.last;
                  context.read<MultiplayerBloc>().add(
                    MpMakeMoveEvent(lastMove.from.toString(), lastMove.to.toString(), promotion: lastMove.promotion?.name)
                  );
                }
              },
            ),
          ],
          child: Scaffold(
            backgroundColor: Colors.transparent,
            floatingActionButton: FloatingActionButton(
              onPressed: () => _showChat(context),
              backgroundColor: AppTheme.goldPrimary,
              child: const Icon(Icons.chat_bubble_rounded, color: AppTheme.midnight),
            ),
            body: GameScreen(config: config),
          ),
        );
      },
    );
  }

  void _showChat(BuildContext context) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.8,
        child: BlocBuilder<MultiplayerBloc, MultiplayerState>(
          builder: (context, state) {
            return ChatWidget(
              messages: state.chatMessages,
              onSendMessage: (msg) => context.read<MultiplayerBloc>().add(MpSendChatEvent(msg)),
            );
          },
        ),
      ),
    );
  }

  String _friendlyCause(String? cause) {
    switch (cause) {
      case 'resignation_user_quit':
      case 'resign':
        return 'resignation';
      case 'agreement':
        return 'draw agreement';
      case 'network_disconnect':
      case 'network_disconnect_or_app_crash':
        return 'network disconnect / app crash';
      default:
        return cause ?? 'unknown reason';
    }
  }
}
