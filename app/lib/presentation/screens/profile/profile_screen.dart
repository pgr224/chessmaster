import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../data/models/achievement_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/game_record_model.dart';

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
                _buildHeader(context, user),
                _buildStats(user),
                _buildRecentGames(context, user),
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

  Widget _buildHeader(BuildContext context, UserModel user) {
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
                  backgroundImage: user.avatarUrl != null ? NetworkImage(user.avatarUrl!) : null,
                  child: user.avatarUrl == null ? Text(
                    user.username[0].toUpperCase(),
                    style: GoogleFonts.fredoka(
                      fontSize: 48, fontWeight: FontWeight.w700, color: AppTheme.goldPrimary,
                    ),
                  ) : null,
                ).animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                GestureDetector(
                  onTap: () => _showEditProfile(context, user),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.accentCyan,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: const Icon(Icons.settings_suggest_rounded, size: 20, color: AppTheme.midnight),
                  ),
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

  Widget _buildStats(UserModel user) {
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
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
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

  Widget _buildRecentGames(BuildContext context, UserModel user) {
    final games = user.recentGames.take(5).toList();
    if (games.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(20),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('🕒 Recent Games', style: GoogleFonts.fredoka(
                  color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700,
                )),
                if (user.recentGames.length > 5)
                  TextButton(
                    onPressed: () {}, // TODO: Show full history
                    child: Text('View More', style: GoogleFonts.fredoka(color: AppTheme.goldPrimary)),
                  ),
              ],
            ),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(22),
                border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
              ),
              child: ListView.separated(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                itemCount: games.length,
                separatorBuilder: (_, __) => Divider(color: Colors.white.withValues(alpha: 0.05), height: 1),
                itemBuilder: (context, index) => _buildGameTile(games[index]),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildGameTile(GameRecord game) {
    final bool isWin = game.result == 'Won';
    final bool isDraw = game.result == 'Draw';
    final resultColor = isWin ? AppTheme.goldPrimary : (isDraw ? Colors.blueGrey : Colors.redAccent);

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: resultColor.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Text(isWin ? '🏆' : (isDraw ? '🤝' : '💀'), style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('vs ${game.opponent}', style: GoogleFonts.fredoka(
                  color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
                )),
                Text('${game.mode} • ${game.moves} moves', style: GoogleFonts.baloo2(
                  color: AppTheme.textMuted, fontSize: 12,
                )),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(game.result.toUpperCase(), style: GoogleFonts.fredoka(
                color: resultColor, fontSize: 14, fontWeight: FontWeight.w700,
              )),
              Text(game.date, style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildModeStats(UserModel user) {
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

  void _showEditProfile(BuildContext context, UserModel user) {
    final nameController = TextEditingController(text: user.username);
    final avatars = [
      'https://api.dicebear.com/7.x/avataaars/svg?seed=Felix',
      'https://api.dicebear.com/7.x/avataaars/svg?seed=Aneka',
      'https://api.dicebear.com/7.x/avataaars/svg?seed=King',
      'https://api.dicebear.com/7.x/avataaars/svg?seed=Viking',
    ];
    String selectedAvatar = user.avatarUrl ?? avatars[0];

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.midnight,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(28))),
      builder: (ctx) => StatefulBuilder(
        builder: (context, setLocalState) => Padding(
          padding: EdgeInsets.fromLTRB(24, 24, 24, MediaQuery.of(context).viewInsets.bottom + 40),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Text('⚙️ Profile Settings', style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
              const SizedBox(height: 24),
              SingleChildScrollView(
                scrollDirection: Axis.horizontal,
                child: Row(
                  children: avatars.map((url) {
                    final isSel = selectedAvatar == url;
                    return GestureDetector(
                      onTap: () => setLocalState(() => selectedAvatar = url),
                      child: Container(
                        margin: const EdgeInsets.only(right: 12),
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          border: Border.all(color: isSel ? AppTheme.goldPrimary : Colors.transparent, width: 3),
                        ),
                        child: CircleAvatar(radius: 32, backgroundImage: NetworkImage(url)),
                      ),
                    );
                  }).toList(),
                ).animate().slideX(begin: 0.1),
              ),
              const SizedBox(height: 24),
              TextField(
                controller: nameController,
                style: GoogleFonts.fredoka(color: AppTheme.textPrimary),
                decoration: InputDecoration(
                  labelText: 'Username',
                  labelStyle: GoogleFonts.fredoka(color: AppTheme.textSecondary),
                  enabledBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: Colors.white10)),
                  focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(16), borderSide: BorderSide(color: AppTheme.goldPrimary)),
                  prefixIcon: const Icon(Icons.person_pin_rounded, color: AppTheme.goldPrimary),
                ),
              ),
              const SizedBox(height: 32),
              SizedBox(
                width: double.infinity,
                height: 56,
                child: ElevatedButton(
                  onPressed: () {
                    ctx.read<AuthBloc>().add(AuthUpdateProfileEvent(
                      username: nameController.text,
                      avatarPath: selectedAvatar,
                    ));
                    Navigator.pop(ctx);
                  },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.goldPrimary,
                    foregroundColor: AppTheme.midnight,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                  ),
                  child: Text('Save Changes', style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w600)),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
