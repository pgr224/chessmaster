import 'dart:async';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/time_control.dart';
import '../../../data/models/game_variant.dart';
import 'package:chess_master/presentation/blocs/auth/auth_bloc.dart' as auth;
import 'package:chess_master/presentation/blocs/multiplayer/multiplayer_bloc.dart';
import 'package:chess_master/presentation/blocs/settings/settings_bloc.dart';

class LobbyScreen extends StatefulWidget {
  final String? initialChallengeId;
  final bool autoAccept;
  final String? initialXpRequestId;
  final bool autoAcceptXp;
  final bool autoRejectXp;

  const LobbyScreen({
    super.key,
    this.initialChallengeId,
    this.autoAccept = false,
    this.initialXpRequestId,
    this.autoAcceptXp = false,
    this.autoRejectXp = false,
  });

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  // Removed local selectedTime, now managed by MultiplayerBloc
  Timer? _xpRequestsPoller;
  bool _notifyMe = true;
  int _lastOnlineMilestone = 0;
  MultiplayerStatus? _lastStatus;
  int _lastXpRequestCount = 0;
  final List<_OnlineEngagementItem> _engagementFeed = <_OnlineEngagementItem>[];

  @override
  void initState() {
    super.initState();
    final authState = context.read<auth.AuthBloc>().state;
    if (authState is auth.AuthAuthenticatedState) {
      context.read<MultiplayerBloc>().add(MpConnectLobbyEvent(
            authState.user.id,
            authState.user.username,
            rating: authState.user.xp,
          ));

      // 📲 Handle Deep-linked Invitation
      if (widget.initialChallengeId != null) {
        if (widget.autoAccept) {
          context
              .read<MultiplayerBloc>()
              .add(MpAcceptChallengeEvent(widget.initialChallengeId!));
        } else {
          // We can't show the dialog yet because the lobby isn't connected
          // The Bloc will receive the updated state soon, but we ensure
          // the deep-link is prioritized.
        }
      }

      _refreshXpRequests();
      _xpRequestsPoller = Timer.periodic(
          const Duration(seconds: 20), (_) => _refreshXpRequests());

      if (widget.initialXpRequestId != null) {
        WidgetsBinding.instance.addPostFrameCallback((_) {
          _handleDeepLinkedXpRequest(widget.initialXpRequestId!);
        });
      }
    }
  }

  @override
  void dispose() {
    _xpRequestsPoller?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MultiplayerBloc, MultiplayerState>(
      listenWhen: (previous, current) =>
          previous.status != current.status ||
          previous.lobbyNotice != current.lobbyNotice ||
          previous.pendingTournamentId != current.pendingTournamentId,
      listener: (context, state) {
        _handleEngagementMilestones(state);

        if (state.status == MultiplayerStatus.matchmaking) {
          context.push('/matchmaking');
        } else if (state.status == MultiplayerStatus.inGame &&
            state.gameId != null) {
          context.go('/room/${state.gameId}');
        }

        // Show incoming tournament challenge dialog
        if (state.pendingTournamentId != null &&
            state.pendingTournamentChallengerId != null) {
          _showTournamentChallengeDialog(context, state);
        }

        if (state.lobbyNotice != null) {
          if (state.lobbyNotice!.contains('invited you') &&
              state.challengerId != null) {
            _showChallengeDialog(
                context, state.lobbyNotice!, state.challengerId!);
            _pushEngagementNotice(
              title: 'New Challenge',
              body: state.lobbyNotice!,
              accent: AppTheme.accentCyan,
            );
          } else {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.lobbyNotice!),
                onVisible: () =>
                    context.read<MultiplayerBloc>().add(MpClearNoticeEvent()),
              ));
            _pushEngagementNotice(
              title: 'Lobby Update',
              body: state.lobbyNotice!,
              accent: AppTheme.goldPrimary,
            );
          }
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.midnight,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppTheme.textPrimary),
              onPressed: () {
                context.read<MultiplayerBloc>().add(MpDisconnectLobbyEvent());
                context.pop();
              },
            ),
            title: Text(
              '🌍 Online Multiplayer',
              style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 24,
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
          ),
          body: Container(
            decoration:
                const BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: SafeArea(
              child: LayoutBuilder(
                builder: (context, constraints) {
                  final isWide = constraints.maxWidth >= 980;
                  final content = _buildMainContent(state, constraints, isWide);

                  if (isWide) {
                    return Padding(
                      padding: const EdgeInsets.all(24),
                      child: Row(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Expanded(
                              child: SingleChildScrollView(child: content)),
                          const SizedBox(width: 20),
                          SizedBox(
                            width: 340,
                            child: _buildOnlinePlayersPreview(state),
                          ),
                        ],
                      ),
                    );
                  }

                  return SingleChildScrollView(
                    padding: const EdgeInsets.all(20),
                    child: Column(
                      children: [
                        content,
                        const SizedBox(height: 18),
                        _buildOnlinePlayersPreview(state),
                      ],
                    ),
                  );
                },
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildConnectionStatus(MultiplayerState state) {
    final isConnected = state.status == MultiplayerStatus.inLobby;
    final hasError = state.connectionError != null;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: hasError ? AppTheme.errorGradient : AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? AppTheme.accentGreen : AppTheme.accentRed,
              boxShadow: [
                BoxShadow(
                  color:
                      (isConnected ? AppTheme.accentGreen : AppTheme.accentRed)
                          .withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              hasError
                  ? 'Network Error: ${state.connectionError}'
                  : isConnected
                      ? 'Connected to Global Server • ${state.onlineCount} players online'
                      : 'Connecting to online lobby...',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(
                color: hasError ? Colors.white : AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ),
          if (hasError)
            TextButton(
              onPressed: () {
                final authState = context.read<auth.AuthBloc>().state;
                if (authState is auth.AuthAuthenticatedState) {
                  context.read<MultiplayerBloc>().add(MpConnectLobbyEvent(
                        authState.user.id,
                        authState.user.username,
                        rating: authState.user.xp,
                      ));
                }
              },
              child: Text(
                'TRY AGAIN',
                style: GoogleFonts.fredoka(
                  color: Colors.white,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildMainContent(
      MultiplayerState state, BoxConstraints constraints, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildConnectionStatus(state),
        const SizedBox(height: 12),
        _buildXpBroadcasts(state),
        const SizedBox(height: 24),
        _buildHeroCard(state),
        const SizedBox(height: 26),
        Text(
          'Select Time Control',
          style: GoogleFonts.fredoka(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ).animate().fadeIn().slideY(),
        const SizedBox(height: 16),
        _buildTimeGrid(state, constraints.maxWidth)
            .animate()
            .fadeIn(delay: 200.ms)
            .slideY(),
        const SizedBox(height: 20),
        Text(
          'Select Variant',
          style: GoogleFonts.fredoka(
            color: AppTheme.textPrimary,
            fontSize: 24,
            fontWeight: FontWeight.w700,
          ),
        ).animate().fadeIn(delay: 260.ms).slideY(),
        const SizedBox(height: 14),
        _buildVariantGrid(state, constraints.maxWidth)
            .animate()
            .fadeIn(delay: 320.ms)
            .slideY(),
        const SizedBox(height: 18),
        if (!isWide) ...[
          _buildOnlinePlayersButton(state),
          const SizedBox(height: 16),
        ],
        _buildPlayButton(state).animate().fadeIn(delay: 400.ms).slideY(),
        const SizedBox(height: 16),
        Row(
          children: [
            if (isWide) ...[
              Expanded(child: _buildOnlinePlayersButton(state)),
              const SizedBox(width: 12),
            ],
            Expanded(
              child: OutlinedButton.icon(
                style: OutlinedButton.styleFrom(
                  padding: const EdgeInsets.symmetric(vertical: 18),
                  side:
                      BorderSide(color: AppTheme.goldPrimary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  context.push('/tournament/invite');
                },
                icon:
                    const Icon(Icons.emoji_events_rounded, color: AppTheme.goldPrimary),
                label: Text(
                  '🏆 Tournament',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.goldPrimary,
                    fontSize: 18,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ).animate().fadeIn(delay: 500.ms).slideY(),
            ),
          ],
        ),
        const SizedBox(height: 16),
        _buildEngagementControls(),
        const SizedBox(height: 10),
        _buildEngagementFeed(),
      ],
    );
  }

  void _handleEngagementMilestones(MultiplayerState state) {
    if (_lastStatus != state.status) {
      if (state.status == MultiplayerStatus.matchmaking) {
        _pushEngagementNotice(
          title: 'Matchmaking Started',
          body: 'Searching for an opponent using ${state.selectedTimeControl}.',
          accent: AppTheme.accentCyan,
        );
      } else if (_lastStatus == MultiplayerStatus.matchmaking &&
          state.status == MultiplayerStatus.inLobby) {
        _pushEngagementNotice(
          title: 'Matchmaking Stopped',
          body: 'You are back in the lobby queue screen.',
          accent: AppTheme.textMuted,
        );
      }
      _lastStatus = state.status;
    }

    final onlineMilestone = _onlineMilestone(state.onlineCount);
    if (onlineMilestone > 0 && onlineMilestone > _lastOnlineMilestone) {
      _lastOnlineMilestone = onlineMilestone;
      _pushEngagementNotice(
        title: 'Lobby Milestone',
        body: '$onlineMilestone players are online right now.',
        accent: AppTheme.accentGreen,
      );
    }

    if (state.xpBroadcastRequests.length > _lastXpRequestCount) {
      _pushEngagementNotice(
        title: 'Community Alert',
        body: 'New XP help request received in the lobby.',
        accent: AppTheme.accentOrange,
      );
    }
    _lastXpRequestCount = state.xpBroadcastRequests.length;
  }

  int _onlineMilestone(int onlineCount) {
    if (onlineCount >= 100) return 100;
    if (onlineCount >= 50) return 50;
    if (onlineCount >= 25) return 25;
    if (onlineCount >= 10) return 10;
    return 0;
  }

  void _pushEngagementNotice({
    required String title,
    required String body,
    required Color accent,
  }) {
    _engagementFeed.insert(
      0,
      _OnlineEngagementItem(
        title: title,
        body: body,
        createdAt: DateTime.now(),
        accent: accent,
      ),
    );
    if (_engagementFeed.length > 8) {
      _engagementFeed.removeLast();
    }

    if (!mounted) return;

    final settings = context.read<SettingsBloc>().state;
    final canNotify = settings.notificationsEnabled && _notifyMe;
    if (canNotify) {
      ScaffoldMessenger.of(context)
        ..hideCurrentSnackBar()
        ..showSnackBar(
          SnackBar(content: Text('$title • $body')),
        );
    }

    setState(() {});
  }

  Widget _buildEngagementControls() {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(
              'Engagement Alerts',
              style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 16,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Switch(
            value: _notifyMe,
            activeColor: AppTheme.accentGreen,
            onChanged: (value) {
              setState(() {
                _notifyMe = value;
              });
            },
          ),
        ],
      ),
    );
  }

  Widget _buildEngagementFeed() {
    if (_engagementFeed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Online Milestones',
            style: GoogleFonts.fredoka(
              color: AppTheme.accentOrange,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ..._engagementFeed.take(4).map((item) {
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 9),
              decoration: BoxDecoration(
                color: item.accent.withValues(alpha: 0.08),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: item.accent.withValues(alpha: 0.26)),
              ),
              child: Row(
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: item.accent,
                    ),
                  ),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          item.title,
                          style: GoogleFonts.fredoka(
                            color: AppTheme.textPrimary,
                            fontSize: 12,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        Text(
                          item.body,
                          style: GoogleFonts.baloo2(
                            color: AppTheme.textSecondary,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildXpBroadcasts(MultiplayerState state) {
    final authState = context.watch<auth.AuthBloc>().state;
    final bool needsXp =
        authState is auth.AuthAuthenticatedState && authState.user.xp < 0;

    if (!needsXp) return const SizedBox.shrink();

    return Padding(
      padding: const EdgeInsets.only(bottom: 12),
      child: Container(
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: Colors.redAccent.withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.redAccent.withValues(alpha: 0.4)),
        ),
        child: Row(
          children: [
            const Icon(Icons.warning_amber_rounded,
                color: Colors.redAccent, size: 28),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Negative XP Balance!',
                    style: GoogleFonts.fredoka(
                        color: Colors.redAccent,
                        fontSize: 18,
                        fontWeight: FontWeight.bold),
                  ),
                  Text(
                    'You need at least 0 XP to play. Request the community for help!',
                    style: GoogleFonts.baloo2(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w600),
                  ),
                ],
              ),
            ),
            _buildBroadcastButton(),
          ],
        ),
      ),
    ).animate().shake(duration: 500.ms);
  }

  Widget _buildBroadcastButton() {
    return FilledButton(
      style: FilledButton.styleFrom(
        backgroundColor: AppTheme.accentGreen,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
      onPressed: () async {
        try {
          final ok =
              await context.read<auth.AuthBloc>().authRepository.requestXP(
                    amount: 500,
                  );
          if (!mounted) return;
          if (ok) {
            ScaffoldMessenger.of(context).showSnackBar(
              const SnackBar(content: Text('XP Broadcast Request Sent!')),
            );
            _refreshXpRequests();
          }
        } catch (e) {
          if (!mounted) return;
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text('Could not send request: ${e.toString()}')),
          );
        }
      },
      child: Text('BROADCAST',
          style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
    );
  }

  void _handleDonateXP(String userId, String username, int amount,
      [int? requestId]) {
    showDialog(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        title: Text('Donate XP to $username',
            style: GoogleFonts.fredoka(color: AppTheme.textPrimary)),
        content: Text(
            'Are you sure you want to donate $amount XP? This will be deducted from your total balance.',
            style: GoogleFonts.baloo2(color: AppTheme.textSecondary)),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(ctx), child: const Text('CANCEL')),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              try {
                final success = await context
                    .read<auth.AuthBloc>()
                    .authRepository
                  .donateXP(
                    recipientId: userId,
                    amount: amount,
                    requestId: requestId);
                
                if (!mounted) {
                  return;
                }

                if (success) {
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text('Donated $amount XP to $username!')));
                  
                  context.read<auth.AuthBloc>().add(
                      auth.AuthCheckStatusEvent()); // Refresh local user XP
                    _refreshXpRequests();
                }
              } catch (e) {
                if (!mounted) {
                  return;
                }
                ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(content: Text('Error: ${e.toString()}')));
              }
            },
            child: const Text('DONATE'),
          ),
        ],
      ),
    );
  }

  Widget _buildHeroCard(MultiplayerState state) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.rainbowGradient,
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
            color: AppTheme.goldPrimary.withValues(alpha: 0.2),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Row(
        children: [
          const Icon(Icons.groups_rounded, color: AppTheme.midnight, size: 42),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Play Live With Real Opponents',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.midnight,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  'Quick match, direct 1v1 challenge, or send a tournament invite from the player list.',
                  style: GoogleFonts.baloo2(
                    color: AppTheme.midnight.withValues(alpha: 0.9),
                    fontSize: 16,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTimeGrid(MultiplayerState state, double width) {
    final timeOptions = TimeControlPreset.all;

    final crossAxisCount = width < 520 ? 2 : 3;
    final aspectRatio = width < 520 ? 2.2 : 2.0;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: aspectRatio,
      ),
      itemCount: timeOptions.length,
      itemBuilder: (context, index) {
        final option = timeOptions[index];
        final isSelected = state.selectedTimeControl == option.value;
        final accentColor = option.color;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context
                .read<MultiplayerBloc>()
                .add(MpChangeSelectedTimeEvent(option.value)),
            child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isSelected
                  ? LinearGradient(
                      colors: [
                        accentColor.withValues(alpha: 0.15),
                        accentColor.withValues(alpha: 0.05)
                      ],
                      begin: Alignment.topLeft,
                      end: Alignment.bottomRight,
                    )
                  : null,
              color: isSelected ? null : AppTheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected
                    ? accentColor
                    : AppTheme.textMuted.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: accentColor.withValues(alpha: 0.2),
                          blurRadius: 8,
                          offset: const Offset(0, 2))
                    ]
                  : null,
            ),
              child: Padding(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.spaceBetween,
                  children: [
                    // Icon
                    Icon(
                      option.icon,
                      color: isSelected ? accentColor : AppTheme.textMuted,
                      size: 18,
                    ),
                    // Time control
                    Column(
                      children: [
                        Text(
                          option.value,
                          style: GoogleFonts.fredoka(
                            color: isSelected
                                ? AppTheme.textPrimary
                                : AppTheme.textSecondary,
                            fontSize: 14,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        const SizedBox(height: 2),
                        Text(
                          option.label,
                          style: GoogleFonts.baloo2(
                            color: isSelected ? accentColor : AppTheme.textMuted,
                            fontSize: 11,
                            fontWeight: FontWeight.w600,
                          ),
                        ),
                      ],
                    ),
                    // Info text - smaller and subtle
                    Text(
                      option.description,
                      style: GoogleFonts.baloo2(
                        color: isSelected
                            ? AppTheme.textSecondary
                            : AppTheme.textMuted.withValues(alpha: 0.7),
                        fontSize: 9,
                        fontWeight: FontWeight.w500,
                        height: 1.2,
                      ),
                      textAlign: TextAlign.center,
                      maxLines: 2,
                      overflow: TextOverflow.ellipsis,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOnlinePlayersButton(MultiplayerState state) {
    return FilledButton.icon(
      style: FilledButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 18),
        backgroundColor: AppTheme.accentPurple,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: () => _showSocialWindow(state),
      icon: const Icon(Icons.groups_2_rounded, color: Colors.white),
      label: Text(
        'View Online Players',
        style: GoogleFonts.fredoka(
          color: Colors.white,
          fontSize: 18,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Widget _buildVariantGrid(MultiplayerState state, double width) {
    final variants = GameVariantPreset.all;
    final crossAxisCount = width < 520 ? 2 : 3;
    final aspectRatio = width < 520 ? 2.0 : 2.35;

    return GridView.builder(
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      gridDelegate: SliverGridDelegateWithFixedCrossAxisCount(
        crossAxisCount: crossAxisCount,
        crossAxisSpacing: 10,
        mainAxisSpacing: 10,
        childAspectRatio: aspectRatio,
      ),
      itemCount: variants.length,
      itemBuilder: (context, index) {
        final variant = variants[index];
        final isSelected = state.selectedVariantId == variant.id;

        return Material(
          color: Colors.transparent,
          child: InkWell(
            borderRadius: BorderRadius.circular(14),
            onTap: () => context
                .read<MultiplayerBloc>()
                .add(MpChangeSelectedVariantEvent(variant.id)),
            child: AnimatedContainer(
              duration: const Duration(milliseconds: 220),
              padding: const EdgeInsets.all(10),
              decoration: BoxDecoration(
                color: isSelected
                    ? variant.color.withValues(alpha: 0.14)
                    : AppTheme.surface.withValues(alpha: 0.55),
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                  color: isSelected
                      ? variant.color
                      : AppTheme.textMuted.withValues(alpha: 0.15),
                  width: isSelected ? 2 : 1,
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(variant.icon,
                          size: 16,
                          color:
                              isSelected ? variant.color : AppTheme.textMuted),
                      const SizedBox(width: 6),
                      Expanded(
                        child: Text(
                          variant.name,
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: GoogleFonts.fredoka(
                            color: AppTheme.textPrimary,
                            fontSize: 13,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${variant.subtitle} • ${variant.xpMultiplier.toStringAsFixed(2)}x XP',
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      color: isSelected ? variant.color : AppTheme.textMuted,
                      fontSize: 10,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                  const Spacer(),
                  Text(
                    variant.description,
                    maxLines: 2,
                    overflow: TextOverflow.ellipsis,
                    style: GoogleFonts.baloo2(
                      color: AppTheme.textSecondary,
                      fontSize: 10,
                      fontWeight: FontWeight.w500,
                      height: 1.15,
                    ),
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildOnlinePlayersPreview(MultiplayerState state) {
    final previewPlayers =
        state.availablePlayers.take(3).toList(growable: false);
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.person_search_rounded,
                  color: AppTheme.goldPrimary),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Players Online',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.textPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
              Text(
                '${state.onlineCount}',
                style: GoogleFonts.fredoka(
                  color: AppTheme.accentCyan,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
            ],
          ),
          const SizedBox(height: 10),
          Text(
            'Challenge a player directly or invite them to a friendly tournament room.',
            style: GoogleFonts.baloo2(
                color: AppTheme.textSecondary,
                fontSize: 15,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...previewPlayers.map(_buildPreviewPlayerTile),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showSocialWindow(state),
              child: Text(
                'Open full player window',
                style: GoogleFonts.fredoka(
                    color: AppTheme.goldPrimary, fontWeight: FontWeight.w600),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildPreviewPlayerTile(OnlineLobbyUser player) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(18),
      ),
      child: Row(
        children: [
          CircleAvatar(
            radius: 18,
            backgroundColor:
                player.isAvailable ? AppTheme.accentCyan : AppTheme.textMuted,
            child: Text(player.name.characters.first.toUpperCase(),
                style: GoogleFonts.fredoka(color: AppTheme.midnight)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name,
                    style: GoogleFonts.fredoka(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text('${player.xp} XP • ${player.flair}',
                    style: GoogleFonts.baloo2(
                        color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          _availabilityChip(player.isAvailable),
        ],
      ),
    );
  }

  Widget _availabilityChip(bool isAvailable) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: (isAvailable ? AppTheme.accentCyan : AppTheme.textMuted)
            .withValues(alpha: 0.16),
        borderRadius: BorderRadius.circular(999),
      ),
      child: Text(
        isAvailable ? 'Ready' : 'Busy',
        style: GoogleFonts.fredoka(
          color: isAvailable ? AppTheme.accentCyan : AppTheme.textMuted,
          fontSize: 12,
          fontWeight: FontWeight.w600,
        ),
      ),
    );
  }

  Future<void> _showSocialWindow(MultiplayerState state) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DefaultTabController(
          length: 2,
          child: DraggableScrollableSheet(
            initialChildSize: 0.82,
            minChildSize: 0.55,
            maxChildSize: 0.96,
            builder: (context, scrollController) {
              return Container(
                decoration: const BoxDecoration(
                  gradient: AppTheme.backgroundGradient,
                  borderRadius: BorderRadius.vertical(top: Radius.circular(28)),
                ),
                child: SafeArea(
                  top: false,
                  child: Column(
                    children: [
                      const SizedBox(height: 14),
                      Center(
                        child: Container(
                          width: 56,
                          height: 6,
                          decoration: BoxDecoration(
                            color: Colors.white.withValues(alpha: 0.18),
                            borderRadius: BorderRadius.circular(999),
                          ),
                        ),
                      ),
                      const SizedBox(height: 16),
                      TabBar(
                        dividerColor: Colors.transparent,
                        indicatorColor: AppTheme.accentCyan,
                        labelColor: AppTheme.accentCyan,
                        unselectedLabelColor: AppTheme.textMuted,
                        labelStyle: GoogleFonts.fredoka(
                            fontWeight: FontWeight.bold, fontSize: 18),
                        tabs: const [
                          Tab(
                              text: 'Players',
                              icon: Icon(Icons.people_rounded)),
                          Tab(
                              text: 'XP Requests',
                              icon: Icon(Icons.volunteer_activism_rounded)),
                        ],
                      ),
                      Expanded(
                        child: TabBarView(
                          children: [
                            // PLAYERS TAB
                            _buildPlayersTab(state, scrollController),
                            // REQUESTS TAB
                            _buildRequestsTab(state, scrollController),
                          ],
                        ),
                      ),
                    ],
                  ),
                ),
              );
            },
          ),
        );
      },
    );
  }

  Widget _buildPlayersTab(
      MultiplayerState state, ScrollController scrollController) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Available Online Players',
            style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Choose a player and send either a 1v1 challenge or a tournament invite.',
            style: GoogleFonts.baloo2(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          Expanded(
            child: ListView.builder(
              controller: scrollController,
              itemCount: state.availablePlayers.length,
              itemBuilder: (context, index) =>
                  _buildChallengeCard(state.availablePlayers[index]),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildRequestsTab(
      MultiplayerState state, ScrollController scrollController) {
    return Padding(
      padding: const EdgeInsets.all(18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'XP Broadcast Requests',
            style: GoogleFonts.fredoka(
                color: AppTheme.goldPrimary,
                fontSize: 26,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 6),
          Text(
            'Help fellow players get back in the game! Requests last for 24 hours.',
            style: GoogleFonts.baloo2(
                color: AppTheme.textSecondary,
                fontSize: 16,
                fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 16),
          if (state.xpBroadcastRequests.isEmpty)
            Expanded(
              child: Center(
                child: Column(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Icon(Icons.hourglass_empty_rounded,
                        color: AppTheme.textMuted, size: 48),
                    const SizedBox(height: 12),
                    Text('No active requests',
                        style: GoogleFonts.baloo2(color: AppTheme.textMuted)),
                  ],
                ),
              ),
            )
          else
            Expanded(
              child: ListView.builder(
                controller: scrollController,
                itemCount: state.xpBroadcastRequests.length,
                itemBuilder: (context, index) {
                  final req = state.xpBroadcastRequests[index];
                  return Container(
                    margin: const EdgeInsets.only(bottom: 12),
                    padding: const EdgeInsets.all(16),
                    decoration: BoxDecoration(
                      color: AppTheme.navyCard,
                      borderRadius: BorderRadius.circular(18),
                      border: Border.all(
                          color: AppTheme.accentOrange.withValues(alpha: 0.3)),
                    ),
                    child: Row(
                      children: [
                        const CircleAvatar(
                          backgroundColor: AppTheme.accentOrange,
                          child: Icon(Icons.person, color: Colors.white),
                        ),
                        const SizedBox(width: 14),
                        Expanded(
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                req['username'] ?? 'Anonymous',
                                style: GoogleFonts.fredoka(
                                    color: AppTheme.textPrimary,
                                    fontSize: 18,
                                    fontWeight: FontWeight.bold),
                              ),
                              Text(
                                'Asking for ${req['amount']} XP',
                                style: GoogleFonts.baloo2(
                                    color: AppTheme.accentOrange,
                                    fontWeight: FontWeight.w600),
                              ),
                            ],
                          ),
                        ),
                        FilledButton(
                          style: FilledButton.styleFrom(
                              backgroundColor: AppTheme.accentOrange),
                          onPressed: () => _handleDonateXP(
                            req['userId'], req['username'], req['amount'],
                            req['id'] is int
                              ? req['id'] as int
                              : int.tryParse('${req['id']}')),
                          child: const Text('DONATE'),
                        ),
                      ],
                    ),
                  );
                },
              ),
            ),
        ],
      ),
    );
  }

  Widget _buildChallengeCard(OnlineLobbyUser player) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              CircleAvatar(
                radius: 22,
                backgroundColor: player.isAvailable
                    ? AppTheme.goldPrimary
                    : AppTheme.textMuted,
                child: Text(player.name.characters.first.toUpperCase(),
                    style: GoogleFonts.fredoka(
                        color: AppTheme.midnight, fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.name,
                        style: GoogleFonts.fredoka(
                            color: AppTheme.textPrimary,
                            fontSize: 18,
                            fontWeight: FontWeight.w700)),
                    Text('${player.xp} XP • ${player.flair}',
                        style: GoogleFonts.baloo2(
                            color: AppTheme.textSecondary, fontSize: 14)),
                  ],
                ),
              ),
              _availabilityChip(player.isAvailable),
            ],
          ),
          const SizedBox(height: 14),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: player.isAvailable
                    ? () => context.read<MultiplayerBloc>().add(
                          MpSendChallengeEvent(
                            opponent: player,
                            mode: ChallengeMode.duel,
                            timeControl: context
                                .read<MultiplayerBloc>()
                                .state
                                .selectedTimeControl,
                            variantId: context
                                .read<MultiplayerBloc>()
                                .state
                                .selectedVariantId,
                          ),
                        )
                    : null,
                icon: const Icon(Icons.sports_martial_arts_rounded),
                label: const Text('1v1 Challenge'),
              ),
              OutlinedButton.icon(
                onPressed: player.isAvailable
                    ? () => context.read<MultiplayerBloc>().add(
                          MpSendChallengeEvent(
                            opponent: player,
                            mode: ChallengeMode.tournament,
                            timeControl: context
                                .read<MultiplayerBloc>()
                                .state
                                .selectedTimeControl,
                            variantId: context
                                .read<MultiplayerBloc>()
                                .state
                                .selectedVariantId,
                          ),
                        )
                    : null,
                icon: const Icon(Icons.emoji_events_rounded),
                label: const Text('Tournament Invite'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildPlayButton(MultiplayerState state) {
    final isReady = state.status == MultiplayerStatus.inLobby;
    final selectedVariant = GameVariantPreset.fromId(state.selectedVariantId);
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        backgroundColor: AppTheme.goldPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        elevation: 8,
        shadowColor: AppTheme.goldPrimary.withValues(alpha: 0.5),
      ),
      onPressed: isReady
          ? () {
              context.read<MultiplayerBloc>().add(MpStartMatchmakingEvent());
            }
          : null,
      child: isReady
          ? Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text('Find Match',
                    style: GoogleFonts.fredoka(
                      color: AppTheme.midnight,
                      fontSize: 22,
                      fontWeight: FontWeight.w800,
                    )),
                Text(
                  '${selectedVariant.name} • ${state.selectedTimeControl}',
                  style: GoogleFonts.baloo2(
                    color: AppTheme.midnight.withValues(alpha: 0.8),
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            )
          : Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const SizedBox(
                    width: 20,
                    height: 20,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: AppTheme.midnight)),
                const SizedBox(width: 12),
                Text(
                  'Connecting...',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.midnight,
                    fontSize: 20,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
    );
  }

  void _showChallengeDialog(
      BuildContext context, String message, String challengerId) {
    final state = context.read<MultiplayerBloc>().state;
    final preset = TimeControlPreset.fromValue(
        state.challengerTimeControl ?? TimeControlPreset.defaultValue);
    final variant = GameVariantPreset.fromId(state.challengerVariantId);

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.midnight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('⚔️ New Challenge!',
            style: GoogleFonts.fredoka(color: AppTheme.goldPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(message,
                style: GoogleFonts.baloo2(
                    color: AppTheme.textPrimary, fontSize: 16)),
            const SizedBox(height: 14),
            Row(
              children: [
                Icon(preset.icon, size: 18, color: preset.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    '${preset.label} • ${preset.value}',
                    style: GoogleFonts.fredoka(
                      color: AppTheme.goldPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 6),
            Text(preset.description,
                style: GoogleFonts.baloo2(
                    color: AppTheme.textSecondary, fontSize: 14)),
            const SizedBox(height: 10),
            Row(
              children: [
                Icon(variant.icon, size: 18, color: variant.color),
                const SizedBox(width: 8),
                Expanded(
                  child: Text(
                    'Variant: ${variant.name}',
                    style: GoogleFonts.fredoka(
                      color: variant.color,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<MultiplayerBloc>().add(MpClearNoticeEvent());
              Navigator.pop(ctx);
            },
            child: Text('Decline',
                style: GoogleFonts.fredoka(
                    color: AppTheme.accentRed, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldPrimary,
              foregroundColor: AppTheme.midnight,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              context
                  .read<MultiplayerBloc>()
                  .add(MpAcceptChallengeEvent(challengerId));
              Navigator.pop(ctx);
            },
            child: Text('Accept',
                style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  void _showTournamentChallengeDialog(
      BuildContext context, MultiplayerState state) {
    final challName = state.pendingTournamentChallengerName ?? 'Someone';
    final rounds = state.pendingTournamentRounds;
    final tc = state.pendingTournamentTimeControl ?? TimeControlPreset.defaultValue;
    final preset = TimeControlPreset.fromValue(tc);
    final tId = state.pendingTournamentId!;
    final cId = state.pendingTournamentChallengerId!;

    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.midnight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('🏆 Tournament Invite!',
            style: GoogleFonts.fredoka(color: AppTheme.goldPrimary)),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text(
              '$challName wants to play a $rounds-round tournament with ${preset.label} (${preset.value}) time control.',
              style: GoogleFonts.baloo2(
                  color: AppTheme.textPrimary, fontSize: 15),
            ),
            const SizedBox(height: 12),
            Text(preset.description,
                style: GoogleFonts.baloo2(
                    color: AppTheme.textSecondary, fontSize: 14)),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              context.read<MultiplayerBloc>().add(MpClearNoticeEvent());
              Navigator.pop(ctx);
            },
            child: Text('Decline',
                style: GoogleFonts.fredoka(
                    color: AppTheme.accentRed,
                    fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldPrimary,
              foregroundColor: AppTheme.midnight,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              // Accept via lobby WS
              final mpService = context
                  .read<MultiplayerBloc>()
                  .mpService;
              mpService.acceptTournamentChallenge(cId, tId);
              context.read<MultiplayerBloc>().add(MpClearNoticeEvent());
              Navigator.pop(ctx);
              // Navigate to tournament lobby
              context.push('/tournament/$tId');
            },
            child: Text('Accept',
                style:
                    GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }

  Future<void> _refreshXpRequests() async {
    final authState = context.read<auth.AuthBloc>().state;
    if (authState is! auth.AuthAuthenticatedState) return;

    final requests = await context
        .read<auth.AuthBloc>()
        .authRepository
        .getActiveBroadcastRequests();
    if (!mounted) return;

    final normalized = requests
        .whereType<Map>()
        .map((e) => Map<String, dynamic>.from(e))
        .toList(growable: false);

    context
        .read<MultiplayerBloc>()
        .add(MpSetXpBroadcastRequestsEvent(normalized));
  }

  Future<void> _handleDeepLinkedXpRequest(String requestIdRaw) async {
    final requestId = int.tryParse(requestIdRaw);
    if (requestId == null) return;

    if (widget.autoAcceptXp) {
      await _respondToXpRequest(requestId, 'accept');
      return;
    }

    if (widget.autoRejectXp) {
      await _respondToXpRequest(requestId, 'reject');
      return;
    }

    final request = await context
        .read<auth.AuthBloc>()
        .authRepository
        .getXpRequestById(requestId);

    if (!mounted || request == null) return;

    final requesterName = request['requester_username']?.toString() ?? 'Player';
    final amount = (request['amount'] as num?)?.toInt() ?? 0;

    await showDialog<void>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        title: Text('XP Help Request',
            style: GoogleFonts.fredoka(color: AppTheme.textPrimary)),
        content: Text(
          '$requesterName requested $amount XP from you.',
          style: GoogleFonts.baloo2(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _respondToXpRequest(requestId, 'reject');
            },
            child: const Text('Reject'),
          ),
          FilledButton(
            onPressed: () async {
              Navigator.pop(ctx);
              await _respondToXpRequest(requestId, 'accept');
            },
            child: const Text('Accept'),
          ),
        ],
      ),
    );
  }

  Future<void> _respondToXpRequest(int requestId, String action) async {
    try {
      final ok = await context
          .read<auth.AuthBloc>()
          .authRepository
          .respondToXpRequest(requestId: requestId, action: action);
      if (!mounted) return;

      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text(ok
              ? (action == 'accept'
                  ? 'XP request accepted.'
                  : 'XP request rejected.')
              : 'Could not process XP request.'),
        ),
      );
      if (ok) {
        context.read<auth.AuthBloc>().add(auth.AuthCheckStatusEvent());
        _refreshXpRequests();
      }
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text('Could not process request: ${e.toString()}')),
      );
    }
  }
}

class _OnlineEngagementItem {
  final String title;
  final String body;
  final DateTime createdAt;
  final Color accent;

  const _OnlineEngagementItem({
    required this.title,
    required this.body,
    required this.createdAt,
    required this.accent,
  });
}
