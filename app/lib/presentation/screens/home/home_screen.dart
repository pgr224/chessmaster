import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/di/injection_container.dart' as di;
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../presentation/blocs/auth/auth_bloc.dart';
import '../../../presentation/blocs/settings/settings_bloc.dart';
import '../../../data/models/game_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/repositories/game_repository.dart';
import '../../../data/repositories/puzzle_repository.dart';

class HomeScreen extends StatefulWidget {
  const HomeScreen({super.key});

  @override
  State<HomeScreen> createState() => _HomeScreenState();
}

class _HomeScreenState extends State<HomeScreen> {
  final GameRepository _gameRepository = di.sl<GameRepository>();
  final PuzzleRepository _puzzleRepository = di.sl<PuzzleRepository>();
  Future<List<GameModel>>? _recentGamesFuture;
  String? _recentForUser;

  @override
  Widget build(BuildContext context) {
    final bgTheme = context.watch<SettingsBloc>().state.backgroundTheme;
    return BlocBuilder<AuthBloc, AuthState>(
      builder: (context, authState) {
        final user = authState is AuthAuthenticatedState ? authState.user : null;
        if (user != null && _recentForUser != user.id) {
          _recentForUser = user.id;
          _recentGamesFuture = _gameRepository.getRecentGames(user.id, limit: 8);
        }
        return Scaffold(
          backgroundColor: Colors.transparent,
          body: Container(
            decoration: BoxDecoration(gradient: AppTheme.getBackground(bgTheme)),
            child: SafeArea(
              child: CustomScrollView(
                physics: const BouncingScrollPhysics(),
                slivers: [
                  SliverToBoxAdapter(child: _buildHeader(user)),
                  SliverToBoxAdapter(child: _buildQuickStats(user)),
                  SliverToBoxAdapter(child: _buildSectionTitle('🎮 Game Modes')),
                  SliverPadding(
                    padding: const EdgeInsets.symmetric(horizontal: 16),
                    sliver: SliverList(
                      delegate: SliverChildListDelegate([
                        _buildModeCard(
                          emoji: '🤖',
                          title: 'Play vs AI',
                          subtitle: 'Challenge the computer!',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF74B9FF), Color(0xFFA29BFE)],
                          ),
                          shadowColor: const Color(0xFF74B9FF),
                          onTap: () => context.push('/game/setup', extra: GameMode.singlePlayer),
                          delay: 0,
                        ),
                        _buildModeCard(
                          emoji: '👫',
                          title: 'Two Players',
                          subtitle: 'Play with a friend!',
                          gradient: const LinearGradient(
                            colors: [Color(0xFF6BCB77), Color(0xFF4ECDC4)],
                          ),
                          shadowColor: const Color(0xFF6BCB77),
                          onTap: () => context.go('/game/play', extra: const GameConfig(mode: GameMode.twoPlayer)),
                          delay: 80,
                        ),
                        _buildModeCard(
                          emoji: '🌍',
                          title: 'Online Battle',
                          subtitle: 'Play with the world!',
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFF6B9D), Color(0xFFA29BFE)],
                          ),
                          shadowColor: const Color(0xFFFF6B9D),
                          onTap: () => context.push('/lobby'),
                          delay: 160,
                        ),
                        _buildModeCard(
                          emoji: '📰',
                          title: 'Chess World',
                          subtitle: 'News, events, and career tips!',
                          gradient: LinearGradient(
                            colors: [const Color(0xFFFFD93D), const Color(0xFFFF8A5C)],
                          ),
                          shadowColor: const Color(0xFFFFD93D),
                          onTap: () => context.push('/chess_world'),
                          delay: 240,
                        ),
                        _buildModeCard(
                          emoji: '📚',
                          title: 'Learn Chess',
                          subtitle: 'Become a master!',
                          gradient: const LinearGradient(
                            colors: [Color(0xFFFFB347), Color(0xFFFF8A5C)],
                          ),
                          shadowColor: const Color(0xFFFF8A5C),
                          onTap: () => context.push('/tutorial'),
                          delay: 320,
                        ),
                      ]),
                    ),
                  ),
                  SliverToBoxAdapter(child: _buildSectionTitle('🧩 Daily Puzzle')),
                  SliverToBoxAdapter(child: _buildDailyPuzzle()),
                  SliverToBoxAdapter(child: _buildSectionTitle('🕹️ Recent Games')),
                  SliverToBoxAdapter(child: _buildRecentGames(user)),
                  const SliverToBoxAdapter(child: SizedBox(height: 32)),
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
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 8),
      child: Row(
        children: [
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  _greeting(),
                  style: GoogleFonts.baloo2(
                    color: AppTheme.textSecondary,
                    fontSize: 16,
                    fontWeight: FontWeight.w500,
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  user?.username ?? 'Player',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.textPrimary,
                    fontSize: 28,
                    fontWeight: FontWeight.w700,
                  ),
                ).animate().fadeIn(duration: 400.ms).slideX(begin: -0.1),
              ],
            ),
          ),
          // Avatar — big and colorful
          GestureDetector(
            onTap: () => context.push('/profile'),
            child: Container(
              width: 60,
              height: 60,
              decoration: BoxDecoration(
                shape: BoxShape.circle,
                gradient: AppTheme.rainbowGradient,
                boxShadow: [
                  BoxShadow(
                    color: AppTheme.goldPrimary.withValues(alpha: 0.4),
                    blurRadius: 16,
                    spreadRadius: 2,
                  ),
                ],
              ),
              child: user?.avatarUrl != null
                  ? ClipOval(child: Image.network(user!.avatarUrl!, fit: BoxFit.cover))
                  : const Icon(Icons.person_rounded, color: AppTheme.midnight, size: 32),
            ),
          ).animate().scale(duration: 500.ms, curve: Curves.elasticOut),
        ],
      ),
    );
  }

  Widget _buildQuickStats(UserModel? user) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.25)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem('${user?.stats.gamesPlayed ?? 0}', '🎮 Games', null),
          _divider(),
          _statItem('${user?.stats.wins ?? 0}', '🏆 Wins', AppTheme.goldPrimary),
          _divider(),
          _statItem(
            '${user?.stats.winRate.toStringAsFixed(0) ?? 0}%',
            '📈 Rate', AppTheme.accentCyan,
          ),
          _divider(),
          _statItem('${user?.xp ?? 0}', '🔥 XP', AppTheme.skyBlue),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1);
  }

  Widget _statItem(String value, String label, Color? color) {
    return Column(
      children: [
        Text(value, style: GoogleFonts.fredoka(
          color: color ?? AppTheme.textPrimary,
          fontSize: 22, fontWeight: FontWeight.w700,
        )),
        const SizedBox(height: 4),
        Text(label, style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 13)),
      ],
    );
  }

  Widget _divider() => Container(
    width: 1, height: 44,
    decoration: BoxDecoration(
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Colors.transparent, AppTheme.textMuted.withValues(alpha: 0.3), Colors.transparent],
      ),
    ),
  );

  Widget _buildSectionTitle(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 24, 20, 14),
      child: Row(
        children: [
          Container(
            width: 5, height: 24,
            decoration: BoxDecoration(
              gradient: AppTheme.rainbowGradient,
              borderRadius: BorderRadius.circular(3),
            ),
          ),
          const SizedBox(width: 12),
          Text(title, style: GoogleFonts.fredoka(
            color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }

  Widget _buildModeCard({
    required String emoji,
    required String title,
    required String subtitle,
    required LinearGradient gradient,
    required Color shadowColor,
    required VoidCallback onTap,
    int delay = 0,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        margin: const EdgeInsets.only(bottom: 14),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
          boxShadow: [
            BoxShadow(
              color: shadowColor.withValues(alpha: 0.15),
              blurRadius: 20,
              offset: const Offset(0, 6),
            ),
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.2),
              blurRadius: 12,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: onTap,
            borderRadius: BorderRadius.circular(24),
            splashColor: shadowColor.withValues(alpha: 0.1),
            child: Padding(
              padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 18),
              child: Row(
                children: [
                  // Big gradient emoji container
                  Container(
                    width: 64,
                    height: 64,
                    decoration: BoxDecoration(
                      gradient: gradient,
                      borderRadius: BorderRadius.circular(20),
                      boxShadow: [
                        BoxShadow(
                          color: shadowColor.withValues(alpha: 0.3),
                          blurRadius: 12,
                          offset: const Offset(0, 4),
                        ),
                      ],
                    ),
                    child: Center(
                      child: Text(emoji, style: const TextStyle(fontSize: 34)),
                    ),
                  ),
                  const SizedBox(width: 18),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(title, style: GoogleFonts.fredoka(
                          color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600,
                        )),
                        const SizedBox(height: 3),
                        Text(subtitle, style: GoogleFonts.baloo2(
                          color: AppTheme.textSecondary, fontSize: 15,
                        )),
                      ],
                    ),
                  ),
                  Container(
                    width: 36, height: 36,
                    decoration: BoxDecoration(
                      color: shadowColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Icon(Icons.arrow_forward_ios_rounded,
                        color: shadowColor, size: 16),
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
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          begin: Alignment.topLeft,
          end: Alignment.bottomRight,
          colors: [Color(0xFF2D1B69), Color(0xFF1A1A40)],
        ),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.lavender.withValues(alpha: 0.4)),
        boxShadow: [
          BoxShadow(color: AppTheme.lavender.withValues(alpha: 0.15), blurRadius: 20),
        ],
      ),
      child: Row(
        children: [
          const Text('🧩', style: TextStyle(fontSize: 48)),
          const SizedBox(width: 18),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('DAILY PUZZLE', style: GoogleFonts.fredoka(
                  color: AppTheme.lavender, fontSize: 13, fontWeight: FontWeight.w600,
                  letterSpacing: 1.5,
                )),
                Text('White to move and win!', style: GoogleFonts.fredoka(
                  color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600,
                )),
                const SizedBox(height: 4),
                Text('Difficulty: ⭐⭐⭐', style: GoogleFonts.baloo2(
                  color: AppTheme.textSecondary, fontSize: 14,
                )),
              ],
            ),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.lavender,
              foregroundColor: Colors.white,
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () async {
              final puzzle = await _puzzleRepository.getDailyPuzzle();
              if (mounted) {
                context.go('/game/play', extra: GameConfig(
                  mode: GameMode.puzzle,
                  puzzle: puzzle,
                  playerColor: 'white',
                ));
              }
            },
            child: Text('Solve!', style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16)),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1);
  }

  Widget _buildRecentGames(UserModel? user) {
    if (user == null) {
      return _emptyRecentGames('Sign in to see recent matches.');
    }

    final future = _recentGamesFuture ?? _gameRepository.getRecentGames(user.id, limit: 8);
    _recentGamesFuture = future;

    return FutureBuilder<List<GameModel>>(
      future: future,
      builder: (context, snapshot) {
        if (snapshot.connectionState == ConnectionState.waiting) {
          return Container(
            height: 110,
            margin: const EdgeInsets.symmetric(horizontal: 16),
            decoration: BoxDecoration(
              color: AppTheme.navyCard.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(24),
              border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
            ),
            child: const Center(child: CircularProgressIndicator(strokeWidth: 2)),
          );
        }

        final games = snapshot.data ?? const <GameModel>[];
        if (games.isEmpty) {
          return _emptyRecentGames('No recent games. Start playing!');
        }

        return Container(
          height: 152,
          margin: const EdgeInsets.symmetric(horizontal: 16),
          decoration: BoxDecoration(
            color: AppTheme.navyCard.withValues(alpha: 0.5),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: ListView.separated(
            padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            itemCount: games.length.clamp(0, 4),
            separatorBuilder: (_, __) => const Divider(color: Colors.white10, height: 8),
            itemBuilder: (context, index) {
              final g = games[index];
              final outcome = _outcomeLabel(g, user.id);
              final cause = _causeLabel(g.termination);
              return Row(
                children: [
                  Text(outcome.$1, style: const TextStyle(fontSize: 18)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          '${g.mode} • ${outcome.$2}',
                          style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 13, fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        Text(
                          'Cause: $cause',
                          style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 12),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                ],
              );
            },
          ),
        );
      },
    );
  }

  Widget _emptyRecentGames(String message) {
    return Container(
      height: 110,
      margin: const EdgeInsets.symmetric(horizontal: 16),
      decoration: BoxDecoration(
        color: AppTheme.navyCard.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
      ),
      child: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            const Text('🕹️', style: TextStyle(fontSize: 32)),
            const SizedBox(height: 8),
            Text(
              message,
              style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 16),
            ),
          ],
        ),
      ),
    );
  }

  (String, String) _outcomeLabel(GameModel game, String userId) {
    if (game.status == 'abandoned') return ('⚠️', 'Abandoned');
    if (game.result == 'draw') return ('🤝', 'Draw');
    final isWhite = game.whiteUserId == userId;
    final win = game.result == 'white' ? isWhite : !isWhite;
    return win ? ('🏆', 'Win') : ('💥', 'Loss');
  }

  String _causeLabel(String? cause) {
    switch (cause) {
      case 'resignation_user_quit':
        return 'Opponent resigned';
      case 'agreement':
        return 'Draw agreement';
      case 'network_disconnect_or_app_crash':
      case 'network_disconnect':
        return 'Network disconnect/app crash';
      case null:
      case '':
        return 'Normal completion';
      default:
        return cause.replaceAll('_', ' ');
    }
  }

  String _greeting() {
    final hour = DateTime.now().hour;
    if (hour < 12) return 'Good morning ☀️';
    if (hour < 17) return 'Good afternoon 🌤️';
    return 'Good evening 🌙';
  }
}
