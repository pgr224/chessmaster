import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../presentation/blocs/auth/auth_bloc.dart';
import '../../../data/models/user_model.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  @override
  Widget build(BuildContext context) {
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticatedState ? authState.user : null;
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(user)),
                  SliverToBoxAdapter(child: _buildQuickStats(user)),
                  SliverToBoxAdapter(child: _buildSectionTitle('Game Modes')),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildModeCard(
                          icon: '🤖',
                          title: 'vs AI',
                          subtitle: 'Challenge the computer',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF1565C0), Color(0xFF7B61FF)],
                          ),
                          onTap: () => context.push('/game/setup', extra: GameMode.singlePlayer),
                          delay: 0,
                        ),
                        _buildModeCard(
                          icon: '👥',
                          title: 'Two Player',
                          subtitle: 'Play locally with a friend',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF2E7D32), Color(0xFF00E676)],
                          ),
                          onTap: () => context.go('/game/play', extra: const GameConfig(mode: GameMode.twoPlayer)),
                          delay: 100,
                        ),
                        _buildModeCard(
                          icon: '🌐',
                          title: 'Online Battle',
                          subtitle: 'Compete with players worldwide',
                          gradient: AppTheme.cyanGradient,
                          onTap: () => context.push('/lobby'),
                          delay: 200,
                        ),
                        _buildModeCard(
                          icon: '🏆',
                          title: 'Tournament',
                          subtitle: 'Enter bracket competition',
                          gradient: LinearGradient(colors: [AppTheme.goldDark, AppTheme.goldPrimary]),
                          onTap: () => context.push('/tournaments'),
                          delay: 300,
                        ),
                        _buildModeCard(
                          icon: '📚',
                          title: 'Tutorial',
                          subtitle: 'Learn chess step by step',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF880E4F), Color(0xFFFF4081)],
                          ),
                          onTap: () => context.push('/tutorial'),
                          delay: 400,
                        ),
                      ]),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildSectionTitle('Daily Puzzle')),
                  SliverToBoxAdapter(child: _buildDailyPuzzle()),
                  SliverToBoxAdapter(child: _buildSectionTitle('Recent Games')),
                  SliverToBoxAdapter(child: _buildRecentGames()),
                  const SliverToBoxAdapter(child: SizedBox(height: 24)),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildHeader(UserModel? user) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 16, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: TextStyle(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.username ?? 'Player',
                  style: const TextStyle(
                    color: AppTheme.textPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
              ],
            ),
          ),
          // Avatar
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              width: 52,
              height: 52,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: const LinearGradient(
                  colors: [AppTheme.goldDark, AppTheme.goldPrimary],
                ),
                boxShadow: AppTheme.goldShadow,
              ),
              child: user?.avatarUrl != null
                  ? ClipOval(child: Image.network(user!.avatarUrl!, fit: BoxFit.cover))
                  : const Icon(Icons.person_rounded, color: AppTheme.midnight, size: 28),
            ),
          ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack),
        ],
      ),
    );
  }

  Widget _buildQuickStats(UserModel? user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.2)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('${user?.stats.gamesPlayed ?? 0}', 'Games', Icons.sports_esports_rounded),
          _divider(),
          _statItem('${user?.stats.wins ?? 0}', 'Wins', Icons.emoji_events_rounded,
              color: AppTheme.goldPrimary),
          _divider(),
          _statItem(
            '${user?.stats.winRate.toStringAsFixed(0) ?? 0}%',
            'Win Rate', Icons.trending_up_rounded,
            color: AppTheme.accentGreen,
          ),
          _divider(),
          _statItem('${user?.rating ?? 1200}', 'Rating', Icons.star_rounded,
              color: AppTheme.accentCyan),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _statItem(String value, String label, IconData icon, {Color? color}) {
    return Column(
      children: [
        Icon(icon, color: color ?? AppTheme.textSecondary, size: 20),
        const SizedBox(height: 4),
        Text(value, style: TextStyle(
          color: color ?? AppTheme.textPrimary,
          fontSize: 20, fontWeight: FontWeight.w800,
        )),
        Text(label, style: const TextStyle(color: AppTheme.textMuted, fontSize: 11)),
      ],
    );
  }

  Widget _divider() => Container(width: 1, height: 40, color: AppTheme.textMuted.withOpacity(0.2));

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 12),
      child: Row(
        children: [
          Container(width: 4, height: 20, decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(2),
          )),
          const SizedBox(width: 10),
          Text(title, style: const TextStyle(
            color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700,
          )),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String icon,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required VoidCallback onTap,
    int delay = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: Colors.white.withOpacity(0.05)),
          boxShadow: AppTheme.cardShadow,
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(18),
            splashColor: Colors.white.withOpacity(0.05),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  // Icon container with gradient
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(16),
                    ),
                    child: Center(
                      child: Text(icon, style: const TextStyle(fontSize: 28)),
                    ),
                  ),
                  const SizedBox(width: 16),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: const TextStyle(
                          color: AppTheme.textPrimary, fontSize: 17, fontWeight: FontWeight.w700,
                        )),
                        const SizedBox(height: 2),
                        Text(subtitle, style: const TextStyle(
                          color: AppTheme.textSecondary, fontSize: 13,
                        )),
                      ],
                    ),
                  ),
                  Container(
                    width: 32, height: 32,
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.06),
                      borderRadius: BorderRadius.circular(10),
                    ),
                    child: const Icon(Icons.arrow_forward_ios_rounded,
                        color: AppTheme.textSecondary, size: 14),
                  ),
                ],
              ),
            ),
          ),
        ),
      ).animate().fadeIn(delay: delay.ms).slideX(begin: 0.05),
    );
  }

  Widget _buildDailyPuzzle() {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF1A1040), Color(0xFF0E1535)],
        ),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentPurple.withOpacity(0.4)),
        boxShadow: [
          BoxShadow(color: AppTheme.accentPurple.withOpacity(0.2), blurRadius: 20),
        ],
      ),
      child: Row(
        children: [
          const Text('🧩', style: TextStyle(fontSize: 40)),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                const Text('Daily Puzzle', style: TextStyle(
                  color: AppTheme.accentPurple, fontSize: 12, fontWeight: FontWeight.w700,
                  letterSpacing: 1.5,
                )),
                const Text('White to move and win!', style: TextStyle(
                  color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 4),
                Text('Difficulty: ★★★☆☆', style: TextStyle(color: AppTheme.textSecondary, fontSize: 13)),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentPurple,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            ),
            onPressed: () {},
            child: const Text('Solve', style: TextStyle(fontWeight: FontWeight.w700)),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildRecentGames() {
    // Placeholder — would be loaded from local DB
    return Container(
      height: 100,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      child: const Center(
        child: Text(
          'No recent games. Start playing!',
          style: TextStyle(color: AppTheme.textMuted, fontSize: 14),
        ),
      ),
    );
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning,';
    if (hour < 17) return 'Good afternoon,';
    return 'Good evening,';
  }
}
