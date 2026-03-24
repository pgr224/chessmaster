import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
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
                  radius: 50,
                  backgroundColor: AppTheme.goldPrimary.withOpacity(0.1),
                  child: Text(
                    user.username[0].toUpperCase(),
                    style: const TextStyle(fontSize: 40, fontWeight: FontWeight.bold, color: AppTheme.goldPrimary),
                  ),
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                Container(
                  padding: const EdgeInsets.all(4),
                  decoration: const BoxDecoration(color: AppTheme.accentCyan, shape: BoxShape.circle),
                  child: const Icon(Icons.edit_rounded, size: 16, color: AppTheme.midnight),
                ),
              ],
            ),
            const SizedBox(height: 16),
            Text(
              user.username,
              style: const TextStyle(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.bold),
            ).animate().fadeIn(delay: 200.ms),
            Text(
              'Rank: Master of strategy',
              style: TextStyle(color: AppTheme.goldPrimary.withOpacity(0.8), fontSize: 14, fontWeight: FontWeight.w600),
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
            _statCard('ELO', '1540', Icons.trending_up_rounded, AppTheme.accentCyan),
            _statCard('GAMES', '124', Icons.grid_view_rounded, AppTheme.goldPrimary),
            _statCard('WIN RATE', '64%', Icons.emoji_events_rounded, AppTheme.accentGreen),
          ],
        ),
      ),
    );
  }

  Widget _statCard(String label, String value, IconData icon, Color color) {
    return Container(
      width: 100,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: color.withOpacity(0.1)),
      ),
      child: Column(
        children: [
          Icon(icon, color: color, size: 20),
          const SizedBox(height: 8),
          Text(value, style: const TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold)),
          Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 10, letterSpacing: 0.8)),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9,0.9));
  }

  Widget _buildAchievementsHeader() {
    return const SliverPadding(
      padding: EdgeInsets.fromLTRB(24, 40, 24, 16),
      sliver: SliverToBoxAdapter(
        child: Text(
          'Achievements',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.bold),
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
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: a.isUnlocked ? AppTheme.navyCard : AppTheme.surface.withOpacity(0.4),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: a.isUnlocked ? AppTheme.goldPrimary.withOpacity(0.3) : Colors.transparent,
          width: 1.5,
        ),
      ),
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Container(
            padding: const EdgeInsets.all(12),
            decoration: BoxDecoration(
              color: a.isUnlocked ? AppTheme.goldPrimary.withOpacity(0.1) : Colors.black12,
              shape: BoxShape.circle,
            ),
            child: Text(
              a.icon,
              style: TextStyle(fontSize: 28, color: a.isUnlocked ? null : Colors.grey),
            ),
          ),
          const SizedBox(height: 12),
          Text(
            a.title,
            style: TextStyle(
              color: a.isUnlocked ? AppTheme.textPrimary : AppTheme.textMuted,
              fontWeight: FontWeight.bold,
              fontSize: 14,
            ),
            textAlign: TextAlign.center,
          ),
          const SizedBox(height: 4),
          Text(
            a.description,
            style: TextStyle(color: AppTheme.textSecondary, fontSize: 10),
            textAlign: TextAlign.center,
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          if (a.isUnlocked) ...[
            const Spacer(),
             const Text('UNLOCKED', style: TextStyle(color: AppTheme.goldPrimary, fontSize: 10, fontWeight: FontWeight.w800, letterSpacing: 1)),
          ],
        ],
      ),
    ).animate().fadeIn(delay: (index * 100).ms).slideY(begin: 0.1);
  }
}
