import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/multiplayer/multiplayer_bloc.dart';

class LobbyScreen extends StatefulWidget {
  const LobbyScreen({super.key});

  @override
  State<LobbyScreen> createState() => _LobbyScreenState();
}

class _LobbyScreenState extends State<LobbyScreen> {
  String _selectedTime = '10+0';

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticatedState) {
      context.read<MultiplayerBloc>().add(MpConnectLobbyEvent(
        authState.user.id,
        authState.user.username,
        rating: authState.user.xp,
      ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<MultiplayerBloc, MultiplayerState>(
      listenWhen: (previous, current) =>
          previous.status != current.status || previous.lobbyNotice != current.lobbyNotice,
      listener: (context, state) {
        if (state.status == MultiplayerStatus.matchmaking) {
          context.push('/matchmaking');
        } else if (state.status == MultiplayerStatus.inGame && state.gameId != null) {
          context.go('/room/${state.gameId}');
        }

        if (state.lobbyNotice != null) {
          if (state.lobbyNotice!.contains('invited you') && state.challengerId != null) {
             _showChallengeDialog(context, state.lobbyNotice!, state.challengerId!);
          } else {
            ScaffoldMessenger.of(context)
              ..hideCurrentSnackBar()
              ..showSnackBar(SnackBar(
                content: Text(state.lobbyNotice!),
                onVisible: () => context.read<MultiplayerBloc>().add(MpClearNoticeEvent()),
              ));
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
              icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
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
            decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
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
                          Expanded(child: SingleChildScrollView(child: content)),
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
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            width: 10, height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: isConnected ? AppTheme.accentGreen : AppTheme.accentRed,
              boxShadow: [
                BoxShadow(
                  color: (isConnected ? AppTheme.accentGreen : AppTheme.accentRed).withValues(alpha: 0.5),
                  blurRadius: 8,
                ),
              ],
            ),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Text(
              isConnected
                  ? 'Connected to Global Server • ${state.onlineCount} players online'
                  : 'Connecting to online lobby...',
              maxLines: 2,
              overflow: TextOverflow.ellipsis,
              style: GoogleFonts.baloo2(
                color: AppTheme.textSecondary,
                fontWeight: FontWeight.w700,
                fontSize: 17,
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMainContent(MultiplayerState state, BoxConstraints constraints, bool isWide) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.stretch,
      children: [
        _buildConnectionStatus(state),
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
        _buildTimeGrid(constraints.maxWidth).animate().fadeIn(delay: 200.ms).slideY(),
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
                  side: BorderSide(color: AppTheme.goldPrimary.withValues(alpha: 0.5)),
                  shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                ),
                onPressed: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(content: Text('Private rooms coming soon!')),
                  );
                },
                icon: const Icon(Icons.lock_rounded, color: AppTheme.goldPrimary),
                label: Text(
                  'Create Private Game',
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
      ],
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

  Widget _buildTimeGrid(double width) {
    final times = [
      {
        'label': 'Bullet',
        'time': '1+0',
        'icon': Icons.flash_on_rounded,
        'color': Colors.red,
        'info': 'Super fast. 1 min per side. Perfect for quick matches.',
      },
      {
        'label': 'Blitz',
        'time': '3+0',
        'icon': Icons.local_fire_department_rounded,
        'color': Colors.orange,
        'info': '3 min per side. Rapid decision making needed.',
      },
      {
        'label': 'Blitz',
        'time': '5+0',
        'icon': Icons.bolt_rounded,
        'color': Colors.amber,
        'info': '5 min per side. Fast-paced tactical battles.',
      },
      {
        'label': 'Rapid',
        'time': '10+0',
        'icon': Icons.timer_rounded,
        'color': AppTheme.skyBlue,
        'info': '10 min per side. Time for strategy & tactics.',
      },
      {
        'label': 'Rapid',
        'time': '15+10',
        'icon': Icons.hourglass_top_rounded,
        'color': AppTheme.accentCyan,
        'info': '15 min + 10 sec increment. Balanced gameplay.',
      },
      {
        'label': 'Classic',
        'time': '30+0',
        'icon': Icons.account_balance_rounded,
        'color': AppTheme.goldPrimary,
        'info': '30 min per side. Thoughtful, classical chess.',
      },
    ];
    
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
      itemCount: times.length,
      itemBuilder: (context, index) {
        final item = times[index];
        final isSelected = _selectedTime == item['time'];
        final accentColor = item['color'] as Color;
        
        return GestureDetector(
          onTap: () => setState(() => _selectedTime = item['time'] as String),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            decoration: BoxDecoration(
              gradient: isSelected 
                ? LinearGradient(
                    colors: [accentColor.withValues(alpha: 0.15), accentColor.withValues(alpha: 0.05)],
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                  )
                : null,
              color: isSelected ? null : AppTheme.surface.withValues(alpha: 0.6),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? accentColor : AppTheme.textMuted.withValues(alpha: 0.1),
                width: isSelected ? 2 : 1,
              ),
              boxShadow: isSelected 
                ? [BoxShadow(color: accentColor.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 2))]
                : null,
            ),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
              child: Column(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  // Icon
                  Icon(
                    item['icon'] as IconData,
                    color: isSelected ? accentColor : AppTheme.textMuted,
                    size: 18,
                  ),
                  // Time control
                  Column(
                    children: [
                      Text(
                        item['time'] as String,
                        style: GoogleFonts.fredoka(
                          color: isSelected ? AppTheme.textPrimary : AppTheme.textSecondary,
                          fontSize: 14,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 2),
                      Text(
                        item['label'] as String,
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
                    item['info'] as String,
                    style: GoogleFonts.baloo2(
                      color: isSelected ? AppTheme.textSecondary : AppTheme.textMuted.withValues(alpha: 0.7),
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
      onPressed: () => _showPlayersWindow(state),
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

  Widget _buildOnlinePlayersPreview(MultiplayerState state) {
    final previewPlayers = state.availablePlayers.take(3).toList(growable: false);
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
              const Icon(Icons.person_search_rounded, color: AppTheme.goldPrimary),
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
            style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w600),
          ),
          const SizedBox(height: 12),
          ...previewPlayers.map(_buildPreviewPlayerTile),
          const SizedBox(height: 10),
          Align(
            alignment: Alignment.centerRight,
            child: TextButton(
              onPressed: () => _showPlayersWindow(state),
              child: Text(
                'Open full player window',
                style: GoogleFonts.fredoka(color: AppTheme.goldPrimary, fontWeight: FontWeight.w600),
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
            backgroundColor: player.isAvailable ? AppTheme.accentCyan : AppTheme.textMuted,
            child: Text(player.name.characters.first.toUpperCase(), style: GoogleFonts.fredoka(color: AppTheme.midnight)),
          ),
          const SizedBox(width: 12),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(player.name, style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                Text('${player.xp} XP • ${player.flair}', style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 13)),
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
        color: (isAvailable ? AppTheme.accentCyan : AppTheme.textMuted).withValues(alpha: 0.16),
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

  Future<void> _showPlayersWindow(MultiplayerState state) async {
    await showModalBottomSheet<void>(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (sheetContext) {
        return DraggableScrollableSheet(
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
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(18, 16, 18, 18),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
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
                      const SizedBox(height: 14),
                      Text(
                        'Available Online Players',
                        style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w700),
                      ),
                      const SizedBox(height: 6),
                      Text(
                        'Choose a player and send either a 1v1 challenge or a tournament invite.',
                        style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w600),
                      ),
                      const SizedBox(height: 16),
                      Expanded(
                        child: ListView.builder(
                          controller: scrollController,
                          itemCount: state.availablePlayers.length,
                          itemBuilder: (context, index) => _buildChallengeCard(state.availablePlayers[index]),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
            );
          },
        );
      },
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
                backgroundColor: player.isAvailable ? AppTheme.goldPrimary : AppTheme.textMuted,
                child: Text(player.name.characters.first.toUpperCase(), style: GoogleFonts.fredoka(color: AppTheme.midnight, fontSize: 20)),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(player.name, style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700)),
                    Text('${player.xp} XP • ${player.flair}', style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 14)),
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
                            timeControl: _selectedTime,
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
                            timeControl: _selectedTime,
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
    return ElevatedButton(
      style: ElevatedButton.styleFrom(
        padding: const EdgeInsets.symmetric(vertical: 20),
        backgroundColor: AppTheme.goldPrimary,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
        elevation: 8,
        shadowColor: AppTheme.goldPrimary.withValues(alpha: 0.5),
      ),
      onPressed: isReady ? () {
        context.read<MultiplayerBloc>().add(MpStartMatchmakingEvent());
      } : null,
      child: isReady 
        ? Text('Find Match', style: GoogleFonts.fredoka(
            color: AppTheme.midnight, fontSize: 22, fontWeight: FontWeight.w800,
          ))
        : Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.midnight)),
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

  void _showChallengeDialog(BuildContext context, String message, String challengerId) {
    showDialog(
      context: context,
      barrierDismissible: false,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.midnight,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('⚔️ New Challenge!', style: GoogleFonts.fredoka(color: AppTheme.goldPrimary)),
        content: Text(message, style: GoogleFonts.baloo2(color: AppTheme.textPrimary, fontSize: 16)),
        actions: [
          TextButton(
            onPressed: () {
              context.read<MultiplayerBloc>().add(MpClearNoticeEvent());
              Navigator.pop(ctx);
            },
            child: Text('Decline', style: GoogleFonts.fredoka(color: AppTheme.accentRed, fontWeight: FontWeight.w600)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.goldPrimary, 
              foregroundColor: AppTheme.midnight,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () {
              context.read<MultiplayerBloc>().add(MpAcceptChallengeEvent(challengerId));
              Navigator.pop(ctx);
            },
            child: Text('Accept', style: GoogleFonts.fredoka(fontWeight: FontWeight.bold)),
          ),
        ],
      ),
    );
  }
}
