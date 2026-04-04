import 'dart:convert';
import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:percent_indicator/percent_indicator.dart';
import 'package:go_router/go_router.dart';
import 'package:cached_network_image/cached_network_image.dart';
import 'package:image_picker/image_picker.dart';
import 'package:image_cropper/image_cropper.dart';

import '../../../core/theme/app_theme.dart';
import 'package:chess_master/presentation/blocs/auth/auth_bloc.dart';
import '../../../data/models/user_model.dart';
import '../../../data/models/game_record_model.dart';
import '../../../data/repositories/auth_repository.dart';

class ProfileScreen extends StatelessWidget {
  const ProfileScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: BlocConsumer<AuthBloc, AuthState>(
        listener: (context, state) {
          if (state is AuthErrorState) {
            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(state.message),
                backgroundColor: AppTheme.accentRed,
                behavior: SnackBarBehavior.floating,
              ),
            );
          }
        },
        builder: (context, state) {
          if (state is AuthLoadingState || state is AuthInitialState) {
            return const Center(
              child: CircularProgressIndicator(color: AppTheme.goldPrimary),
            );
          }

          if (state is AuthAuthenticatedState) {
            return _ProfileContent(user: state.user);
          }

          // fallback for unauthenticated or persistent error
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Text('👤', style: TextStyle(fontSize: 64)),
                const SizedBox(height: 16),
                Text('Join the Chess Arena',
                    style: GoogleFonts.fredoka(
                        color: AppTheme.textPrimary, fontSize: 18)),
                const SizedBox(height: 24),
                ElevatedButton(
                  onPressed: () => context.go('/onboarding'),
                  style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.goldPrimary),
                  child: const Text('Get Started',
                      style: TextStyle(color: Colors.black)),
                ),
              ],
            ),
          );
        },
      ),
    );
  }
}

class _ProfileContent extends StatelessWidget {
  final UserModel user;

  const _ProfileContent({required this.user});

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: const BoxDecoration(
        gradient: AppTheme.backgroundGradient,
      ),
      child: CustomScrollView(
        physics: const BouncingScrollPhysics(),
        slivers: [
          _buildSliverAppBar(context),
          _buildProfileHeader(),
          _buildActionButtons(context),
          _buildXPProgress(),
          _buildStatsGrid(),
          _buildRulesSection(),
          _buildRecentGamesSection(),
          const SliverPadding(padding: EdgeInsets.only(bottom: 60)),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      backgroundColor: Colors.transparent,
      elevation: 0,
      leading: IconButton(
        onPressed: () => context.pop(),
        icon: const Icon(Icons.arrow_back_ios_new_rounded,
            color: AppTheme.textPrimary),
      ),
      actions: [
        IconButton(
          onPressed: () => context.push('/settings'),
          icon: const Icon(Icons.tune_rounded, color: AppTheme.goldPrimary),
        ),
        const SizedBox(width: 8),
      ],
      floating: true,
    );
  }

  Widget _buildProfileHeader() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 20),
        child: Column(
          children: [
            Hero(
              tag: 'user-avatar',
              child: Container(
                padding: const EdgeInsets.all(4),
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: AppTheme.rainbowGradient,
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.goldPrimary.withValues(alpha: 0.3),
                      blurRadius: 20,
                      spreadRadius: 2,
                    )
                  ],
                ),
                child: _UserAvatar(user: user, size: 100),
              ),
            ),
            const SizedBox(height: 16),
            Text(
              user.username.toUpperCase(),
              style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 28,
                fontWeight: FontWeight.w700,
                letterSpacing: 2,
              ),
            ),
            const SizedBox(height: 4),
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.stars_rounded,
                    color: AppTheme.goldPrimary, size: 18),
                const SizedBox(width: 6),
                Text(
                  'GRANDMASTER STRATEGIST',
                  style: GoogleFonts.baloo2(
                    color: AppTheme.goldPrimary.withValues(alpha: 0.8),
                    fontSize: 14,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
          ],
        )
            .animate()
            .fadeIn(duration: 600.ms)
            .slideY(begin: 0.2, curve: Curves.easeOutQuad),
      ),
    );
  }

  Widget _buildActionButtons(BuildContext context) {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 40, vertical: 10),
        child: Row(
          children: [
            Expanded(
              child: _actionBtn(
                label: 'Edit Identity',
                icon: Icons.edit_rounded,
                onTap: () => _showEditProfile(context),
              ),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: _actionBtn(
                label: 'Share Profile',
                icon: Icons.ios_share_rounded,
                onTap: () {}, // TODO: Share functionality
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _actionBtn(
      {required String label,
      required IconData icon,
      required VoidCallback onTap}) {
    return Material(
      color: Colors.transparent,
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Container(
          padding: const EdgeInsets.symmetric(vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.surface.withValues(alpha: 0.3),
            borderRadius: BorderRadius.circular(16),
            border: Border.all(color: Colors.white.withValues(alpha: 0.05)),
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(icon, color: AppTheme.textSecondary, size: 16),
              const SizedBox(width: 8),
              Text(label,
                  style: GoogleFonts.baloo2(
                      color: AppTheme.textPrimary,
                      fontSize: 13,
                      fontWeight: FontWeight.w600)),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildXPProgress() {
    final level = (user.xp / 1000).floor() + 1;
    final currentLevelXP = (level - 1) * 1000;
    final nextLevelXP = level * 1000;
    final progress = (user.xp - currentLevelXP) / 1000;

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 20),
        child: Container(
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.navyCard.withValues(alpha: 0.8),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.1)),
          ),
          child: Column(
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text('Rank Progress',
                          style: GoogleFonts.baloo2(
                              color: AppTheme.textSecondary, fontSize: 14)),
                      Text('LEVEL $level',
                          style: GoogleFonts.fredoka(
                              color: AppTheme.goldPrimary,
                              fontSize: 24,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                    decoration: BoxDecoration(
                      color: AppTheme.goldPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text('${user.xp} XP',
                        style: GoogleFonts.fredoka(
                            color: AppTheme.goldPrimary,
                            fontWeight: FontWeight.w700)),
                  ),
                ],
              ),
              const SizedBox(height: 20),
              LinearPercentIndicator(
                lineHeight: 12,
                percent: progress.clamp(0.0, 1.0),
                backgroundColor: Colors.white.withValues(alpha: 0.05),
                progressColor: AppTheme.goldPrimary,
                barRadius: const Radius.circular(6),
                animation: true,
                padding: EdgeInsets.zero,
              ),
              const SizedBox(height: 10),
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Text('$currentLevelXP XP',
                      style: GoogleFonts.baloo2(
                          color: AppTheme.textMuted, fontSize: 12)),
                  Text('Next: $nextLevelXP XP',
                      style: GoogleFonts.baloo2(
                          color: AppTheme.textMuted, fontSize: 12)),
                ],
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildStatsGrid() {
    return SliverPadding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      sliver: SliverGrid.count(
        crossAxisCount: 2,
        mainAxisSpacing: 16,
        crossAxisSpacing: 16,
        childAspectRatio: 1.6,
        children: [
          _statTile('Wins', '${user.stats.wins}', AppTheme.goldPrimary,
              Icons.emoji_events_rounded),
          _statTile('Losses', '${user.stats.losses}', AppTheme.accentRed,
              Icons.close_rounded),
          _statTile('Win Rate', '${user.stats.winRate.toStringAsFixed(0)}%',
              AppTheme.accentCyan, Icons.insights_rounded),
          _statTile('Matches', '${user.stats.gamesPlayed}', AppTheme.skyBlue,
              Icons.sports_esports_rounded),
        ],
      ),
    );
  }

  Widget _statTile(String label, String value, Color color, IconData icon) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyCard.withValues(alpha: 0.6),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: color.withValues(alpha: 0.1)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
            ),
            child: Icon(icon, color: color, size: 20),
          ),
          const SizedBox(width: 14),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(value,
                  style: GoogleFonts.fredoka(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.bold)),
              Text(label,
                  style: GoogleFonts.baloo2(
                      color: AppTheme.textSecondary, fontSize: 13)),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildRulesSection() {
    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.all(24),
        child: Container(
          padding: const EdgeInsets.all(24),
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.15)),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              _ruleSectionTitle('🎮 VS Computer', Icons.computer_rounded),
              _ruleItem('Easy Win', '+100 XP', AppTheme.goldPrimary),
              _ruleItem('Medium Win', '+250 XP', AppTheme.goldPrimary),
              _ruleItem('Hard Win', '+400 XP', AppTheme.goldPrimary),
              _ruleItem('Impossible Win', '+700 XP', AppTheme.goldPrimary),
              _ruleItem('AI Mode Win', '+1000 XP', AppTheme.goldPrimary),
              _ruleSectionTitle('⚔️ Multiplayer', Icons.language_rounded),
              _ruleItem('Victory', '+100 XP', AppTheme.goldPrimary),
              _ruleItem('Defeat', '-20 XP', AppTheme.accentRed),
              _ruleSectionTitle(
                  '✨ Milestones & Skills', Icons.auto_awesome_rounded),
              _ruleItem('Mate in 5 (Global)', '+500 XP', AppTheme.accentCyan),
              _ruleItem(
                  'Perfect Game (Global)', '+10,000 XP', AppTheme.accentCyan),
              _ruleItem('Every 100th Win', '+1,000 XP', AppTheme.goldPrimary),
              _ruleSectionTitle('🛠️ Penalties', Icons.warning_amber_rounded),
              _ruleItem('Take Back (Vs AI)', '-25 XP', AppTheme.accentRed),
              _ruleItem('Hint Usage', '-10 XP', AppTheme.accentRed),
              const Padding(
                padding: EdgeInsets.only(top: 20),
                child: Text(
                  '💡 Rules of the Arena:\n'
                  '• 5-Second Rule: Take backs are only allowed within 5s of a move.\n'
                  '• Practice & 2-Player modes award 0 XP but follow the 5s rule.\n'
                  '• Be fair, have fun, and master the board!',
                  style: TextStyle(
                      color: AppTheme.textMuted,
                      fontSize: 12,
                      height: 1.5,
                      fontStyle: FontStyle.italic),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _ruleSectionTitle(String title, IconData icon) {
    return Padding(
      padding: const EdgeInsets.only(top: 16, bottom: 8),
      child: Row(
        children: [
          Icon(icon, size: 14, color: AppTheme.textSecondary.withValues(alpha: 0.5)),
          const SizedBox(width: 8),
          Text(title.toUpperCase(),
              style: GoogleFonts.fredoka(
                  color: AppTheme.textSecondary,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                  letterSpacing: 1.2)),
        ],
      ),
    );
  }

  Widget _ruleItem(String label, String value, Color color) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          Text(label,
              style: GoogleFonts.baloo2(
                  color: AppTheme.textSecondary, fontSize: 15)),
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.05),
              borderRadius: BorderRadius.circular(6),
            ),
            child: Text(value,
                style: GoogleFonts.fredoka(
                    color: color, fontSize: 14, fontWeight: FontWeight.w600)),
          ),
        ],
      ),
    );
  }

  Widget _buildRecentGamesSection() {
    final games = user.recentGames;
    if (games.isEmpty) return const SliverToBoxAdapter(child: SizedBox());

    return SliverToBoxAdapter(
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 16),
              child: Text('Recent Battles',
                  style: GoogleFonts.fredoka(
                      color: AppTheme.textPrimary,
                      fontSize: 20,
                      fontWeight: FontWeight.w700)),
            ),
            ...games.take(5).map((game) => _buildGameTile(game)),
          ],
        ),
      ),
    );
  }

  Widget _buildGameTile(GameRecord game) {
    final isWin = game.result.toLowerCase() == 'won';
    final isDraw = game.result.toLowerCase() == 'draw';
    final color = isWin
        ? AppTheme.goldPrimary
        : (isDraw ? AppTheme.textMuted : AppTheme.accentRed);

    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withValues(alpha: 0.03)),
      ),
      child: Row(
        children: [
          Container(
            padding: const EdgeInsets.all(10),
            decoration: BoxDecoration(
              color: color.withValues(alpha: 0.1),
              shape: BoxShape.circle,
            ),
            child: Text(isWin ? '🏆' : (isDraw ? '🤝' : '💀'),
                style: const TextStyle(fontSize: 18)),
          ),
          const SizedBox(width: 16),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text('vs ${game.opponent}',
                    style: GoogleFonts.fredoka(
                        color: AppTheme.textPrimary,
                        fontSize: 16,
                        fontWeight: FontWeight.w600)),
                Text('${game.mode} • ${game.date}',
                    style: GoogleFonts.baloo2(
                        color: AppTheme.textSecondary, fontSize: 12)),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(game.result.toUpperCase(),
                  style: GoogleFonts.fredoka(
                      color: color, fontSize: 13, fontWeight: FontWeight.bold)),
              Text('${game.moves} moves',
                  style: GoogleFonts.baloo2(
                      color: AppTheme.textMuted, fontSize: 11)),
            ],
          ),
        ],
      ),
    );
  }

  void _showEditProfile(BuildContext context) {
    showEditProfileModal(context, user);
  }
}

// Global helper for profile editing
void showEditProfileModal(BuildContext context, UserModel user) {
  final nameController = TextEditingController(text: user.username);
  String? localAvatarPreview = user.localAvatar;
  bool isCartoon = user.isGhibli;
  bool checkingName = false;
  bool? nameAvailable;
  String? suggestedName;

  String buildUsernameSuggestion(String currentUsername) {
    final cleaned = currentUsername
        .trim()
        .replaceAll(RegExp(r'\s+'), '_')
        .replaceAll(RegExp(r'[^a-zA-Z0-9_]'), '');
    final base = cleaned.isEmpty
        ? 'ChessPlayer'
        : cleaned.replaceAll(RegExp(r'\d+$'), '');
    final suffix = 100 + Random().nextInt(900);
    final candidate = '$base$suffix';
    return candidate.length > 30 ? candidate.substring(0, 30) : candidate;
  }

  showModalBottomSheet(
    context: context,
    backgroundColor: Colors.transparent,
    isScrollControlled: true,
    builder: (ctx) => StatefulBuilder(
      builder: (builderContext, setLocalState) {
        return Container(
          padding: EdgeInsets.fromLTRB(
              28, 28, 28, MediaQuery.of(builderContext).viewInsets.bottom + 40),
          decoration: const BoxDecoration(
            gradient: AppTheme.backgroundGradient,
            borderRadius: BorderRadius.vertical(top: Radius.circular(32)),
            boxShadow: [BoxShadow(color: Colors.black54, blurRadius: 40)],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              Container(
                  width: 40,
                  height: 4,
                  decoration: BoxDecoration(
                      color: Colors.white24,
                      borderRadius: BorderRadius.circular(2))),
              const SizedBox(height: 24),
              Text('👤 IDENTITY STUDIO',
                  style: GoogleFonts.fredoka(
                      color: AppTheme.textPrimary,
                      fontWeight: FontWeight.w700,
                      letterSpacing: 1.5)),
              const SizedBox(height: 8),
              if (user.usernameChanges >= 2)
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  decoration: BoxDecoration(
                    color: AppTheme.accentRed.withValues(alpha: 0.1),
                    borderRadius: BorderRadius.circular(12),
                  ),
                  child: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      const Icon(Icons.lock_rounded,
                          color: AppTheme.accentRed, size: 14),
                      const SizedBox(width: 8),
                      Text('RENAME LIMIT REACHED (2/2)',
                          style: GoogleFonts.fredoka(
                              color: AppTheme.accentRed,
                              fontSize: 12,
                              fontWeight: FontWeight.w700)),
                    ],
                  ),
                )
              else
                Text('CHANGES ALLOWED: ${2 - user.usernameChanges} REMAINING',
                    style: GoogleFonts.fredoka(
                        color: AppTheme.goldPrimary.withValues(alpha: 0.7),
                        fontSize: 12,
                        fontWeight: FontWeight.w600)),
              const SizedBox(height: 32),
              GestureDetector(
                onTap: () async {
                  final picker = ImagePicker();
                  final XFile? image = await picker.pickImage(
                      source: ImageSource.gallery, imageQuality: 85);
                  if (image == null) return;

                  final croppedFile = await ImageCropper().cropImage(
                    sourcePath: image.path,
                    aspectRatio: const CropAspectRatio(ratioX: 1, ratioY: 1),
                    compressFormat: ImageCompressFormat.jpg,
                    uiSettings: [
                      AndroidUiSettings(
                          toolbarTitle: 'Crop Avatar',
                          toolbarColor: AppTheme.midnight,
                          toolbarWidgetColor: Colors.white,
                          lockAspectRatio: true),
                      IOSUiSettings(
                          title: 'Crop Avatar', aspectRatioLockEnabled: true),
                    ],
                  );

                  if (croppedFile != null) {
                    final bytes = await croppedFile.readAsBytes();
                    setLocalState(
                        () => localAvatarPreview = base64Encode(bytes));
                  }
                },
                child: Stack(
                  alignment: Alignment.bottomRight,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(4),
                      decoration: const BoxDecoration(
                          shape: BoxShape.circle,
                          gradient: AppTheme.rainbowGradient),
                      child: _UserAvatar(
                          user: user.copyWith(localAvatar: localAvatarPreview),
                          size: 100),
                    ),
                    Container(
                      padding: const EdgeInsets.all(8),
                      decoration: const BoxDecoration(
                          color: AppTheme.goldPrimary, shape: BoxShape.circle),
                      child: const Icon(Icons.camera_alt_rounded,
                          size: 20, color: Colors.black),
                    ),
                  ],
                ),
              ),
              const SizedBox(height: 32),
              TextField(
                controller: nameController,
                enabled: user.usernameChanges < 2,
                style: GoogleFonts.fredoka(
                    color: user.usernameChanges < 2
                        ? AppTheme.textPrimary
                        : AppTheme.textMuted),
                onChanged: (val) async {
                  if (val == user.username) {
                    setLocalState(() {
                      checkingName = false;
                      nameAvailable = null;
                      suggestedName = null;
                    });
                    return;
                  }
                  setLocalState(() {
                    checkingName = true;
                    suggestedName = null;
                  });
                  final available =
                      await context.read<AuthRepository>().checkUsername(val);
                  if (nameController.text == val) {
                    setLocalState(() {
                      checkingName = false;
                      nameAvailable = available;
                      if (!available) {
                        suggestedName = buildUsernameSuggestion(val);
                      }
                    });
                  }
                },
                decoration: InputDecoration(
                  labelText:
                      user.usernameChanges < 2 ? 'PLAYER NAME' : 'NAME LOCKED',
                  labelStyle: GoogleFonts.fredoka(
                      color: user.usernameChanges < 2
                          ? AppTheme.textSecondary
                          : AppTheme.accentRed.withValues(alpha: 0.5),
                      letterSpacing: 1),
                  prefixIcon: const Icon(Icons.stars_rounded,
                      color: AppTheme.goldPrimary),
                  suffixIcon: checkingName
                      ? const Padding(
                          padding: EdgeInsets.all(12),
                          child: SizedBox(
                              width: 20,
                              height: 20,
                              child: CircularProgressIndicator(
                                  strokeWidth: 2, color: AppTheme.goldPrimary)))
                      : (nameAvailable == null
                          ? null
                          : (nameAvailable!
                              ? const Icon(Icons.check_circle,
                                  color: Colors.green)
                              : const Icon(Icons.error, color: Colors.red))),
                  filled: true,
                  fillColor: Colors.white.withValues(alpha: 0.03),
                  border: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: BorderSide.none),
                  focusedBorder: OutlineInputBorder(
                      borderRadius: BorderRadius.circular(20),
                      borderSide: const BorderSide(
                          color: AppTheme.goldPrimary, width: 1.5)),
                ),
              ),
              if (suggestedName != null) ...[
                const SizedBox(height: 8),
                Row(
                  children: [
                    const Icon(Icons.info_outline,
                        color: AppTheme.textMuted, size: 14),
                    const SizedBox(width: 6),
                    Text('Taken. Try ',
                        style: GoogleFonts.baloo2(
                            color: AppTheme.textMuted, fontSize: 13)),
                    GestureDetector(
                      onTap: () {
                        nameController.text = suggestedName!;
                        nameController.selection = TextSelection.fromPosition(
                            TextPosition(offset: suggestedName!.length));
                      },
                      child: Text('"$suggestedName"',
                          style: GoogleFonts.baloo2(
                              color: AppTheme.goldPrimary,
                              fontSize: 13,
                              fontWeight: FontWeight.bold)),
                    ),
                  ],
                ),
              ],
              const SizedBox(height: 32),
              Row(
                children: [
                  const Text('🎨', style: TextStyle(fontSize: 20)),
                  const SizedBox(width: 12),
                  Expanded(
                      child: Text('Ghibli Art Style',
                          style: GoogleFonts.baloo2(
                              color: AppTheme.textPrimary,
                              fontWeight: FontWeight.w600))),
                  Switch.adaptive(
                    value: isCartoon,
                    activeThumbColor: AppTheme.goldPrimary,
                    onChanged: (v) => setLocalState(() => isCartoon = v),
                  ),
                ],
              ),
              const SizedBox(height: 40),
              SizedBox(
                width: double.infinity,
                height: 60,
                child: ElevatedButton(
                  onPressed: (nameAvailable == false || checkingName)
                      ? null
                      : () {
                          context.read<AuthBloc>().add(AuthUpdateProfileEvent(
                                username: nameController.text,
                                localAvatar: localAvatarPreview,
                                isGhibli: isCartoon,
                              ));
                          Navigator.pop(ctx);
                        },
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.goldPrimary,
                    foregroundColor: Colors.black,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(20)),
                    elevation: 8,
                    shadowColor: AppTheme.goldPrimary.withValues(alpha: 0.4),
                  ),
                  child: Text('APPLY CHANGES',
                      style: GoogleFonts.fredoka(
                          fontSize: 18,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.2)),
                ),
              ),
            ],
          ),
        );
      },
    ),
  );
}

class _UserAvatar extends StatelessWidget {
  final UserModel user;
  final double size;

  const _UserAvatar({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: size,
      height: size,
      decoration: const BoxDecoration(
        shape: BoxShape.circle,
        color: Colors.black26,
      ),
      child: ClipOval(
        child: user.localAvatar != null
            ? Image.memory(base64Decode(user.localAvatar!), fit: BoxFit.cover)
            : (user.avatarUrl != null && user.avatarUrl!.isNotEmpty
                ? CachedNetworkImage(
                    imageUrl: user.avatarUrl!,
                    fit: BoxFit.cover,
                    placeholder: (context, url) =>
                        Container(color: Colors.white10),
                    errorWidget: (context, url, error) =>
                        _FallbackAvatar(user: user, size: size),
                  )
                : _FallbackAvatar(user: user, size: size)),
      ),
    );
  }
}

class _FallbackAvatar extends StatelessWidget {
  final UserModel user;
  final double size;

  const _FallbackAvatar({required this.user, required this.size});

  @override
  Widget build(BuildContext context) {
    return Container(
      color: AppTheme.goldPrimary,
      child: Center(
        child: Text(
          user.username.isNotEmpty ? user.username[0].toUpperCase() : 'U',
          style: GoogleFonts.fredoka(
            fontSize: size * 0.45,
            fontWeight: FontWeight.w700,
            color: Colors.black,
          ),
        ),
      ),
    );
  }
}
