import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/router/app_router.dart';

import '../../blocs/game/game_bloc.dart';
import '../../blocs/multiplayer/multiplayer_bloc.dart';
import '../../blocs/settings/settings_bloc.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../game/game_screen.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';
import '../../../data/models/game_config.dart';
import '../../utils/engagement_notifier.dart';

class GameRoomScreen extends StatefulWidget {
  final String gameId;
  const GameRoomScreen({super.key, required this.gameId});

  @override
  State<GameRoomScreen> createState() => _GameRoomScreenState();
}

class _GameRoomScreenState extends State<GameRoomScreen> {
  final EngagementNotifier _engagement = EngagementNotifier(maxItems: 8);
  bool _didStartNotice = false;
  bool _didLowTimeNotice = false;
  int _lastOpponentUndoCount = 0;
  int _lastChatCount = 0;

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MultiplayerBloc, MultiplayerState>(
      listenWhen: (prev, current) =>
          prev.status != current.status ||
          prev.gameReason != current.gameReason ||
          prev.drawOfferPending != current.drawOfferPending ||
          prev.saveOfferPending != current.saveOfferPending ||
          prev.opponentUndoCount != current.opponentUndoCount ||
          prev.whiteTime != current.whiteTime ||
          prev.blackTime != current.blackTime ||
          prev.chatMessages.length != current.chatMessages.length,
      listener: (context, mpState) {
        _handleMilestones(mpState);

        if (mpState.gameReason == 'disconnect_timeout') {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('Opponent left: disconnect timeout')),
          );
        }
        if (mpState.status == MultiplayerStatus.gameOver &&
            mpState.gameReason != null) {
          if (mpState.gameReason == 'opponent_no_show') {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('Your opponent did not join the game in time.')),
            );
            // Navigate back to lobby after a short delay
            Future.delayed(const Duration(seconds: 2), () {
              if (context.mounted) context.go('/lobby');
            });
          } else {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                  content:
                      Text('Match ended: ${_friendlyCause(mpState.gameReason)}')),
            );
          }
        }
        if (mpState.status == MultiplayerStatus.disconnected) {
          context.go('/home');
        }
        if (mpState.drawOfferPending) {
          _showDrawOfferDialog(context);
        }
        if (mpState.saveOfferPending) {
          _showSaveRequestDialog(context);
        }
      },
      builder: (context, mpState) {
        if (mpState.status != MultiplayerStatus.inGame &&
            mpState.status != MultiplayerStatus.gameOver) {
          if (!mpState.opponentConnected) {
            // Show waiting screen for opponent
            return Scaffold(
              backgroundColor: AppTheme.midnight,
              body: SafeArea(
                child: Padding(
                  padding: const EdgeInsets.all(20),
                  child: Column(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const CircularProgressIndicator(color: AppTheme.goldPrimary),
                      const SizedBox(height: 24),
                      Text(
                        'Waiting for ${mpState.opponentName ?? 'opponent'} to join...',
                        style: GoogleFonts.fredoka(
                          color: AppTheme.textPrimary,
                          fontSize: 24,
                          fontWeight: FontWeight.w600,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 12),
                      Text(
                        'You can safely leave without penalty until they join.',
                        style: GoogleFonts.baloo2(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                        ),
                        textAlign: TextAlign.center,
                      ),
                      const SizedBox(height: 32),
                      ElevatedButton.icon(
                        onPressed: () {
                          context.read<MultiplayerBloc>().add(const MpLeaveGameEvent());
                          context.go('/home');
                        },
                        icon: const Icon(Icons.exit_to_app),
                        label: Text(
                          'Leave Game',
                          style: GoogleFonts.fredoka(),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentRed,
                          padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          } else {
            return const Scaffold(
              backgroundColor: AppTheme.midnight,
              body: Center(
                child: CircularProgressIndicator(color: AppTheme.goldPrimary),
              ),
            );
          }
        }

        final themeState = context.read<ThemeBloc>().state;

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
          variantId: mpState.variantId ?? 'standard',
        );

        return MultiBlocListener(
          listeners: [
            BlocListener<MultiplayerBloc, MultiplayerState>(
              listenWhen: (prev, current) =>
                  (prev.lastMoveFrom != current.lastMoveFrom ||
                      prev.lastMoveTo != current.lastMoveTo) &&
                  current.lastMoveFrom != null,
              listener: (context, state) {
                context.read<GameBloc>().add(GameMakeMoveEvent(
                      Square.fromString(state.lastMoveFrom!),
                      Square.fromString(state.lastMoveTo!),
                      promotion: pieceTypeFromPromotionCode(state.lastMovePromotion),
                    ));
              },
            ),
            BlocListener<GameBloc, GameState>(
              listenWhen: (prev, current) =>
                  prev.moveHistory.length < current.moveHistory.length &&
                  current.currentTurn != current.playerColor,
              listener: (context, state) {
                if (state.moveHistory.isNotEmpty &&
                    state.mode == GameMode.multiplayer) {
                  final lastMove = state.moveHistory.last;
                  context.read<MultiplayerBloc>().add(MpMakeMoveEvent(
                      lastMove.from.toString(), lastMove.to.toString(),
                      promotion: lastMove.promotion?.name));
                }
              },
            ),
            BlocListener<MultiplayerBloc, MultiplayerState>(
              listenWhen: (prev, current) =>
                  current.opponentUndoCount > prev.opponentUndoCount,
              listener: (context, state) {
                context
                    .read<GameBloc>()
                    .add(const GameUndoEvent(fromOpponent: true));
              },
            ),
            BlocListener<GameBloc, GameState>(
              listenWhen: (prev, current) =>
                  prev.moveHistory.length > current.moveHistory.length &&
                  current.mode == GameMode.multiplayer &&
                  current.isPlayerTurn,
              listener: (context, state) {
                context.read<MultiplayerBloc>().add(MpUndoEvent());
              },
            ),
            BlocListener<MultiplayerBloc, MultiplayerState>(
              listenWhen: (prev, current) =>
                  prev.opponentName != current.opponentName &&
                  current.opponentName != null,
              listener: (context, state) {
                context
                    .read<GameBloc>()
                    .add(GameSetOpponentNameEvent(state.opponentName!));
              },
            ),
          ],
          child: Scaffold(
            backgroundColor: Colors.transparent,
            body: Stack(
              children: [
                GameScreen(config: config),
                _buildEngagementOverlay(),
              ],
            ),
          ),
        );
      },
    );
  }

  void _handleMilestones(MultiplayerState mpState) {
    if (!_didStartNotice && mpState.status == MultiplayerStatus.inGame) {
      _didStartNotice = true;
      _pushEngagementNotice(
        title: 'Match Started',
        body: 'Playing against ${mpState.opponentName ?? 'opponent'}.',
        accent: AppTheme.accentCyan,
      );
    }

    if (mpState.opponentUndoCount > _lastOpponentUndoCount) {
      _lastOpponentUndoCount = mpState.opponentUndoCount;
      _pushEngagementNotice(
        title: 'Undo Activity',
        body: 'Opponent requested an undo.',
        accent: AppTheme.accentOrange,
      );
    }

    if (mpState.chatMessages.length > _lastChatCount &&
        mpState.chatMessages.isNotEmpty) {
      final last = mpState.chatMessages.last;
      if (!last.isMe) {
        _pushEngagementNotice(
          title: 'New Chat Message',
          body: '${last.username}: ${last.message}',
          accent: AppTheme.skyBlue,
        );
      }
    }
    _lastChatCount = mpState.chatMessages.length;

    final lowTime = (mpState.whiteTime > 0 && mpState.whiteTime <= 30) ||
        (mpState.blackTime > 0 && mpState.blackTime <= 30);
    if (lowTime && !_didLowTimeNotice) {
      _didLowTimeNotice = true;
      _pushEngagementNotice(
        title: 'Time Pressure',
        body: 'One of the clocks dropped below 30 seconds.',
        accent: AppTheme.accentRed,
      );
    }

    if (mpState.drawOfferPending) {
      _pushEngagementNotice(
        title: 'Draw Offer Received',
        body: 'Your opponent offered a draw.',
        accent: AppTheme.skyBlue,
      );
    }

    if (mpState.saveOfferPending) {
      _pushEngagementNotice(
        title: 'Save Request',
        body: 'Opponent wants to save and continue later.',
        accent: AppTheme.accentGreen,
      );
    }

    if (mpState.status == MultiplayerStatus.gameOver && mpState.gameReason != null) {
      _pushEngagementNotice(
        title: 'Game Over',
        body: _friendlyCause(mpState.gameReason),
        accent: AppTheme.goldPrimary,
      );
    }
  }

  void _pushEngagementNotice({
    required String title,
    required String body,
    required Color accent,
  }) {
    if (!mounted) {
      return;
    }

    final settings = context.read<SettingsBloc>().state;
    _engagement.push(
      context: context,
      globalNotificationsEnabled: settings.notificationsEnabled,
      title: title,
      body: body,
      accent: accent,
    );

    setState(() {});
  }

  Widget _buildEngagementOverlay() {
    if (_engagement.feed.isEmpty) {
      return Positioned(
        top: 94,
        right: 12,
        child: _notifyToggleChip(),
      );
    }

    return Positioned(
      top: 94,
      right: 12,
      child: ConstrainedBox(
        constraints: const BoxConstraints(maxWidth: 260),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.end,
          children: [
            _notifyToggleChip(),
            const SizedBox(height: 8),
            Container(
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: Colors.black.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: Colors.white24),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Live Notifications',
                    style: GoogleFonts.fredoka(
                      color: AppTheme.textPrimary,
                      fontSize: 12,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                  const SizedBox(height: 6),
                  ..._engagement.feed.take(3).map((item) {
                    return Padding(
                      padding: const EdgeInsets.only(bottom: 6),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Container(
                            margin: const EdgeInsets.only(top: 4),
                            width: 7,
                            height: 7,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: item.accent,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              '${item.title}: ${item.body}',
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: GoogleFonts.baloo2(
                                color: AppTheme.textSecondary,
                                fontSize: 10,
                                fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                        ],
                      ),
                    );
                  }),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _notifyToggleChip() {
    return GestureDetector(
      onTap: () {
        setState(() {
          _engagement.toggleNotify();
        });
      },
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
        decoration: BoxDecoration(
          color: Colors.black.withValues(alpha: 0.55),
          borderRadius: BorderRadius.circular(999),
          border: Border.all(color: Colors.white24),
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(
              _engagement.notifyEnabled
                  ? Icons.notifications_active
                  : Icons.notifications_off,
              size: 15,
              color: _engagement.notifyEnabled
                  ? AppTheme.accentGreen
                  : AppTheme.textMuted,
            ),
            const SizedBox(width: 6),
            Text(
              _engagement.notifyEnabled ? 'Alerts On' : 'Alerts Off',
              style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
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
        title: Text('🤝 Draw Offer',
            style: GoogleFonts.fredoka(color: AppTheme.skyBlue)),
        content: Text(
          'Your opponent is offering a draw. Do you accept?',
          style:
              GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MultiplayerBloc>().add(MpDrawDeclineEvent());
            },
            child: Text('Decline',
                style: GoogleFonts.fredoka(color: AppTheme.accentRed)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MultiplayerBloc>().add(MpDrawAcceptEvent());
              context.read<GameBloc>().add(GameDrawAcceptEvent());
            },
            child: Text('Accept Draw',
                style: GoogleFonts.fredoka(color: AppTheme.midnight)),
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
        title: Text('💾 Save & Quit?',
            style: GoogleFonts.fredoka(color: AppTheme.accentCyan)),
        content: Text(
          'Your opponent wants to save the game progress and quit. If you accept, both players can resume this later.',
          style:
              GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MultiplayerBloc>().add(MpSaveDeclineEvent());
            },
            child: Text('Continue',
                style: GoogleFonts.fredoka(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentCyan,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              Navigator.pop(ctx);
              context.read<MultiplayerBloc>().add(MpSaveAcceptEvent());
            },
            child: Text('Accept & Save',
                style: GoogleFonts.fredoka(color: AppTheme.midnight)),
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
