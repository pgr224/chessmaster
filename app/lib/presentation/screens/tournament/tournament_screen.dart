import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class Tournament {
  final String id;
  final String name;
  final String status;
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
        id: '1', name: 'Grandmaster Open', status: 'open',
        participants: 128, prize: '🥇 1000 XP + Rare Icon',
        startTime: DateTime.now().add(const Duration(hours: 4)),
      ),
      Tournament(
        id: '2', name: 'Blitz Brawl', status: 'ongoing',
        participants: 64, prize: '⚡ 500 XP',
        startTime: DateTime.now().subtract(const Duration(minutes: 30)),
      ),
      Tournament(
        id: '3', name: 'Weekend Warrior', status: 'completed',
        participants: 32, prize: '🛡️ Exclusive Border',
        startTime: DateTime.now().subtract(const Duration(days: 2)),
      ),
    ];

    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 28),
          onPressed: () => context.pop(),
        ),
        title: Text('🏆 Tournaments',
          style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
        ),
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
          _statItem('1.2k', '🏅 Prize Pool', AppTheme.goldPrimary),
          _statItem('42', '🎯 Active', AppTheme.skyBlue),
          _statItem('8k', '👥 Live', AppTheme.accentCyan),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.1);
  }

  Widget _statItem(String value, String label, Color color) {
    return Column(children: [
      Text(value, style: GoogleFonts.fredoka(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
      const SizedBox(height: 4),
      Text(label, style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 13)),
    ]);
  }

  Widget _buildTournamentCard(BuildContext context, Tournament t, int index) {
    final isOpen = t.status == 'open';
    return GestureDetector(
      onTap: () => context.push('/tournament/${t.id}/bracket'),
      child: Container(
        margin: const EdgeInsets.only(bottom: 18),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: _statusColor(t.status).withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(
              color: _statusColor(t.status).withValues(alpha: 0.1),
              blurRadius: 16, offset: const Offset(0, 6),
            ),
          ],
        ),
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.all(22),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(children: [
                          Container(
                            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 5),
                            decoration: BoxDecoration(
                              color: _statusColor(t.status).withValues(alpha: 0.15),
                              borderRadius: BorderRadius.circular(10),
                            ),
                            child: Text(
                              t.status.toUpperCase(),
                              style: GoogleFonts.fredoka(
                                color: _statusColor(t.status), fontSize: 11, fontWeight: FontWeight.w600,
                              ),
                            ),
                          ),
                          const SizedBox(width: 10),
                          Text(t.prize, style: GoogleFonts.baloo2(
                            color: AppTheme.goldPrimary, fontSize: 13, fontWeight: FontWeight.w600,
                          )),
                        ]),
                        const SizedBox(height: 14),
                        Text(t.name, style: GoogleFonts.fredoka(
                          color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w600,
                        )),
                        const SizedBox(height: 6),
                        Text('${t.participants} players • Starts in 3h 12m',
                          style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 14),
                        ),
                      ],
                    ),
                  ),
                  Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted, size: 28),
                ],
              ),
            ),
            if (isOpen)
              ClipRRect(
                borderRadius: const BorderRadius.vertical(bottom: Radius.circular(24)),
                child: SizedBox(
                  width: double.infinity,
                  height: 52,
                  child: ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.accentCyan,
                      shape: const RoundedRectangleBorder(),
                    ),
                    onPressed: () {},
                    child: Text('🚀 JOIN NOW',
                      style: GoogleFonts.fredoka(color: AppTheme.midnight, fontWeight: FontWeight.w700, fontSize: 17),
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 150).ms).slideX(begin: 0.05);
  }

  Color _statusColor(String s) => switch (s) {
    'open' => AppTheme.accentCyan,
    'ongoing' => AppTheme.goldPrimary,
    _ => AppTheme.textMuted,
  };
}
