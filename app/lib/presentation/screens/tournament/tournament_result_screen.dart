import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';
import '../../../data/models/tournament_model.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../blocs/tournament/tournament_bloc.dart';

/// Full-page results screen shown after a tournament ends.
class TournamentResultScreen extends StatelessWidget {
  final String tournamentId;
  const TournamentResultScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<TournamentBloc, TournamentState>(
      builder: (context, ts) {
        final authState = context.watch<AuthBloc>().state;
        final myId = authState is AuthAuthenticatedState
            ? authState.user.id
            : null;

        final players = ts.activeTournament?.players ?? [];
        final winner =
            players.isNotEmpty ? players.first : null;
        final iWon = winner?.id == myId;

        return Scaffold(
          backgroundColor: AppTheme.midnight,
          body: Container(
            decoration:
                const BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: SafeArea(
              child: SingleChildScrollView(
                padding: const EdgeInsets.all(24),
                child: Column(
                  children: [
                    const SizedBox(height: 20),
                    _buildTrophy(iWon),
                    const SizedBox(height: 16),
                    Text(
                      iWon ? '🎉 You Won the Tournament!' : '🥈 Tournament Complete',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fredoka(
                        color: iWon
                            ? AppTheme.goldPrimary
                            : AppTheme.textPrimary,
                        fontSize: 26,
                        fontWeight: FontWeight.w700,
                      ),
                    ).animate().fadeIn().slideY(begin: 0.2),
                    if (winner != null && !iWon) ...[
                      const SizedBox(height: 6),
                      Text(
                        '${winner.username} wins this tournament 👑',
                        textAlign: TextAlign.center,
                        style: GoogleFonts.baloo2(
                            color: AppTheme.textSecondary, fontSize: 14),
                      ),
                    ],
                    const SizedBox(height: 28),
                    _buildXpCard(ts, myId),
                    const SizedBox(height: 16),
                    _buildStandings(players, myId),
                    const SizedBox(height: 32),
                    _buildActions(context),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildTrophy(bool iWon) {
    return Text(
      iWon ? '🏆' : '🏅',
      style: const TextStyle(fontSize: 72),
    ).animate().scale(delay: 200.ms, duration: 600.ms, curve: Curves.elasticOut);
  }

  Widget _buildXpCard(TournamentState ts, String? myId) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: LinearGradient(
          colors: [
            AppTheme.goldPrimary.withValues(alpha: 0.15),
            AppTheme.accentOrange.withValues(alpha: 0.1),
          ],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.4)),
      ),
      child: Column(
        children: [
          Text(
            '+${ts.xpEarned} XP',
            style: GoogleFonts.fredoka(
              color: AppTheme.goldPrimary,
              fontSize: 40,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 4),
          Text(
            'Tournament Reward',
            style: GoogleFonts.baloo2(
                color: AppTheme.textSecondary, fontSize: 13),
          ),
          const SizedBox(height: 12),
          const Divider(color: AppTheme.textMuted),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _buildSmallStat('ELO', '${ts.eloChange >= 0 ? '+' : ''}${ts.eloChange}', AppTheme.skyBlue),
            ],
          ),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.15);
  }

  Widget _buildSmallStat(String label, String value, Color color) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.fredoka(
                color: color, fontSize: 18, fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.baloo2(
                color: AppTheme.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _buildStandings(List<TournamentPlayer> players, String? myId) {
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
          Text('Final Standings',
              style: GoogleFonts.fredoka(
                  color: AppTheme.textPrimary,
                  fontSize: 18,
                  fontWeight: FontWeight.w700)),
          const SizedBox(height: 12),
          ...players.asMap().entries.map((e) {
            final rank = e.key + 1;
            final p = e.value;
            final isMe = p.id == myId;
            return Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding:
                  const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                color: isMe
                    ? AppTheme.goldPrimary.withValues(alpha: 0.12)
                    : Colors.white.withValues(alpha: 0.04),
                borderRadius: BorderRadius.circular(12),
                border: Border.all(
                  color: isMe
                      ? AppTheme.goldPrimary.withValues(alpha: 0.4)
                      : Colors.transparent,
                ),
              ),
              child: Row(
                children: [
                  Text(
                    rank == 1
                        ? '🥇'
                        : rank == 2
                            ? '🥈'
                            : '🥉',
                    style: const TextStyle(fontSize: 22),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isMe ? 'You' : p.username,
                          style: GoogleFonts.baloo2(
                              color: isMe
                                  ? AppTheme.goldPrimary
                                  : AppTheme.textPrimary,
                              fontWeight: FontWeight.w700,
                              fontSize: 14),
                        ),
                        Text(
                          '${p.wins}W / ${p.draws}D / ${p.losses}L',
                          style: GoogleFonts.baloo2(
                              color: AppTheme.textMuted, fontSize: 11),
                        ),
                      ],
                    ),
                  ),
                  Text(
                    '${p.score} pts',
                    style: GoogleFonts.fredoka(
                        color: AppTheme.accentGreen,
                        fontSize: 16,
                        fontWeight: FontWeight.w700),
                  ),
                ],
              ),
            );
          }),
        ],
      ),
    ).animate().fadeIn(delay: 600.ms);
  }

  Widget _buildActions(BuildContext context) {
    return Column(
      children: [
        ElevatedButton.icon(
          style: ElevatedButton.styleFrom(
            backgroundColor: AppTheme.goldPrimary,
            foregroundColor: AppTheme.midnight,
            minimumSize: const Size(double.infinity, 54),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: () {
            context.read<TournamentBloc>().add(TournamentDisconnectEvent());
            context.go('/lobby');
          },
          icon: const Icon(Icons.replay_rounded),
          label: Text('New Tournament',
              style: GoogleFonts.fredoka(
                  fontSize: 18, fontWeight: FontWeight.w700)),
        ),
        const SizedBox(height: 12),
        OutlinedButton.icon(
          style: OutlinedButton.styleFrom(
            side: const BorderSide(color: AppTheme.textMuted),
            minimumSize: const Size(double.infinity, 50),
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
          ),
          onPressed: () {
            context.read<TournamentBloc>().add(TournamentDisconnectEvent());
            context.go('/home');
          },
          icon: const Icon(Icons.home_rounded, color: AppTheme.textSecondary),
          label: Text('Back to Home',
              style: GoogleFonts.fredoka(
                  color: AppTheme.textSecondary,
                  fontSize: 16,
                  fontWeight: FontWeight.w600)),
        ),
      ],
    ).animate().fadeIn(delay: 800.ms);
  }
}
