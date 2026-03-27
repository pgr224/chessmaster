import 'dart:convert';
import 'package:flutter/material.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:share_plus/share_plus.dart';
import 'package:image_picker/image_picker.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../../../data/models/achievement_model.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/game_record_model.dart';
import '../../../data/repositories/auth_repository.dart';
import 'package:image_cropper/image_cropper.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';

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
                _buildStats(context, user),
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
                buildAvatarCircle(user, 56, isCartoon: user.isGhibli)
                  .animate().scale(duration: 600.ms, curve: Curves.easeOutBack),
                GestureDetector(
                  onTap: () => context.push('/settings'),
                  child: Container(
                    padding: const EdgeInsets.all(8),
                    decoration: BoxDecoration(
                      color: AppTheme.goldPrimary,
                      shape: BoxShape.circle,
                      boxShadow: [BoxShadow(color: Colors.black26, blurRadius: 4)],
                    ),
                    child: const Icon(Icons.settings_rounded, size: 20, color: AppTheme.midnight),
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

  Widget _buildStats(BuildContext context, UserModel user) {
    return SliverToBoxAdapter(
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 8),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.spaceAround,
              children: [
                _statCard('🎮 GAMES', '${user.stats.gamesPlayed}', AppTheme.goldPrimary),
                GestureDetector(
                  onTap: () => _showDetailedStats(context, user),
                  child: _statCard('🏆 WIN %', '${user.stats.winRate.toStringAsFixed(0)}%', AppTheme.accentCyan),
                ),
                _statCard('🏅 RANK', '#42', AppTheme.accentPurple), // Placeholder for real rank
              ],
            ),
          ),
          const SizedBox(height: 20),
          _buildXPBar(user),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }

  Widget _buildXPBar(UserModel user) {
    // Basic level calculation: level = sqrt(xp/100) or similar
    final level = (user.xp / 500).floor() + 1;
    final currentLevelXP = (level - 1) * 500;
    final nextLevelXP = level * 500;
    final progress = (user.xp - currentLevelXP) / 500;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Level $level', style: GoogleFonts.fredoka(color: AppTheme.goldPrimary, fontSize: 16, fontWeight: FontWeight.w700)),
              Text('${user.xp} / $nextLevelXP XP', style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
          const SizedBox(height: 8),
          LinearPercentIndicator(
            lineHeight: 12,
            percent: progress.clamp(0.0, 1.0),
            backgroundColor: AppTheme.goldPrimary.withValues(alpha: 0.1),
            progressColor: AppTheme.goldPrimary,
            barRadius: const Radius.circular(10),
            animation: true,
            animationDuration: 1000,
            padding: EdgeInsets.zero,
          ),
        ],
      ),
    );
  }

  void _showDetailedStats(BuildContext context, UserModel user) {
    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.midnight,
      shape: const RoundedRectangleBorder(borderRadius: BorderRadius.vertical(top: Radius.circular(32))),
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(32),
        decoration: const BoxDecoration(
          gradient: AppTheme.backgroundGradient,
          borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: [
                Text('📊 Performance', style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                IconButton(onPressed: () => Navigator.pop(ctx), icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted)),
              ],
            ),
            const SizedBox(height: 24),
            _detailedStatRow('🤖 Solo vs AI', user.stats.aiWinRate, user.stats.aiGames, AppTheme.accentCyan),
            _detailedStatRow('🌍 Online Multiplayer', user.stats.mpWinRate, user.stats.multiplayerGames, AppTheme.goldPrimary),
            _detailedStatRow('👥 Local Two Player', user.stats.twoPlayerWinRate, user.stats.twoPlayerGames, AppTheme.skyBlue),
            _detailedStatRow('🏆 Tournaments', user.stats.tournamentWins.toDouble(), 0, AppTheme.accentPurple, isCount: true),
            const SizedBox(height: 16),
            const Divider(color: Colors.white10),
            const SizedBox(height: 16),
            Text('Overall win rate: ${user.stats.winRate.toStringAsFixed(1)}%', style: GoogleFonts.baloo2(color: AppTheme.textSecondary)),
            const SizedBox(height: 12),
          ],
        ),
      ),
    );
  }

  Widget _detailedStatRow(String label, double rate, int games, Color color, {bool isCount = false}) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
              Text(isCount ? '${rate.toInt()}' : '${rate.toStringAsFixed(0)}%', style: GoogleFonts.fredoka(color: color, fontSize: 18, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          ClipRRect(
            borderRadius: BorderRadius.circular(10),
            child: LinearProgressIndicator(
              value: isCount ? 1.0 : rate / 100,
              minHeight: 8,
              backgroundColor: color.withValues(alpha: 0.1),
              valueColor: AlwaysStoppedAnimation<Color>(color),
            ),
          ),
          if (!isCount)
            Align(
              alignment: Alignment.centerRight,
              child: Padding(
                padding: const EdgeInsets.only(top: 4),
                child: Text('$games games', style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 11)),
              ),
            ),
        ],
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
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Container(
          padding: const EdgeInsets.all(22),
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text('📊 Win Performance', style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700,
              )),
              const SizedBox(height: 20),
              _modeStatBar('🤖 VS Artificial Intelligence', user.stats.aiWinRate, user.stats.aiGames, AppTheme.accentCyan),
              _modeStatBar('🌍 Online Multiplayer', user.stats.mpWinRate, user.stats.multiplayerGames, AppTheme.goldPrimary),
              _modeStatBar('👥 Local Two Player', user.stats.twoPlayerWinRate, user.stats.twoPlayerGames, AppTheme.skyBlue),
            ],
          ),
        ).animate().fadeIn(delay: 200.ms),
      ),
    );
  }

  Widget _modeStatBar(String label, double rate, int games, Color color) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 18),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text(label, style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600)),
              Text('${rate.toStringAsFixed(0)}%', style: GoogleFonts.fredoka(color: color, fontSize: 16, fontWeight: FontWeight.w700)),
            ],
          ),
          const SizedBox(height: 8),
          LinearPercentIndicator(
            lineHeight: 10,
            percent: (rate / 100).clamp(0.0, 1.0),
            backgroundColor: color.withValues(alpha: 0.1),
            progressColor: color,
            barRadius: const Radius.circular(10),
            animation: true,
            animationDuration: 1200,
            padding: EdgeInsets.zero,
            trailing: Padding(
              padding: const EdgeInsets.only(left: 8),
              child: Text('$games', style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 11)),
            ),
          ),
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

  static Widget buildAvatarCircle(UserModel user, double radius, {String? previewData, bool isCartoon = false}) {
    final hasAvatar = previewData != null || user.localAvatar != null || user.avatarUrl != null;
    
    Widget avatar;
    if (previewData != null) {
      avatar = CircleAvatar(radius: radius, backgroundImage: MemoryImage(base64Decode(previewData)));
    } else if (user.localAvatar != null) {
      avatar = CircleAvatar(radius: radius, backgroundImage: MemoryImage(base64Decode(user.localAvatar!)));
    } else if (user.avatarUrl != null) {
      avatar = CircleAvatar(radius: radius, backgroundImage: NetworkImage(user.avatarUrl!));
    } else {
      avatar = CircleAvatar(
        radius: radius,
        backgroundColor: AppTheme.goldPrimary.withValues(alpha: 0.15),
        child: Text(
          user.username[0].toUpperCase(),
          style: GoogleFonts.fredoka(
            fontSize: radius * 0.8, fontWeight: FontWeight.w700, color: AppTheme.goldPrimary,
          ),
        ),
      );
    }

    if (isCartoon) {
      return ColorFiltered(
        colorFilter: const ColorFilter.matrix([
          1.2, 0.1, 0.1, 0, 10,
          0.1, 1.1, 0.1, 0, 10,
          0.1, 0.1, 1.3, 0, -20,
          0, 0, 0, 1, 0,
        ]), // Vibrant, dreamy matrix
        child: ColorFiltered(
          colorFilter: const ColorFilter.mode(
            Color(0x22FFD700), // Warm Ghibli sun-kissed glow
            BlendMode.overlay,
          ),
          child: avatar,
        ),
      );
    }
    return avatar;
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

  static void showEditProfileModal(BuildContext context, UserModel user) {
    final nameController = TextEditingController(text: user.username);
    String? localAvatarPreview = user.localAvatar;
    bool isCartoon = user.isGhibli;
    bool checkingName = false;
    bool? nameAvailable;
    String? nameError;

    showModalBottomSheet(
      context: context,
      backgroundColor: AppTheme.midnight,
      isScrollControlled: true,
      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(32)),
      builder: (ctx) => StatefulBuilder(
        builder: (builderContext, setLocalState) {
          Future<void> pickAndCropImage() async {
            try {
              final picker = ImagePicker();
              final XFile? image = await picker.pickImage(source: ImageSource.gallery, imageQuality: 85);
              if (image == null) return;
              
              final croppedFile = await ImageCropper().cropImage(
                sourcePath: image.path,
                aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
                compressFormat: ImageCompressFormat.jpg,
                compressQuality: 90,
                uiSettings: [
                  AndroidUiSettings(
                    toolbarTitle: 'Crop Avatar',
                    toolbarColor: AppTheme.midnight,
                    toolbarWidgetColor: Colors.white,
                    initAspectRatio: CropAspectRatioPreset.square,
                    lockAspectRatio: true,
                  ),
                  IOSUiSettings(
                    title: 'Crop Avatar',
                    aspectRatioLockEnabled: true,
                  ),
                ],
              );

              if (croppedFile != null) {
                final bytes = await croppedFile.readAsBytes();
                setLocalState(() => localAvatarPreview = base64Encode(bytes));
              }
            } catch (e) {
              if (kDebugMode) print('Avatar pick error: $e');
            }
          }

          Future<void> checkNameAvailability(String val) async {
            if (val == user.username) {
              setLocalState(() => nameAvailable = null);
              return;
            }
            if (val.length < 2) {
              setLocalState(() => nameAvailable = false);
              return;
            }
            
            setLocalState(() => checkingName = true);
            try {
              final authRepo = context.read<AuthRepository>();
              final available = await authRepo.checkUsername(val);
              setLocalState(() {
                checkingName = false;
                nameAvailable = available;
              });
            } catch (e) {
              setLocalState(() => checkingName = false);
            }
          }

          return Container(
            padding: EdgeInsets.fromLTRB(28, 28, 28, MediaQuery.of(builderContext).viewInsets.bottom + 40),
            decoration: const BoxDecoration(
              gradient: AppTheme.backgroundGradient,
              borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
                const SizedBox(height: 24),
                Text('👤 Identity Studio', style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700)),
                const SizedBox(height: 32),
                
                // Avatar Preview & Upload
                GestureDetector(
                  onTap: pickAndCropImage,
                  child: Stack(
                    alignment: Alignment.bottomRight,
                    children: [
                      Container(
                        padding: const EdgeInsets.all(4),
                        decoration: BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.rainbowGradient,
                        ),
                        child: buildAvatarCircle(user, 64, previewData: localAvatarPreview, isCartoon: isCartoon),
                      ),
                      Container(
                        padding: const EdgeInsets.all(8),
                        decoration: const BoxDecoration(color: AppTheme.goldPrimary, shape: BoxShape.circle),
                        child: const Icon(Icons.camera_alt_rounded, size: 20, color: AppTheme.midnight),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 20),
                
                // Cartoonify Toggle
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: Colors.white.withValues(alpha: 0.05),
                    borderRadius: BorderRadius.circular(20),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Text('🎨', style: TextStyle(fontSize: 20)),
                      const SizedBox(width: 12),
                      Text('Ghibli Masterpiece', style: GoogleFonts.baloo2(color: AppTheme.textPrimary, fontWeight: FontWeight.w600)),
                      const SizedBox(width: 12),
                      Switch.adaptive(
                        value: isCartoon,
                        activeColor: AppTheme.goldPrimary,
                        onChanged: (v) => setLocalState(() => isCartoon = v),
                      ),
                    ],
                  ),
                ),
                
                const SizedBox(height: 32),
                TextField(
                  controller: nameController,
                  style: GoogleFonts.fredoka(color: AppTheme.textPrimary),
                  onChanged: (val) {
                    // Debounce or just check
                    checkNameAvailability(val);
                  },
                  decoration: InputDecoration(
                    labelText: 'Player Name',
                    labelStyle: GoogleFonts.fredoka(color: AppTheme.textSecondary),
                    hintText: 'Choose your legend...',
                    prefixIcon: const Icon(Icons.stars_rounded, color: AppTheme.goldPrimary),
                    suffixIcon: checkingName 
                        ? const Padding(padding: EdgeInsets.all(12), child: SizedBox(width: 20, height: 20, child: CircularProgressIndicator(strokeWidth: 2, color: AppTheme.goldPrimary)))
                        : (nameAvailable == null ? null : (nameAvailable! ? const Icon(Icons.check_circle, color: Colors.green) : const Icon(Icons.error, color: Colors.red))),
                    helperText: nameAvailable == true ? 'This name is available!' : (nameAvailable == false ? 'Name is taken or too short' : null),
                    helperStyle: TextStyle(color: nameAvailable == true ? Colors.green : Colors.red),
                    filled: true,
                    fillColor: Colors.white.withValues(alpha: 0.03),
                    border: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: BorderSide.none),
                    focusedBorder: OutlineInputBorder(borderRadius: BorderRadius.circular(20), borderSide: const BorderSide(color: AppTheme.goldPrimary, width: 1.5)),
                  ),
                ),
                const SizedBox(height: 32),
                SizedBox(
                  width: double.infinity,
                  height: 60,
                  child: ElevatedButton(
                    onPressed: (nameAvailable == false || checkingName) ? null : () {
                      context.read<AuthBloc>().add(AuthUpdateProfileEvent(
                        username: nameController.text,
                        localAvatar: localAvatarPreview,
                        isGhibli: isCartoon,
                      ));
                      Navigator.pop(ctx);
                    },
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.goldPrimary,
                      foregroundColor: AppTheme.midnight,
                      elevation: 8,
                      shadowColor: AppTheme.goldPrimary.withValues(alpha: 0.4),
                      shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                    ),
                    child: Text('Apply Transformation', style: GoogleFonts.fredoka(fontSize: 18, fontWeight: FontWeight.w700)),
                  ),
                ),
              ],
            ),
          );
        },
      ),
    );
  }

  static Widget userAvatar(UserModel user, double size, {String? previewData, bool isCartoon = false}) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        color: AppTheme.midnight,
        border: Border.all(color: AppTheme.goldPrimary, width: 3),
      ),
      child: ClipOval(
        child: previewData != null
            ? Image.memory(base64Decode(previewData), fit: BoxFit.cover)
            : (user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: user.avatarUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) => Container(color: Colors.white10),
                    errorWidget: (context, url, error) => Container(color: Colors.white10),
                  )
                : Container(
                    color: AppTheme.goldPrimary,
                    child: Center(
                      child: Text(
                        user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
                        style: GoogleFonts.fredoka(fontSize: size * 0.5, fontWeight: FontWeight.w700, color: AppTheme.midnight),
                      ),
                    ),
                  )),
      ),
    );
  }
}
