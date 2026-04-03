import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import '../../../core/di/injection_container.dart' as di;
import '../../../data/services/achievement_service.dart';
import '../../../core/theme/app_theme.dart';
import '../../../data/models/achievement_model.dart';

class AchievementsScreen extends StatefulWidget {
  const AchievementsScreen({super.key});

  @override
  State<AchievementsScreen> createState() => _AchievementsScreenState();
}

class _AchievementsScreenState extends State<AchievementsScreen> {
  late List<Achievement> _achievements;
  AchievementCategory? _selectedCategory;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _achievements = di.sl<AchievementService>().achievements;
    _loading = false;
  }

  @override
  Widget build(BuildContext context) {
    final displayed = _selectedCategory != null
        ? _achievements.where((a) => a.category == _selectedCategory).toList()
        : _achievements;

    final unlocked = _achievements.where((a) => a.isUnlocked).length;
    final total = _achievements.length;
    final totalPoints = _achievements
        .where((a) => a.isUnlocked)
        .fold(0, (sum, a) => sum + a.points);

    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: _loading
              ? const Center(
                  child: CircularProgressIndicator(color: AppTheme.goldPrimary))
              : CustomScrollView(
                  physics: const BouncingScrollPhysics(),
                  slivers: [
                    // App Bar
                    SliverAppBar(
                      backgroundColor: Colors.transparent,
                      elevation: 0,
                      leading: IconButton(
                        onPressed: () => context.pop(),
                        icon: const Icon(Icons.arrow_back_ios_new_rounded,
                            color: AppTheme.textPrimary),
                      ),
                      title: Text(
                        '🏆 ACHIEVEMENTS',
                        style: GoogleFonts.fredoka(
                          color: AppTheme.goldPrimary,
                          fontSize: 22,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5,
                        ),
                      ),
                      centerTitle: true,
                      floating: true,
                    ),

                    // Progress summary
                    SliverToBoxAdapter(
                      child: Container(
                        margin: const EdgeInsets.symmetric(
                            horizontal: 16, vertical: 8),
                        padding: const EdgeInsets.all(20),
                        decoration: BoxDecoration(
                          gradient: AppTheme.cardGradient,
                          borderRadius: BorderRadius.circular(24),
                          border: Border.all(
                              color: AppTheme.goldPrimary.withOpacity(0.25)),
                          boxShadow: AppTheme.cardShadow,
                        ),
                        child: Column(
                          children: [
                            Row(
                              mainAxisAlignment: MainAxisAlignment.spaceAround,
                              children: [
                                _summaryItem('$unlocked/$total', 'Unlocked',
                                    AppTheme.goldPrimary),
                                _divider(),
                                _summaryItem('$totalPoints', 'Points',
                                    AppTheme.accentCyan),
                                _divider(),
                                _summaryItem(
                                  '${(unlocked / total * 100).toStringAsFixed(0)}%',
                                  'Complete',
                                  AppTheme.skyBlue,
                                ),
                              ],
                            ),
                            const SizedBox(height: 16),
                            // Progress bar
                            ClipRRect(
                              borderRadius: BorderRadius.circular(6),
                              child: LinearProgressIndicator(
                                value: unlocked / total,
                                backgroundColor: Colors.white.withOpacity(0.05),
                                valueColor: const AlwaysStoppedAnimation(
                                    AppTheme.goldPrimary),
                                minHeight: 8,
                              ),
                            ),
                          ],
                        ),
                      ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),
                    ),

                    // Category filters
                    SliverToBoxAdapter(
                      child: SizedBox(
                        height: 46,
                        child: ListView(
                          scrollDirection: Axis.horizontal,
                          padding: const EdgeInsets.symmetric(horizontal: 12),
                          children: [
                            _categoryChip(null, '🏷️ All'),
                            ...AchievementCategory.values.map(
                              (cat) => _categoryChip(cat, categoryName(cat)),
                            ),
                          ],
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 12)),

                    // Achievement grid
                    SliverPadding(
                      padding: const EdgeInsets.symmetric(horizontal: 16),
                      sliver: SliverGrid(
                        gridDelegate:
                            const SliverGridDelegateWithFixedCrossAxisCount(
                          crossAxisCount: 2,
                          mainAxisSpacing: 12,
                          crossAxisSpacing: 12,
                          childAspectRatio: 0.95,
                        ),
                        delegate: SliverChildBuilderDelegate(
                          (context, index) {
                            final achievement = displayed[index];
                            return _AchievementCard(
                              achievement: achievement,
                              delay: index * 50,
                            );
                          },
                          childCount: displayed.length,
                        ),
                      ),
                    ),

                    const SliverToBoxAdapter(child: SizedBox(height: 40)),
                  ],
                ),
        ),
      ),
    );
  }

  Widget _categoryChip(AchievementCategory? category, String label) {
    final isSelected = _selectedCategory == category;
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4),
      child: FilterChip(
        selected: isSelected,
        onSelected: (_) => setState(() => _selectedCategory = category),
        label: Text(
          label,
          style: GoogleFonts.fredoka(
            color: isSelected ? AppTheme.midnight : AppTheme.textSecondary,
            fontSize: 12,
            fontWeight: FontWeight.w600,
          ),
        ),
        backgroundColor: AppTheme.surface.withOpacity(0.5),
        selectedColor: AppTheme.goldPrimary,
        checkmarkColor: AppTheme.midnight,
        side: BorderSide(
          color: isSelected
              ? AppTheme.goldPrimary
              : Colors.white.withOpacity(0.06),
        ),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        padding: const EdgeInsets.symmetric(horizontal: 6, vertical: 2),
      ),
    );
  }

  Widget _summaryItem(String value, String label, Color color) {
    return Column(
      children: [
        Text(value,
            style: GoogleFonts.fredoka(
                color: color, fontSize: 22, fontWeight: FontWeight.w700)),
        const SizedBox(height: 2),
        Text(label,
            style: GoogleFonts.baloo2(
                color: AppTheme.textSecondary, fontSize: 12)),
      ],
    );
  }

  Widget _divider() => Container(
        width: 1,
        height: 40,
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [
              Colors.transparent,
              AppTheme.textMuted.withOpacity(0.3),
              Colors.transparent
            ],
          ),
        ),
      );
}

class _AchievementCard extends StatelessWidget {
  final Achievement achievement;
  final int delay;

  const _AchievementCard({required this.achievement, this.delay = 0});

  @override
  Widget build(BuildContext context) {
    final isUnlocked = achievement.isUnlocked;
    final hasProgress =
        achievement.requiredCount != null && achievement.requiredCount! > 0;

    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        gradient: isUnlocked
            ? LinearGradient(
                begin: Alignment.topLeft,
                end: Alignment.bottomRight,
                colors: [
                  AppTheme.goldPrimary.withOpacity(0.15),
                  AppTheme.navyCard.withOpacity(0.9),
                ],
              )
            : AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(
          color: isUnlocked
              ? AppTheme.goldPrimary.withOpacity(0.4)
              : Colors.white.withOpacity(0.05),
          width: isUnlocked ? 2 : 1,
        ),
        boxShadow: isUnlocked
            ? [
                BoxShadow(
                  color: AppTheme.goldPrimary.withOpacity(0.15),
                  blurRadius: 12,
                  offset: const Offset(0, 4),
                ),
              ]
            : null,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Icon + Points
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: isUnlocked
                      ? AppTheme.goldPrimary.withOpacity(0.15)
                      : AppTheme.surface.withOpacity(0.5),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Center(
                  child: Text(
                    achievement.icon,
                    style: TextStyle(
                      fontSize: 26,
                      color: isUnlocked ? null : Colors.white.withOpacity(0.3),
                    ),
                  ),
                ),
              ),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
                decoration: BoxDecoration(
                  color:
                      (isUnlocked ? AppTheme.goldPrimary : AppTheme.textMuted)
                          .withOpacity(0.1),
                  borderRadius: BorderRadius.circular(8),
                ),
                child: Text(
                  '${achievement.points}pts',
                  style: GoogleFonts.fredoka(
                    color:
                        isUnlocked ? AppTheme.goldPrimary : AppTheme.textMuted,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ),
            ],
          ),
          const Spacer(),
          // Title
          Text(
            achievement.title,
            style: GoogleFonts.fredoka(
              color: isUnlocked ? AppTheme.textPrimary : AppTheme.textSecondary,
              fontSize: 14,
              fontWeight: FontWeight.w700,
            ),
            maxLines: 1,
            overflow: TextOverflow.ellipsis,
          ),
          const SizedBox(height: 3),
          // Description
          Text(
            achievement.description,
            style: GoogleFonts.baloo2(
              color: AppTheme.textMuted,
              fontSize: 11,
              height: 1.2,
            ),
            maxLines: 2,
            overflow: TextOverflow.ellipsis,
          ),
          // Progress bar for progressive achievements
          if (hasProgress && !isUnlocked) ...[
            const SizedBox(height: 8),
            ClipRRect(
              borderRadius: BorderRadius.circular(4),
              child: LinearProgressIndicator(
                value: achievement.progressPercent,
                backgroundColor: Colors.white.withOpacity(0.05),
                valueColor: AlwaysStoppedAnimation(
                  AppTheme.accentCyan.withOpacity(0.7),
                ),
                minHeight: 4,
              ),
            ),
            const SizedBox(height: 3),
            Text(
              '${achievement.currentProgress}/${achievement.requiredCount}',
              style: GoogleFonts.jura(
                  color: AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.bold),
            ),
          ],
          if (isUnlocked) ...[
            const SizedBox(height: 6),
            Row(
              children: [
                const Icon(Icons.check_circle_rounded,
                    color: AppTheme.goldPrimary, size: 14),
                const SizedBox(width: 4),
                Text(
                  'UNLOCKED',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.goldPrimary,
                    fontSize: 10,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
              ],
            ),
          ],
        ],
      ),
    ).animate().fadeIn(delay: delay.ms).slideY(begin: 0.08);
  }
}
