import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/tournament_model.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/multiplayer/multiplayer_bloc.dart';
import '../../blocs/tournament/tournament_bloc.dart';

/// Shows the live tournament state: current round, scores, pairings,
/// engagement banners and completed round history.
class TournamentLobbyScreen extends StatefulWidget {
  final String tournamentId;
  const TournamentLobbyScreen({super.key, required this.tournamentId});

  @override
  State<TournamentLobbyScreen> createState() => _TournamentLobbyScreenState();
}

class _TournamentLobbyScreenState extends State<TournamentLobbyScreen> {
  String? _myUserId;

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticatedState) {
      _myUserId = authState.user.id;
      // Connect to tournament WS and signal ready
      context.read<TournamentBloc>().add(TournamentConnectEvent(
            tournamentId: widget.tournamentId,
            userId: authState.user.id,
            username: authState.user.username,
            rating: authState.user.xp,
          ));
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TournamentBloc, TournamentState>(
      listener: (context, ts) {
        if (ts.status == TournamentStatus.finished) {
          context.go('/tournament/${widget.tournamentId}/result');
        }
      },
      builder: (context, ts) {
        return Scaffold(
          backgroundColor: AppTheme.midnight,
          appBar: AppBar(
            backgroundColor: Colors.transparent,
            elevation: 0,
            leading: IconButton(
              icon: const Icon(Icons.arrow_back_rounded,
                  color: AppTheme.textPrimary),
              onPressed: () {
                context
                    .read<TournamentBloc>()
                    .add(TournamentDisconnectEvent());
                context.pop();
              },
            ),
            title: Text(
              '🏆 Tournament',
              style: GoogleFonts.fredoka(
                color: AppTheme.goldPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
              ),
            ),
            centerTitle: true,
          ),
          body: Container(
            decoration:
                const BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    _buildStatusBanner(ts),
                    if (ts.engagementMessage != null) ...[
                      const SizedBox(height: 12),
                      _buildEngagementBanner(ts.engagementMessage!),
                    ],
                    const SizedBox(height: 16),
                    _buildRoundIndicator(ts),
                    const SizedBox(height: 16),
                    _buildScoreCard(ts),
                    const SizedBox(height: 16),
                    if (ts.activeTournament?.currentPairings.isNotEmpty ??
                        false)
                      _buildPairings(ts),
                    const SizedBox(height: 16),
                    _buildStandings(ts),
                    const SizedBox(height: 24),
                    if (ts.status == TournamentStatus.waiting)
                      _buildReadyButton(context),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildStatusBanner(TournamentState ts) {
    final (label, color) = switch (ts.status) {
      TournamentStatus.waiting => ('⏳ Waiting for players…', AppTheme.skyBlue),
      TournamentStatus.active => ('⚔️ Tournament in progress', AppTheme.accentGreen),
      TournamentStatus.finished => ('🎉 Tournament finished!', AppTheme.goldPrimary),
      _ => ('Tournament', AppTheme.textSecondary),
    };
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 20),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.15),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: GoogleFonts.fredoka(
            color: color, fontSize: 16, fontWeight: FontWeight.w600),
      ),
    );
  }

  Widget _buildEngagementBanner(String message) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 10, horizontal: 16),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.goldPrimary.withValues(alpha: 0.2),
            AppTheme.accentOrange.withValues(alpha: 0.2),
          ],
        ),
        borderRadius: BorderRadius.circular(14),
        border:
            Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.5)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.fredoka(
            color: AppTheme.goldPrimary,
            fontSize: 15,
            fontWeight: FontWeight.w600),
      ),
    ).animate().shimmer(duration: 1200.ms);
  }

  Widget _buildRoundIndicator(TournamentState ts) {
    final total = ts.totalRounds;
    final current = ts.currentRound;
    return Row(
      mainAxisAlignment: MainAxisAlignment.center,
      children: List.generate(total, (i) {
        final done = i < current;
        final active = i == current - 1;
        return AnimatedContainer(
          duration: const Duration(milliseconds: 300),
          width: active ? 32 : 18,
          height: 18,
          margin: const EdgeInsets.symmetric(horizontal: 3),
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(9),
            color: done
                ? AppTheme.goldPrimary
                : active
                    ? AppTheme.accentGreen
                    : Colors.white.withValues(alpha: 0.15),
          ),
          child: active
              ? Center(
                  child: Text('$current',
                      style: GoogleFonts.fredoka(
                          color: AppTheme.midnight, fontSize: 11)))
              : null,
        );
      }),
    );
  }

  Widget _buildScoreCard(TournamentState ts) {
    final players = ts.activeTournament?.players ?? [];
    if (players.isEmpty) return const SizedBox.shrink();

    final me = players.where((p) => p.id == _myUserId).firstOrNull;
    final opp = players.where((p) => p.id != _myUserId).firstOrNull;

    if (me == null || opp == null) return const SizedBox.shrink();

    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Expanded(child: _buildPlayerScore(me, isMe: true)),
          Column(
            children: [
              Text('VS',
                  style: GoogleFonts.fredoka(
                      color: AppTheme.textMuted,
                      fontSize: 18,
                      fontWeight: FontWeight.w700)),
              const SizedBox(height: 4),
              Text('Round ${ts.currentRound} of ${ts.totalRounds}',
                  style: GoogleFonts.baloo2(
                      color: AppTheme.textMuted, fontSize: 10)),
            ],
          ),
          Expanded(child: _buildPlayerScore(opp, isMe: false)),
        ],
      ),
    );
  }

  Widget _buildPlayerScore(TournamentPlayer p, {required bool isMe}) {
    return Column(
      crossAxisAlignment:
          isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
      children: [
        Text(
          isMe ? 'You' : p.username,
          style: GoogleFonts.fredoka(
            color: isMe ? AppTheme.goldPrimary : AppTheme.textPrimary,
            fontSize: 16,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '${p.score} pts',
          style: GoogleFonts.fredoka(
              color: AppTheme.accentGreen,
              fontSize: 28,
              fontWeight: FontWeight.w700),
        ),
        Text(
          '${p.wins}W / ${p.draws}D / ${p.losses}L',
          style: GoogleFonts.baloo2(
              color: AppTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildPairings(TournamentState ts) {
    final pairings = ts.activeTournament!.currentPairings;
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Current Pairings',
              style: GoogleFonts.fredoka(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...pairings.map((pair) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 4),
                child: Row(
                  children: [
                    Expanded(
                      child: Text(
                        '${pair.player1.username} (${pair.player1Color})',
                        style: GoogleFonts.baloo2(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                    Text('vs',
                        style: GoogleFonts.fredoka(
                            color: AppTheme.textMuted, fontSize: 13)),
                    Expanded(
                      child: Text(
                        '${pair.player2.username} (${pair.player2Color})',
                        textAlign: TextAlign.end,
                        style: GoogleFonts.baloo2(
                            color: AppTheme.textSecondary, fontSize: 13),
                      ),
                    ),
                    const SizedBox(width: 8),
                    GestureDetector(
                      onTap: () => _joinMatch(context, pair.gameId, pair),
                      child: Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 8, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppTheme.goldPrimary.withValues(alpha: 0.2),
                          borderRadius: BorderRadius.circular(8),
                        ),
                        child: Text('Play',
                            style: GoogleFonts.fredoka(
                                color: AppTheme.goldPrimary, fontSize: 12)),
                      ),
                    ),
                  ],
                ),
              )),
        ],
      ),
    );
  }

  Widget _buildStandings(TournamentState ts) {
    final players = ts.activeTournament?.players ?? [];
    if (players.isEmpty) return const SizedBox.shrink();
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Standings',
              style: GoogleFonts.fredoka(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
          const SizedBox(height: 10),
          ...players.asMap().entries.map((e) {
            final rank = e.key + 1;
            final p = e.value;
            final isMe = p.id == _myUserId;
            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor:
                    rank == 1 ? AppTheme.goldPrimary : AppTheme.navyCard,
                child: Text(
                  '$rank',
                  style: GoogleFonts.fredoka(
                      color: rank == 1 ? AppTheme.midnight : AppTheme.textSecondary,
                      fontSize: 12),
                ),
              ),
              title: Text(
                isMe ? 'You' : p.username,
                style: GoogleFonts.baloo2(
                    color: isMe ? AppTheme.goldPrimary : AppTheme.textPrimary,
                    fontWeight: FontWeight.w600,
                    fontSize: 14),
              ),
              trailing: Text(
                '${p.score} pts',
                style: GoogleFonts.fredoka(
                    color: AppTheme.accentGreen,
                    fontSize: 15,
                    fontWeight: FontWeight.w700),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildReadyButton(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentGreen,
        foregroundColor: AppTheme.midnight,
        padding:
            const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        shape:
            RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: () =>
          context.read<TournamentBloc>().add(TournamentReadyEvent()),
      icon: const Icon(Icons.play_arrow_rounded),
      label: Text('Ready!',
          style:
              GoogleFonts.fredoka(fontSize: 20, fontWeight: FontWeight.w700)),
    ).animate().scale();
  }

  void _joinMatch(BuildContext context, String gameId, TournamentPairing pair) {
    // Find my color for this pairing
    String color = 'white';
    if (pair.player1.id == _myUserId) {
      color = pair.player1Color;
    } else if (pair.player2.id == _myUserId) {
      color = pair.player2Color;
    }
    // Navigate to the game room
    context.push('/room/$gameId');
    // color is used by TournamentRoom to assign sides; locally it's informational.
    debugPrint('[TournamentLobby] playing as $color');
  }
}
