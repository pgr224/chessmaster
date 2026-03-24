import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class Tournament {
  final String id;
  final String name;
  final String status; // 'open', 'ongoing', 'completed'
  final int participants;
  final String prize;
  final DateTime startTime;

  const Tournament({
    required this.id,
    required this.name,
    required this.status,
    required this.participants,
    required this.prize,
    required this.startTime,
  });
}

class TournamentScreen extends StatelessWidget {
  const TournamentScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final tournaments = [
      Tournament(
        id: '1',
        name: 'Grandmaster Open',
        status: 'open',
        participants: 128,
        prize: '🥇 1000 XP + Rare Icon',
        startTime: DateTime.now().add(const Duration(hours: 4)),
      ),
      Tournament(
        id: '2',
        name: 'Blitz Brawl',
        status: 'ongoing',
        participants: 64,
        prize: '⚡ 500 XP',
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      Tournament(
        id: '3',
        name: 'Weekend Warrior',
        status: 'completed',
        participants: 32,
        prize: '🛡️ Exclusive Border',
        startTime: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: const Text('Global Tournaments', style: TextStyle(color: AppTheme.textPrimary)),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildStatsHeader(),
              Expanded(
                child: ListView.builder(
                  padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
                  itemCount: tournaments.length,
                  itemBuilder: (context, index) => _buildTournamentCard(context, tournaments[index], index),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsHeader() {
    return Container(
      padding: const EdgeInsets.all(24),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('1.2k', 'Total Prize', Icons.emoji_events_rounded, AppTheme.goldPrimary),
          _statItem('42', 'Active Tourney', Icons.sports_esports_rounded, AppTheme.accentCyan),
          _statItem('8k', 'Live Players', Icons.people_rounded, AppTheme.accentGreen),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _statItem(String value, String label, IconData icon, Color color) {
    return Column(children: [
      Icon(icon, color: color, size: 24),
      const SizedBox(height: 8),
      Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
      Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
    ]);
  }

  Widget _buildTournamentCard(BuildContext context, Tournament t, int index) {
    final isOpen = t.status == 'open';
    return GestureDetector(
      onTap: () => context.push('/tournament/${t.id}/bracket'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(20),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                           Container(
                            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                            decoration: BoxDecoration(
                              color: _statusColor(t.status).withOpacity(0.15),
                              borderRadius: BorderRadius.circular(8),
                            ),
                            child: Text(
                              t.status.toUpperCase(),
                              style: TextStyle(color: _statusColor(t.status), fontSize: 10, fontWeight: FontWeight.w800),
                            ),
                          ),
                          const SizedBox(width: 8),
                          Text(t.prize, style: const TextStyle(color: AppTheme.goldPrimary, fontSize: 11, fontWeight: FontWeight.bold)),
                        ]),
                        const SizedBox(height: 12),
                        Text(t.name, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold)),
                        const SizedBox(height: 4),
                        Text('${t.participants} Participants • Starts in 3h 12m', 
                          style: const TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
                      ],
                    ),
                  ),
                  const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
                ],
              ),
            ),
            if (isOpen)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(20)),
                child: SizedBox(
                  width: double.infinity,
                  height: 48,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.goldPrimary,
                      shape: const RoundedRectangleBorder(),
                    ),
                    onPressed: () {},
                    child: const Text('JOIN NOW', style: TextStyle(color: AppTheme.midnight, fontWeight: FontWeight.w800)),
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 150).ms).slideX(begin: 0.05);
  }

  Color _statusColor(String s) => switch (s) {
    'open' => AppTheme.accentGreen,
    'ongoing' => AppTheme.goldPrimary,
    _ => AppTheme.textMuted,
  };
}
