import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class Match {
  final String player1;
  final String player2;
  final String? score1;
  final String? score2;
  final bool isFinished;

  const Match({
    required this.player1,
    required this.player2,
    this.score1,
    this.score2,
    this.isFinished = false,
  });
}

class BracketScreen extends StatelessWidget {
  final String tournamentId;
  const BracketScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Tournament Bracket', style: TextStyle(color: AppTheme.textPrimary)),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SingleChildScrollView(
          scrollDirection: Axis.horizontal,
          child: SingleChildScrollView(
            child: Padding(
              padding: const EdgeInsets.all(32.0),
              child: Row(
                children: [
                  _buildRound('Quarter Finals', [
                    const Match(player1: 'Magnus C.', player2: 'Hikaru N.', score1: '1', score2: '0', isFinished: true),
                    const Match(player1: 'Fabiano C.', player2: 'Anish G.', score1: '0.5', score2: '0.5', isFinished: true),
                    const Match(player1: 'Vidit Groure', player2: 'Alireza F.', score1: '0', score2: '1', isFinished: true),
                    const Match(player1: 'Levon A.', player2: 'Ding L.', score1: '1', score2: '0', isFinished: true),
                  ]),
                  _buildRoundSpacer(),
                  _buildRound('Semi Finals', [
                    const Match(player1: 'Magnus C.', player2: 'Fabiano C.', score1: '-', score2: '-'),
                    const Match(player1: 'Alireza F.', player2: 'Levon A.', score1: '-', score2: '-'),
                  ]),
                  _buildRoundSpacer(),
                  _buildRound('Finals', [
                    const Match(player1: 'Winner SF1', player2: 'Winner SF2', score1: '-', score2: '-'),
                  ]),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildRound(String title, List<Match> matches) {
    return Column(
      children: [
        Text(title.toUpperCase(), style: const TextStyle(color: AppTheme.goldPrimary, fontSize: 13, fontWeight: FontWeight.bold, letterSpacing: 1.5)),
        const SizedBox(height: 32),
        ...matches.map((m) => _buildMatchCard(m)).toList(),
      ],
    );
  }

  Widget _buildMatchCard(Match m) {
    return Container(
      width: 220,
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.navyCard,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
      ),
      child: Column(
        children: [
          _buildMatchRow(m.player1, m.score1, m.isFinished && (m.score1 == '1' || m.score1 == '0.5')),
          const Divider(color: Colors.white12, height: 1),
          _buildMatchRow(m.player2, m.score2, m.isFinished && (m.score2 == '1' || m.score2 == '0.5')),
        ],
      ),
    ).animate().fadeIn().slideX(begin: 0.1);
  }

  Widget _buildMatchRow(String player, String? score, bool isWinner) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Expanded(
            child: Text(
              player,
              style: TextStyle(
                color: isWinner ? AppTheme.goldPrimary : AppTheme.textPrimary,
                fontWeight: isWinner ? FontWeight.bold : FontWeight.normal,
                fontSize: 14,
              ),
            ),
          ),
          Text(
            score ?? '-',
            style: TextStyle(
              color: isWinner ? AppTheme.goldPrimary : AppTheme.textSecondary,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
          ),
          if (isWinner) ...[
            const SizedBox(width: 8),
            const Icon(Icons.check_circle_rounded, color: AppTheme.goldPrimary, size: 14),
          ],
        ],
      ),
    );
  }

  Widget _buildRoundSpacer() {
    return Container(
      width: 40,
      height: 2,
      color: Colors.white10,
    );
  }
}
