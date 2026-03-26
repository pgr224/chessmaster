import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/router/app_router.dart';
import '../../blocs/auth/auth_bloc.dart';
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
          prev.status != current.status ||
          prev.gameReason != current.gameReason,
      listener: (context, mpState) {
        if (mpState.gameReason == 'disconnect_timeout') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opponent left: disconnect timeout')),
          );
        }
        if (mpState.status == MultiplayerStatus.gameOver && mpState.gameReason != null) {
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Match ended: ${_friendlyCause(mpState.gameReason)}')),
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
                (prev.lastMoveFrom != current.lastMoveFrom || prev.lastMoveTo != current.lastMoveTo) && 
                current.lastMoveFrom != null,
              listener: (context, state) {
                context.read<GameBloc>().add(GameMakeMoveEvent(
                  Square.fromString(state.lastMoveFrom!),
                  Square.fromString(state.lastMoveTo!),
                  promotion: state.lastMovePromotion != null ? PieceType.values.byName(state.lastMovePromotion!) : null,
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
