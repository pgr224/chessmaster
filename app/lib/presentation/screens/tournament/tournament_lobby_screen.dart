import 'dart:math' as math;

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/tournament_model.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/settings/settings_bloc.dart';
import '../../blocs/tournament/tournament_bloc.dart';
import '../../utils/engagement_notifier.dart';

/// Enhanced Tournament HQ screen with spotlight, podium, analytics,
/// engagement feed, and social actions.
class TournamentLobbyScreen extends StatefulWidget {
  final String tournamentId;
  const TournamentLobbyScreen({super.key, required this.tournamentId});

  @override
  State<TournamentLobbyScreen> createState() => _TournamentLobbyScreenState();
}

class _TournamentLobbyScreenState extends State<TournamentLobbyScreen> {
  String? _myUserId;
  int _lastRoundNotified = -1;
  int _lastKnownRank = -1;
  String? _lastEngagementText;
  final EngagementNotifier _engagement = EngagementNotifier(maxItems: 8);
  final List<TournamentPairing> _pairingHistory = <TournamentPairing>[];

  @override
  void initState() {
    super.initState();
    final authState = context.read<AuthBloc>().state;
    if (authState is AuthAuthenticatedState) {
      _myUserId = authState.user.id;
      context.read<TournamentBloc>().add(
            TournamentConnectEvent(
              tournamentId: widget.tournamentId,
              userId: authState.user.id,
              username: authState.user.username,
              rating: authState.user.xp,
            ),
          );
    }
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<TournamentBloc, TournamentState>(
      listenWhen: (prev, curr) =>
          prev.currentRound != curr.currentRound ||
          prev.engagementMessage != curr.engagementMessage ||
          prev.activeTournament != curr.activeTournament ||
          prev.status != curr.status,
      listener: (context, ts) {
        _captureRoundHistory(ts);
        _handleEngagementNotifications(ts);
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
                context.read<TournamentBloc>().add(TournamentDisconnectEvent());
                context.pop();
              },
            ),
            title: Text(
              '🏆 TOURNAMENT HQ',
              style: GoogleFonts.fredoka(
                color: AppTheme.goldPrimary,
                fontSize: 22,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.8,
              ),
            ),
            centerTitle: true,
          ),
          body: Container(
            decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
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
                    _buildOpponentSpotlight(ts),
                    const SizedBox(height: 16),
                    _buildTopThreePodium(ts.activeTournament?.players ?? const []),
                    const SizedBox(height: 16),
                    _buildScoreCard(ts),
                    const SizedBox(height: 16),
                    _buildPairingsList(ts),
                    const SizedBox(height: 16),
                    _buildRewardsPreview(ts),
                    const SizedBox(height: 16),
                    _buildAnalyticsDashboard(ts),
                    const SizedBox(height: 16),
                    _buildStandings(ts),
                    const SizedBox(height: 16),
                    _buildShareActions(ts),
                    const SizedBox(height: 16),
                    _buildNotificationFeed(),
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

  void _captureRoundHistory(TournamentState ts) {
    final pairings = ts.activeTournament?.currentPairings ?? const <TournamentPairing>[];
    for (final pair in pairings) {
      final isMine = pair.player1.id == _myUserId || pair.player2.id == _myUserId;
      final exists = _pairingHistory.any((p) => p.gameId == pair.gameId);
      if (isMine && !exists) {
        _pairingHistory.add(pair);
      }
    }
  }

  void _handleEngagementNotifications(TournamentState ts) {
    final notificationsEnabled =
        context.read<SettingsBloc>().state.notificationsEnabled;

    if (ts.currentRound > 0 && ts.currentRound != _lastRoundNotified) {
      _lastRoundNotified = ts.currentRound;
      _notify(
        title: 'Round ${ts.currentRound} Started',
        body: 'Stay sharp. Every half-point matters now.',
        notificationsEnabled: notificationsEnabled,
        accent: AppTheme.accentCyan,
      );
    }

    final rank = _myRank(ts.activeTournament?.players ?? const <TournamentPlayer>[]);
    if (rank > 0 && _lastKnownRank > 0 && rank < _lastKnownRank) {
      _notify(
        title: 'Position Improved',
        body: 'You climbed from #$_lastKnownRank to #$rank. Keep pressing.',
        notificationsEnabled: notificationsEnabled,
        accent: AppTheme.goldPrimary,
      );
    }
    if (rank > 0) {
      _lastKnownRank = rank;
    }

    if (ts.engagementMessage != null && ts.engagementMessage != _lastEngagementText) {
      _lastEngagementText = ts.engagementMessage;
      _notify(
        title: 'Tournament Update',
        body: ts.engagementMessage!,
        notificationsEnabled: notificationsEnabled,
        accent: AppTheme.accentOrange,
      );
    }
  }

  void _notify({
    required String title,
    required String body,
    required bool notificationsEnabled,
    required Color accent,
  }) {
    if (!mounted) {
      return;
    }

    _engagement.push(
      context: context,
      globalNotificationsEnabled: notificationsEnabled,
      title: title,
      body: body,
      accent: accent,
    );

    setState(() {});
  }

  Widget _buildStatusBanner(TournamentState ts) {
    final rank = _myRank(ts.activeTournament?.players ?? const <TournamentPlayer>[]);
    final score = _myPlayer(ts.activeTournament?.players ?? const <TournamentPlayer>[])?.score ?? 0;
    final text = 'Round ${math.max(1, ts.currentRound)}/${math.max(1, ts.totalRounds)} | Score: ${score.toStringAsFixed(1)} | Rank: ${rank > 0 ? '#$rank' : '-'}';

    final color = switch (ts.status) {
      TournamentStatus.waiting => AppTheme.skyBlue,
      TournamentStatus.active => AppTheme.accentGreen,
      TournamentStatus.finished => AppTheme.goldPrimary,
      _ => AppTheme.textSecondary,
    };

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 18),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.14),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withValues(alpha: 0.42)),
      ),
      child: Text(
        text,
        textAlign: TextAlign.center,
        style: GoogleFonts.fredoka(
          color: color,
          fontSize: 15,
          fontWeight: FontWeight.w700,
        ),
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
        border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.5)),
      ),
      child: Text(
        message,
        textAlign: TextAlign.center,
        style: GoogleFonts.fredoka(
          color: AppTheme.goldPrimary,
          fontSize: 15,
          fontWeight: FontWeight.w600,
        ),
      ),
    ).animate().shimmer(duration: 1200.ms);
  }

  Widget _buildRoundIndicator(TournamentState ts) {
    final total = math.max(1, ts.totalRounds);
    final current = ts.currentRound.clamp(0, total);
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
                  child: Text(
                    '$current',
                    style: GoogleFonts.fredoka(
                      color: AppTheme.midnight,
                      fontSize: 11,
                    ),
                  ),
                )
              : null,
        );
      }),
    );
  }

  Widget _buildOpponentSpotlight(TournamentState ts) {
    final pairings = ts.activeTournament?.currentPairings ?? const <TournamentPairing>[];
    final myPair = pairings.where((p) => p.player1.id == _myUserId || p.player2.id == _myUserId).firstOrNull;
    if (myPair == null) {
      return const SizedBox.shrink();
    }

    final me = myPair.player1.id == _myUserId ? myPair.player1 : myPair.player2;
    final opponent = myPair.player1.id == _myUserId ? myPair.player2 : myPair.player1;
    final winProb = _winProbability(me.rating, opponent.rating);
    final pseudoH2H = '${me.wins}-${me.losses}';

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.35)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            '⚡ Next Opponent Spotlight',
            style: GoogleFonts.fredoka(
              color: AppTheme.accentCyan,
              fontSize: 15,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Row(
            children: [
              CircleAvatar(
                radius: 20,
                backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.3),
                child: Text(
                  opponent.username.characters.first.toUpperCase(),
                  style: GoogleFonts.fredoka(color: AppTheme.textPrimary),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      opponent.username,
                      style: GoogleFonts.fredoka(
                        color: AppTheme.textPrimary,
                        fontSize: 18,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      'Rating ${opponent.rating} • H2H this event $pseudoH2H',
                      style: GoogleFonts.baloo2(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ],
                ),
              ),
              FilledButton(
                onPressed: () => context.push('/profile'),
                style: FilledButton.styleFrom(
                  backgroundColor: AppTheme.accentCyan.withValues(alpha: 0.2),
                  foregroundColor: AppTheme.accentCyan,
                ),
                child: const Text('View Profile'),
              ),
            ],
          ),
          const SizedBox(height: 10),
          LinearProgressIndicator(
            minHeight: 8,
            value: winProb,
            backgroundColor: Colors.white.withValues(alpha: 0.1),
            color: AppTheme.goldPrimary,
            borderRadius: BorderRadius.circular(999),
          ),
          const SizedBox(height: 6),
          Text(
            'Win probability: ${(winProb * 100).toStringAsFixed(0)}%',
            style: GoogleFonts.baloo2(
              color: AppTheme.goldPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildTopThreePodium(List<TournamentPlayer> players) {
    if (players.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = [...players]..sort((a, b) {
        final scoreCmp = b.score.compareTo(a.score);
        if (scoreCmp != 0) return scoreCmp;
        return b.rating.compareTo(a.rating);
      });

    final top = sorted.take(math.min(3, sorted.length)).toList(growable: false);

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Top Standings Podium',
            style: GoogleFonts.fredoka(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          Row(
            children: List.generate(top.length, (index) {
              final p = top[index];
              final medal = index == 0 ? '🥇' : index == 1 ? '🥈' : '🥉';
              final leadText = index == 0
                  ? 'Leader'
                  : '${(top[index - 1].score - p.score).toStringAsFixed(1)} behind';
              return Expanded(
                child: Container(
                  margin: const EdgeInsets.symmetric(horizontal: 4),
                  padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(14),
                    border: Border.all(
                      color: index == 0
                          ? AppTheme.goldPrimary.withValues(alpha: 0.45)
                          : Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                  child: Column(
                    children: [
                      Text(medal, style: const TextStyle(fontSize: 20)),
                      const SizedBox(height: 4),
                      Text(
                        p.id == _myUserId ? 'You' : p.username,
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                        style: GoogleFonts.fredoka(
                          color: AppTheme.textPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        '${p.score.toStringAsFixed(1)} pts',
                        style: GoogleFonts.fredoka(
                          color: AppTheme.accentGreen,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      Text(
                        'R${p.rating}',
                        style: GoogleFonts.baloo2(
                          color: AppTheme.textSecondary,
                          fontSize: 11,
                        ),
                      ),
                      Text(
                        leadText,
                        style: GoogleFonts.baloo2(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              );
            }),
          ),
        ],
      ),
    );
  }

  Widget _buildScoreCard(TournamentState ts) {
    final players = ts.activeTournament?.players ?? [];
    if (players.isEmpty) {
      return const SizedBox.shrink();
    }

    final me = players.where((p) => p.id == _myUserId).firstOrNull;
    final opp = players.where((p) => p.id != _myUserId).firstOrNull;

    if (me == null || opp == null) {
      return const SizedBox.shrink();
    }

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
              Text(
                'VS',
                style: GoogleFonts.fredoka(
                  color: AppTheme.textMuted,
                  fontSize: 18,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 4),
              Text(
                'Round ${ts.currentRound} of ${ts.totalRounds}',
                style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 10),
              ),
            ],
          ),
          Expanded(child: _buildPlayerScore(opp, isMe: false)),
        ],
      ),
    );
  }

  Widget _buildPlayerScore(TournamentPlayer p, {required bool isMe}) {
    return Column(
      crossAxisAlignment: isMe ? CrossAxisAlignment.start : CrossAxisAlignment.end,
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
          '${p.score.toStringAsFixed(1)} pts',
          style: GoogleFonts.fredoka(
            color: AppTheme.accentGreen,
            fontSize: 28,
            fontWeight: FontWeight.w700,
          ),
        ),
        Text(
          '${p.wins}W / ${p.draws}D / ${p.losses}L',
          style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 11),
        ),
      ],
    );
  }

  Widget _buildPairingsList(TournamentState ts) {
    final current = ts.activeTournament?.currentPairings ?? const <TournamentPairing>[];
    final items = <_PairingListItem>[];

    for (final pair in _pairingHistory) {
      items.add(_PairingListItem(pairing: pair, kind: _PairingKind.completed));
    }
    for (final pair in current) {
      if (!items.any((item) => item.pairing.gameId == pair.gameId)) {
        items.add(_PairingListItem(pairing: pair, kind: _PairingKind.live));
      }
    }

    final futureRounds = math.max(0, ts.totalRounds - math.max(0, ts.currentRound));

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
          Text(
            'Pairings Timeline',
            style: GoogleFonts.fredoka(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          if (items.isEmpty)
            Text(
              'Waiting for pairings...',
              style: GoogleFonts.baloo2(color: AppTheme.textMuted),
            ),
          ...items.map((item) => _buildPairingRow(ts, item)),
          if (futureRounds > 0) ...[
            const SizedBox(height: 6),
            Text(
              '⏰ Upcoming rounds: $futureRounds',
              style: GoogleFonts.baloo2(
                color: AppTheme.textMuted,
                fontSize: 12,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildPairingRow(TournamentState ts, _PairingListItem item) {
    final pair = item.pairing;
    final isMine = pair.player1.id == _myUserId || pair.player2.id == _myUserId;
    final live = item.kind == _PairingKind.live;
    final tag = live ? 'LIVE' : 'DONE';
    final tagColor = live ? AppTheme.accentGreen : AppTheme.textMuted;

    return Container(
      margin: const EdgeInsets.only(bottom: 8),
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.04),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Column(
        children: [
          Row(
            children: [
              Expanded(
                child: Text(
                  '${pair.player1.username} (${pair.player1Color})',
                  style: GoogleFonts.baloo2(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              Text('vs', style: GoogleFonts.fredoka(color: AppTheme.textMuted, fontSize: 12)),
              Expanded(
                child: Text(
                  '${pair.player2.username} (${pair.player2Color})',
                  textAlign: TextAlign.end,
                  style: GoogleFonts.baloo2(
                    color: AppTheme.textSecondary,
                    fontSize: 12,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: 8),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 7, vertical: 4),
                decoration: BoxDecoration(
                  color: tagColor.withValues(alpha: 0.16),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  tag,
                  style: GoogleFonts.fredoka(
                    color: tagColor,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 6),
          Row(
            children: [
              Text(
                'Moves ${pair.moveCount} • Captures ${pair.captureCount} • Eval swing ${pair.evalSwing.toStringAsFixed(1)}',
                style: GoogleFonts.baloo2(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                ),
              ),
              const Spacer(),
              if (live && isMine)
                GestureDetector(
                  onTap: () => _joinMatch(context, pair.gameId, pair),
                  child: Container(
                    padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                    decoration: BoxDecoration(
                      color: AppTheme.goldPrimary.withValues(alpha: 0.22),
                      borderRadius: BorderRadius.circular(8),
                    ),
                    child: Text(
                      'Play',
                      style: GoogleFonts.fredoka(
                        color: AppTheme.goldPrimary,
                        fontSize: 11,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRewardsPreview(TournamentState ts) {
    final rounds = math.max(1, ts.totalRounds);
    final first = 120 * rounds;
    final second = 80 * rounds;
    final third = 50 * rounds;
    final participation = 25 * rounds;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.25)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Rewards Preview',
            style: GoogleFonts.fredoka(
              color: AppTheme.goldPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          _rewardRow('🥇 1st Place', '$first XP + Tournament Victor badge'),
          _rewardRow('🥈 2nd Place', '$second XP + Runner-Up badge'),
          _rewardRow('🥉 3rd Place', '$third XP + Bronze badge'),
          _rewardRow('🎯 Participation', '$participation XP'),
          const SizedBox(height: 6),
          Text(
            'Bonus multiplier: x${(1 + (rounds / 20)).toStringAsFixed(2)} for full-round completion',
            style: GoogleFonts.baloo2(
              color: AppTheme.textMuted,
              fontSize: 11,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _rewardRow(String title, String value) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Row(
        children: [
          Expanded(
            child: Text(
              title,
              style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 13,
                fontWeight: FontWeight.w700,
              ),
            ),
          ),
          Text(
            value,
            style: GoogleFonts.baloo2(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildAnalyticsDashboard(TournamentState ts) {
    final players = ts.activeTournament?.players ?? const <TournamentPlayer>[];
    final me = _myPlayer(players);
    if (me == null) {
      return const SizedBox.shrink();
    }

    final roundsPlayed = math.max(1, me.wins + me.draws + me.losses);
    final formIndex = ((me.wins * 3) + me.draws) / (roundsPlayed * 3);
    final avgOpp = me.averageOpponentRating == 0
        ? _avgOpponentRating(players)
        : me.averageOpponentRating.toDouble();

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Analytics Dashboard',
            style: GoogleFonts.fredoka(
              color: AppTheme.skyBlue,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              _metricChip('Rating Δ', '${me.ratingChange >= 0 ? '+' : ''}${me.ratingChange}', AppTheme.skyBlue),
              _metricChip('Accuracy', '${me.accuracy.toStringAsFixed(1)}%', AppTheme.accentGreen),
              _metricChip('Form', '${(formIndex * 100).toStringAsFixed(0)}%', AppTheme.goldPrimary),
              _metricChip('Avg Opp', avgOpp.toStringAsFixed(0), AppTheme.accentOrange),
            ],
          ),
          const SizedBox(height: 12),
          Text(
            'Trajectory',
            style: GoogleFonts.baloo2(
              color: AppTheme.textSecondary,
              fontSize: 12,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 6),
          _buildMiniTrajectory(me, ts.totalRounds),
        ],
      ),
    );
  }

  Widget _metricChip(String title, String value, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 8),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: color.withValues(alpha: 0.35)),
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            value,
            style: GoogleFonts.fredoka(
              color: color,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
          ),
          Text(
            title,
            style: GoogleFonts.baloo2(
              color: AppTheme.textMuted,
              fontSize: 10,
              fontWeight: FontWeight.w600,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildMiniTrajectory(TournamentPlayer me, int totalRounds) {
    final rounds = math.max(1, totalRounds);
    final scoreRatio = (me.score / rounds).clamp(0, 1);
    final accuracyRatio = (me.accuracy / 100).clamp(0, 1);
    final streakRatio = (me.longestWinStreak / rounds).clamp(0, 1);
    final bars = [scoreRatio, accuracyRatio, streakRatio];

    return Row(
      crossAxisAlignment: CrossAxisAlignment.end,
      children: List.generate(bars.length, (i) {
        return Expanded(
          child: Container(
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 46,
            alignment: Alignment.bottomCenter,
            child: Container(
              height: math.max(6, 40 * bars[i]),
              decoration: BoxDecoration(
                color: i == 0
                    ? AppTheme.goldPrimary
                    : i == 1
                        ? AppTheme.accentGreen
                        : AppTheme.skyBlue,
                borderRadius: BorderRadius.circular(8),
              ),
            ),
          ),
        );
      }),
    );
  }

  Widget _buildStandings(TournamentState ts) {
    final players = ts.activeTournament?.players ?? [];
    if (players.isEmpty) {
      return const SizedBox.shrink();
    }

    final sorted = [...players]..sort((a, b) {
        final scoreCmp = b.score.compareTo(a.score);
        if (scoreCmp != 0) return scoreCmp;
        return b.rating.compareTo(a.rating);
      });

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
          Text(
            'Full Standings',
            style: GoogleFonts.fredoka(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          ...sorted.asMap().entries.map((entry) {
            final rank = entry.key + 1;
            final p = entry.value;
            final isMe = p.id == _myUserId;

            return ListTile(
              dense: true,
              contentPadding: EdgeInsets.zero,
              leading: CircleAvatar(
                radius: 14,
                backgroundColor: rank == 1 ? AppTheme.goldPrimary : AppTheme.navyCard,
                child: Text(
                  '$rank',
                  style: GoogleFonts.fredoka(
                    color: rank == 1 ? AppTheme.midnight : AppTheme.textSecondary,
                    fontSize: 12,
                  ),
                ),
              ),
              title: Text(
                isMe ? 'You' : p.username,
                style: GoogleFonts.baloo2(
                  color: isMe ? AppTheme.goldPrimary : AppTheme.textPrimary,
                  fontWeight: FontWeight.w700,
                  fontSize: 14,
                ),
              ),
              subtitle: Text(
                'Rating ${p.rating}',
                style: GoogleFonts.baloo2(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                ),
              ),
              trailing: Text(
                '${p.score.toStringAsFixed(1)} pts',
                style: GoogleFonts.fredoka(
                  color: AppTheme.accentGreen,
                  fontSize: 15,
                  fontWeight: FontWeight.w700,
                ),
              ),
            );
          }),
        ],
      ),
    );
  }

  Widget _buildShareActions(TournamentState ts) {
    final rank = _myRank(ts.activeTournament?.players ?? const <TournamentPlayer>[]);
    final score = _myPlayer(ts.activeTournament?.players ?? const <TournamentPlayer>[])?.score ?? 0;

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Share & Social',
            style: GoogleFonts.fredoka(
              color: AppTheme.textPrimary,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
          Wrap(
            spacing: 10,
            runSpacing: 10,
            children: [
              FilledButton.icon(
                onPressed: () {
                  Share.share(
                    'I am currently #$rank in a live chess tournament with ${score.toStringAsFixed(1)} points. Join me in Chess Master! ',
                  );
                },
                icon: const Icon(Icons.ios_share_rounded),
                label: const Text('Share'),
              ),
              OutlinedButton.icon(
                onPressed: () => _showStatsModal(ts),
                icon: const Icon(Icons.query_stats_rounded),
                label: const Text('View Stats'),
              ),
              OutlinedButton.icon(
                onPressed: () {
                  setState(() {
                    _engagement.toggleNotify();
                  });
                  _notify(
                    title: _engagement.notifyEnabled
                        ? 'Notifications On'
                        : 'Notifications Off',
                    body: _engagement.notifyEnabled
                        ? 'You will receive tournament engagement alerts.'
                        : 'In-app tournament alerts are muted.',
                    notificationsEnabled: false,
                    accent: _engagement.notifyEnabled
                        ? AppTheme.accentGreen
                        : AppTheme.textMuted,
                  );
                },
                icon: Icon(_engagement.notifyEnabled
                    ? Icons.notifications_active
                    : Icons.notifications_off),
                label: Text(_engagement.notifyEnabled
                    ? 'Notify Me: ON'
                    : 'Notify Me: OFF'),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildNotificationFeed() {
    if (_engagement.feed.isEmpty) {
      return const SizedBox.shrink();
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Engagement Feed',
            style: GoogleFonts.fredoka(
              color: AppTheme.accentOrange,
              fontSize: 16,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 10),
              ..._engagement.feed.take(4).map(
                (item) => Container(
                  margin: const EdgeInsets.only(bottom: 8),
                  padding: const EdgeInsets.all(10),
                  decoration: BoxDecoration(
                    color: item.accent.withValues(alpha: 0.08),
                    borderRadius: BorderRadius.circular(12),
                    border: Border.all(color: item.accent.withValues(alpha: 0.24)),
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
                      Text(
                        _engagement.timeAgo(item.createdAt),
                        style: GoogleFonts.baloo2(
                          color: AppTheme.textMuted,
                          fontSize: 10,
                        ),
                      ),
                    ],
                  ),
                ),
              ),
        ],
      ),
    );
  }

  Widget _buildReadyButton(BuildContext context) {
    return ElevatedButton.icon(
      style: ElevatedButton.styleFrom(
        backgroundColor: AppTheme.accentGreen,
        foregroundColor: AppTheme.midnight,
        padding: const EdgeInsets.symmetric(vertical: 16, horizontal: 32),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
      ),
      onPressed: () => context.read<TournamentBloc>().add(TournamentReadyEvent()),
      icon: const Icon(Icons.play_arrow_rounded),
      label: Text(
        'Ready!',
        style: GoogleFonts.fredoka(fontSize: 20, fontWeight: FontWeight.w700),
      ),
    ).animate().scale();
  }

  void _showStatsModal(TournamentState ts) {
    final me = _myPlayer(ts.activeTournament?.players ?? const <TournamentPlayer>[]);
    if (me == null) {
      return;
    }

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) {
        return Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
            borderRadius: const BorderRadius.vertical(top: Radius.circular(24)),
            border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'Performance Stats',
                style: GoogleFonts.fredoka(
                  color: AppTheme.textPrimary,
                  fontSize: 20,
                  fontWeight: FontWeight.w700,
                ),
              ),
              const SizedBox(height: 12),
              Text(
                'Score: ${me.score.toStringAsFixed(1)} | Record: ${me.wins}-${me.draws}-${me.losses}',
                style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 14),
              ),
              Text(
                'Accuracy: ${me.accuracy.toStringAsFixed(1)}% | Longest streak: ${me.longestWinStreak}',
                style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 14),
              ),
              Text(
                'Rating delta: ${me.ratingChange >= 0 ? '+' : ''}${me.ratingChange}',
                style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 14),
              ),
              const SizedBox(height: 12),
            ],
          ),
        );
      },
    );
  }

  TournamentPlayer? _myPlayer(List<TournamentPlayer> players) {
    return players.where((p) => p.id == _myUserId).firstOrNull;
  }

  int _myRank(List<TournamentPlayer> players) {
    if (_myUserId == null || players.isEmpty) {
      return -1;
    }
    final sorted = [...players]..sort((a, b) {
        final scoreCmp = b.score.compareTo(a.score);
        if (scoreCmp != 0) return scoreCmp;
        return b.rating.compareTo(a.rating);
      });
    final index = sorted.indexWhere((p) => p.id == _myUserId);
    return index >= 0 ? index + 1 : -1;
  }

  double _winProbability(int myRating, int oppRating) {
    final exponent = (oppRating - myRating) / 400.0;
    return (1 / (1 + math.pow(10, exponent))).toDouble().clamp(0, 1);
  }

  double _avgOpponentRating(List<TournamentPlayer> players) {
    final opponents = players.where((p) => p.id != _myUserId).toList(growable: false);
    if (opponents.isEmpty) {
      return 0;
    }
    final sum = opponents.fold<int>(0, (acc, p) => acc + p.rating);
    return sum / opponents.length;
  }

  void _joinMatch(BuildContext context, String gameId, TournamentPairing pair) {
    String color = 'white';
    if (pair.player1.id == _myUserId) {
      color = pair.player1Color;
    } else if (pair.player2.id == _myUserId) {
      color = pair.player2Color;
    }

    context.push('/room/$gameId');
    debugPrint('[TournamentLobby] playing as $color');
  }
}

enum _PairingKind { completed, live }

class _PairingListItem {
  final TournamentPairing pairing;
  final _PairingKind kind;

  const _PairingListItem({required this.pairing, required this.kind});
}
