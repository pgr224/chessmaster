import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../data/models/achievement_model.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, state) {
        final user = state is AuthAuthenticatedState ? state.user : null;
        if (user == null) return const Center(child: CircularProgressIndicator());

        return Scaffold(
          backgroundColor: AppTheme.midnight,
          body: Container(
            decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: CustomScrollView(
              slivers: [
                _buildHeader(user),
                _buildStats(user),
                _buildModeStats(user),
                _buildAchievementsHeader(),
                _buildAchievementsGrid(),
              ],
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(dynamic user) {
    return SliverToBoxAdapter(
      child: Container(
        padding: const EdgeInsets.only(top: 80, bottom: 40),
        child: Column(
          children: [
            Stack(
              alignment: Alignment.bottomRight,
              children: [
                CircleAvatar(
                  radius: 56,
                  backgroundColor: AppTheme.goldPrimary.withValues(alpha: 0.15),
                  child: Text(
                    user.username[0].toUpperCase(),
                    style: GoogleFonts.fredoka(
                      fontSize: 48, fontWeight: FontWeight.w700, color: AppTheme.goldPrimary,
                    ),
                  ),
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                Container(
                  padding: const EdgeInsets.all(6),
                  decoration: const BoxDecoration(color: AppTheme.accentCyan, shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, size: 18, color: AppTheme.midnight),
                ),
              ],
            ),
            const SizedBox(height: 18),
            Text(
              user.username,
              style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w700),
            ).animate().fadeIn(delay: 200.ms),
            Text(
              '⭐ Master of Strategy',
              style: GoogleFonts.baloo2(color: AppTheme.goldPrimary.withValues(alpha: 0.9), fontSize: 16, fontWeight: FontWeight.w600),
            ).animate().fadeIn(delay: 300.ms),
          ],
        ),
      ),
    );
  }

  Widget _buildStats(dynamic user) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.spaceAround,
          children: [
            _statCard('🔥 XP', '${user.xp}', AppTheme.skyBlue),
            _statCard('🎮 GAMES', '${user.stats.gamesPlayed}', AppTheme.goldPrimary),
            _statCard('🏆 WIN %', '${user.stats.winRate.toStringAsFixed(0)}%', AppTheme.accentCyan),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, Color color) {
    return Container(
      width: 108,
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(22),
        border: Border.all(color: color.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: color.withValues(alpha: 0.16),
            blurRadius: 16,
            offset: const Offset(0, 6),
          ),
        ],
      ),
      child: Column(
        children: [
          Text(value, style: GoogleFonts.fredoka(color: color, fontSize: 22, fontWeight: FontWeight.w700)),
          const SizedBox(height: 6),
          Text(label, style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 13, fontWeight: FontWeight.w600)),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildModeStats(dynamic user) {
    double _modeWinRate(int wins, int games) => games > 0 ? wins / games * 100 : 0;
    final aiRate = _modeWinRate(user.stats.aiWins, user.stats.aiGames);
    final mpRate = _modeWinRate(user.stats.multiplayerWins, user.stats.multiplayerGames);
    final tGames = user.stats.gamesPlayed - user.stats.aiGames - user.stats.multiplayerGames;
    final tWins = user.stats.tournamentWins;
    final tRate = _modeWinRate(tWins, tGames > 0 ? tGames : 0);

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Container(
          padding: const EdgeInsets.all(18),
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
            borderRadius: BorderRadius.circular(22),
            border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📊 Win Rate by Mode', style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 14),
              Row(
                children: [
                  Expanded(child: _modeStatTile('🤖 AI', aiRate, user.stats.aiGames, AppTheme.accentCyan)),
                  const SizedBox(width: 10),
                  Expanded(child: _modeStatTile('🌍 Online', mpRate, user.stats.multiplayerGames, AppTheme.goldPrimary)),
                  const SizedBox(width: 10),
                  Expanded(child: _modeStatTile('🏆 Tourney', tRate, tGames > 0 ? tGames : 0, AppTheme.accentPurple)),
                ],
              ),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms),
      ),
    );
  }

  Widget _modeStatTile(String label, double rate, int games, Color color) {
    return Container(
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.08),
        borderRadius: BorderRadius.circular(16),
      ),
      child: Column(
        children: [
          Text('${rate.toStringAsFixed(0)}%', style: GoogleFonts.fredoka(
            color: color, fontSize: 22, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 4),
          Text(label, style: GoogleFonts.fredoka(
            color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600,
          )),
          Text('$games games', style: GoogleFonts.baloo2(
            color: AppTheme.textMuted, fontSize: 10,
          )),
        ],
      ),
    );
  }

  Widget _buildAchievementsHeader() {
    return SliverPadding(
      padding: const EdgeInsets.fromLTRB(24, 40, 24, 16),
      sliver: SliverToBoxAdapter(
        child: Text(
          '🏅 Achievements',
          style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
        ),
      ),
    );
  }

  Widget _buildAchievementsGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverGrid(
        gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
          crossAxisCount: 2,
          crossAxisSpacing: 16,
          mainAxisSpacing: 16,
          childAspectRatio: 0.85,
        ),
        delegate: SliverChildBuilderDelegate(
          (context, index) {
            final achievement = sampleAchievements[index];
            return _buildAchievementCard(achievement, index);
          },
          childCount: sampleAchievements.length,
        ),
      ),
    );
  }

  Widget _buildAchievementCard(Achievement a, int index) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        color: a.isUnlocked ? AppTheme.navyCard : AppTheme.surface.withValues(alpha: 0.4),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(
          color: a.isUnlocked ? AppTheme.goldPrimary.withValues(alpha: 0.35) : Colors.transparent,
          width: 2,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: a.isUnlocked ? AppTheme.goldPrimary.withValues(alpha: 0.12) : Colors.black12,
              shape: BoxShape.circle,
            ),
            child: Text(
              a.icon,
              style: TextStyle(fontSize: 32, color: a.isUnlocked ? null : Colors.grey),
            ),
          ),
          const SizedBox(height: 14),
          Text(
            a.title,
            style: GoogleFonts.fredoka(
              color: a.isUnlocked ? AppTheme.textPrimary : AppTheme.textMuted,
              fontWeight: FontWeight.w600, fontSize: 16,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            a.description,
            style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 12),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (a.isUnlocked) ...[
            const Spacer(),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✅ UNLOCKED', style: GoogleFonts.fredoka(
                  color: AppTheme.goldPrimary, fontSize: 11, fontWeight: FontWeight.w600, letterSpacing: 1,
                )),
                const SizedBox(width: 8),
                GestureDetector(
                  onTap: () => _shareAchievement(a),
                  child: Icon(Icons.share_rounded, color: AppTheme.goldPrimary.withValues(alpha: 0.7), size: 18),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1);
  }

  void _shareAchievement(Achievement a) {
    SharePlus.instance.share(ShareParams(
      text: '${a.icon} I just unlocked "${a.title}" in Chess Master!\n'
            '${a.description}\n\n'
            '🔥 Think you can beat me? Download now:\n'
            'https://play.google.com/store/apps/details?id=com.chessmaster.app',
      subject: 'Chess Master Achievement: ${a.title}',
    ));
  }
}
