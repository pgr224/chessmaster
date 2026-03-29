import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/app_router.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/multiplayer/multiplayer_bloc.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../game/game_screen.dart';
import '../../widgets/chat_widget.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';
import '../../../data/models/game_config.dart';

class GameRoomScreen extends StatelessWidget {
  final String gameId;
  const GameRoomScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MultiplayerBloc, MultiplayerState>(
      listenWhen: (prev, current) => 
          prev.status != current.status ||
          prev.gameReason != current.gameReason ||
          prev.drawOfferPending != current.drawOfferPending ||
          prev.saveOfferPending != current.saveOfferPending,
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
        // Show draw offer dialog when received
        if (mpState.drawOfferPending) {
          _showDrawOfferDialog(context);
        }
        // Show save offer dialog when received
        if (mpState.saveOfferPending) {
          _showSaveRequestDialog(context);
        }
      },
      builder: (context, mpState) {
        if (mpState.status != MultiplayerStatus.inGame &&
            mpState.status != MultiplayerStatus.gameOver) {
          return const Scaffold(body: Center(child: CircularProgressIndicator()));
        }

        final themeState = context.read<ThemeBloc>().state;
        
        // Parse time control from multiplayer (e.g. "10+5" -> 600s base, 5s increment)
        int? tcSeconds;
        int incSeconds = 0;
        if (mpState.timeControl != null && mpState.timeControl!.isNotEmpty) {
          final parsed = GameConfig.parseTimeControl(mpState.timeControl!);
          tcSeconds = parsed.$1;
          incSeconds = parsed.$2;
        }

        final config = GameConfig(
          mode: GameMode.multiplayer,
          playerColor: mpState.playerColor?.name ?? 'white',
          boardTheme: themeState.boardTheme,
          pieceShape: themeState.pieceShape,
          pieceStyle: themeState.pieceStyle,
          timeControl: tcSeconds,
          incrementSeconds: incSeconds,
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
            // Sync Multiplayer -> Game (Opponent UNDO)
            BlocListener<MultiplayerBloc, MultiplayerState>(
              listenWhen: (prev, current) => current.opponentUndoCount > prev.opponentUndoCount,
              listener: (context, state) {
                context.read<GameBloc>().add(GameUndoEvent());
              },
            ),
            // Sync Game -> Multiplayer (Player UNDO)
            BlocListener<GameBloc, GameState>(
              listenWhen: (prev, current) => 
                prev.moveHistory.length > current.moveHistory.length &&
                current.mode == GameMode.multiplayer,
              listener: (context, state) {
                context.read<MultiplayerBloc>().add(MpUndoEvent());
              },
            ),
            // Set opponent name in game state
            BlocListener<MultiplayerBloc, MultiplayerState>(
              listenWhen: (prev, current) => prev.opponentName != current.opponentName && current.opponentName != null,
              listener: (context, state) {
                context.read<GameBloc>().add(GameSetOpponentNameEvent(state.opponentName!));
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

  void _showDrawOfferDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('🤝 Draw Offer', style: GoogleFonts.fredoka(color: AppTheme.skyBlue)),
        content: Text(
          'Your opponent is offering a draw. Do you accept?',
          style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MultiplayerBloc>().add(MpDrawDeclineEvent());
            },
            child: Text('Decline', style: GoogleFonts.fredoka(color: AppTheme.accentRed)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MultiplayerBloc>().add(MpDrawAcceptEvent());
              context.read<GameBloc>().add(GameDrawAcceptEvent());
            },
            child: Text('Accept Draw', style: GoogleFonts.fredoka(color: AppTheme.midnight)),
          ),
        ],
      ),
    );
  }

  void _showSaveRequestDialog(BuildContext context) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('💾 Save & Quit?', style: GoogleFonts.fredoka(color: AppTheme.accentCyan)),
        content: Text(
          'Your opponent wants to save the game progress and quit. If you accept, both players can resume this later.',
          style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MultiplayerBloc>().add(MpSaveDeclineEvent());
            },
            child: Text('Continue', style: GoogleFonts.fredoka(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MultiplayerBloc>().add(MpSaveAcceptEvent());
            },
            child: Text('Accept & Save', style: GoogleFonts.fredoka(color: AppTheme.midnight)),
          ),
        ],
      ),
    );
  }

  String _friendlyCause(String? cause) {
    switch (cause) {
      case 'resignation_user_quit':
      case 'resign':
      case 'resignation':
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
