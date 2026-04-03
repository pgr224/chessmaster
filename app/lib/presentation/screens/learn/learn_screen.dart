import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:go_router/go_router.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/tutorial_model.dart';

// ─── Data ────────────────────────────────────────────────────────────────────

class _Category {
  final String emoji;
  final String title;
  final String description;
  final Color color;
  final int lessonCount;
  final String totalTime;
  final String difficulty;
  final String articleId;

  const _Category({
    required this.emoji,
    required this.title,
    required this.description,
    required this.color,
    required this.lessonCount,
    required this.totalTime,
    required this.difficulty,
    required this.articleId,
  });
}

class _Resource {
  final String icon;
  final String name;
  final String description;
  final String url;
  const _Resource(
      {required this.icon,
      required this.name,
      required this.description,
      required this.url});
}

class _WeekPlan {
  final int week;
  final String topic;
  final String goal;
  final String time;
  const _WeekPlan(
      {required this.week,
      required this.topic,
      required this.goal,
      required this.time});
}

// ─── Screen ──────────────────────────────────────────────────────────────────

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  static const _categories = [
    _Category(
      emoji: '🎓',
      title: 'Fundamentals',
      description: 'Piece movement, check & checkmate basics',
      color: AppTheme.goldPrimary,
      lessonCount: 12,
      totalTime: '3 hrs',
      difficulty: 'Beginner',
      articleId: 'fundamentals',
    ),
    _Category(
      emoji: '♟️',
      title: 'Openings',
      description: 'Control the center from move one',
      color: AppTheme.skyBlue,
      lessonCount: 18,
      totalTime: '5 hrs',
      difficulty: 'Intermediate',
      articleId: 'sicilian',
    ),
    _Category(
      emoji: '⚡',
      title: 'Tactics',
      description: 'Forks, pins, skewers & combinations',
      color: AppTheme.accentPurple,
      lessonCount: 24,
      totalTime: '8 hrs',
      difficulty: 'Intermediate',
      articleId: 'tactics',
    ),
    _Category(
      emoji: '⏳',
      title: 'Endgames',
      description: 'Convert advantages into wins',
      color: AppTheme.accentCyan,
      lessonCount: 16,
      totalTime: '6 hrs',
      difficulty: 'Advanced',
      articleId: 'endgames',
    ),
    _Category(
      emoji: '🏆',
      title: 'Strategy',
      description: 'Pawn structure, weak squares & plans',
      color: Color(0xFF6BCB77),
      lessonCount: 20,
      totalTime: '7 hrs',
      difficulty: 'Advanced',
      articleId: 'strategy',
    ),
  ];

  static const _weekPlan = [
    _WeekPlan(
        week: 1,
        topic: 'Piece Values & Movement',
        goal: 'Know every piece\'s power',
        time: '3 hrs'),
    _WeekPlan(
        week: 2,
        topic: 'Basic Checkmates',
        goal: 'Mate with Q+K, R+K',
        time: '3 hrs'),
    _WeekPlan(
        week: 3,
        topic: 'Opening Principles',
        goal: 'Control center, develop pieces',
        time: '2 hrs'),
    _WeekPlan(
        week: 4,
        topic: 'Tactics: Forks & Pins',
        goal: 'Win material systematically',
        time: '4 hrs'),
    _WeekPlan(
        week: 5,
        topic: 'Tactics: Skewers & Discovered Attacks',
        goal: 'Spot 2-move combos',
        time: '4 hrs'),
    _WeekPlan(
        week: 6,
        topic: 'Common Openings',
        goal: 'Learn Sicilian, Italian, Ruy López',
        time: '3 hrs'),
    _WeekPlan(
        week: 7,
        topic: 'Pawn Structure',
        goal: 'Understand weak & passed pawns',
        time: '3 hrs'),
    _WeekPlan(
        week: 8,
        topic: 'Rook Endgames',
        goal: 'Lucena & Philidor positions',
        time: '3 hrs'),
    _WeekPlan(
        week: 9,
        topic: 'King & Pawn Endgames',
        goal: 'Opposition & promotion races',
        time: '2 hrs'),
    _WeekPlan(
        week: 10,
        topic: 'Middlegame Plans',
        goal: 'Build & execute positional plans',
        time: '4 hrs'),
    _WeekPlan(
        week: 11,
        topic: 'Game Analysis',
        goal: 'Review 10 annotated GM games',
        time: '5 hrs'),
    _WeekPlan(
        week: 12,
        topic: 'Full Game Practice',
        goal: 'Apply everything in live games',
        time: '6 hrs'),
  ];

  static const _resources = [
    _Resource(
      icon: '♟',
      name: 'Lichess.org',
      description:
          'Free, open-source chess server with 50 000+ puzzles & lessons',
      url: 'https://lichess.org/learn',
    ),
    _Resource(
      icon: '🌐',
      name: 'Chess.com Learn',
      description: 'Interactive video lessons by top GMs and coaches',
      url: 'https://www.chess.com/learn-chess',
    ),
    _Resource(
      icon: '🏅',
      name: 'FIDE Handbook',
      description: 'Official rules, ratings & arbiters\' regulations',
      url: 'https://handbook.fide.com',
    ),
    _Resource(
      icon: '📖',
      name: 'ChessBase Library',
      description: 'Annotated opening databases & GM repertoires',
      url: 'https://en.chessbase.com',
    ),
    _Resource(
      icon: '🎥',
      name: 'GothamChess (YouTube)',
      description: 'Levy Rozman — beginner to advanced video tutorials',
      url: 'https://www.youtube.com/@GothamChess',
    ),
    _Resource(
      icon: '📚',
      name: 'Chess Tempo',
      description: 'Rated puzzle trainer & opening drills',
      url: 'https://chesstempo.com',
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          '📚 Chess Academy',
          style: GoogleFonts.fredoka(
              color: AppTheme.textPrimary,
              fontSize: 26,
              fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: ListView(
            padding: const EdgeInsets.only(bottom: 32),
            children: [
              _buildFeaturedCard(context),
              _buildSectionHeader('🗂️ Explore Categories'),
              ..._categories.map((c) => _buildCategoryCard(context, c)),
              _buildSectionHeader('⚡ Quick Tactics Quiz'),
              _buildQuickQuiz(context),
              _buildSectionHeader('📅 12-Week Study Plan'),
              _buildTimetable(context),
              _buildSectionHeader('🔗 Reference Resources'),
              _buildResourceGrid(context),
              _buildSectionHeader('📬 Contact & Support'),
              _buildContactSection(context),
              const SizedBox(height: 16),
            ],
          ),
        ),
      ),
    );
  }

  // ── Featured Banner ────────────────────────────────────────────────────────

  Widget _buildFeaturedCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      width: double.infinity,
      height: 200,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A5C), Color(0xFFFFD93D), Color(0xFF6BCB77)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(
              color: AppTheme.goldPrimary.withOpacity(0.35),
              blurRadius: 24,
              offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10,
            bottom: -10,
            child: Icon(Icons.star_rounded,
                size: 120, color: Colors.white.withOpacity(0.15)),
          ),
          Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✨ FEATURED LESSON',
                    style: GoogleFonts.fredoka(
                      color: AppTheme.midnight,
                      fontSize: 12,
                      fontWeight: FontWeight.w600,
                      letterSpacing: 1.2,
                    )),
                const SizedBox(height: 8),
                Text('Master the\nSicilian Defense',
                    style: GoogleFonts.fredoka(
                      color: AppTheme.midnight,
                      fontSize: 28,
                      fontWeight: FontWeight.w700,
                      height: 1.15,
                    )),
                const SizedBox(height: 6),
                Text('45 min · Intermediate · GM-level analysis',
                    style: GoogleFonts.baloo2(
                      color: AppTheme.midnight.withOpacity(0.7),
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    )),
                const Spacer(),
                ElevatedButton(
                  onPressed: () => context.push('/learn/article/sicilian'),
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.midnight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 22, vertical: 12),
                  ),
                  child: Text('Start Now! 🚀',
                      style: GoogleFonts.fredoka(
                          fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  // ── Section Header ─────────────────────────────────────────────────────────

  Widget _buildSectionHeader(String title) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(24, 28, 24, 14),
      child: Text(title,
          style: GoogleFonts.fredoka(
            color: AppTheme.textPrimary,
            fontSize: 22,
            fontWeight: FontWeight.w700,
          )),
    );
  }

  // ── Category Cards ─────────────────────────────────────────────────────────

  Widget _buildCategoryCard(BuildContext context, _Category cat) {
    return GestureDetector(
      onTap: () => context.push('/learn/article/${cat.articleId}'),
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 8),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: cat.color.withOpacity(0.2)),
          boxShadow: [
            BoxShadow(
                color: cat.color.withOpacity(0.1),
                blurRadius: 14,
                offset: const Offset(0, 4))
          ],
        ),
        child: Row(
          children: [
            Container(
              width: 54,
              height: 54,
              decoration: BoxDecoration(
                  color: cat.color.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(16)),
              child: Center(
                  child: Text(cat.emoji, style: const TextStyle(fontSize: 26))),
            ),
            const SizedBox(width: 16),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(cat.title,
                      style: GoogleFonts.fredoka(
                        color: AppTheme.textPrimary,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 3),
                  Text(cat.description,
                      style: GoogleFonts.baloo2(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 10),
                  Row(
                    children: [
                      _chip('${cat.lessonCount} lessons', AppTheme.textMuted),
                      const SizedBox(width: 8),
                      _chip(cat.totalTime, AppTheme.textMuted),
                      const SizedBox(width: 8),
                      _chip(cat.difficulty, cat.color),
                    ],
                  ),
                ],
              ),
            ),
            Icon(Icons.arrow_forward_ios_rounded, color: cat.color, size: 16),
          ],
        ),
      ).animate().fadeIn().slideX(begin: 0.05),
    );
  }

  Widget _chip(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: color.withOpacity(0.12),
        borderRadius: BorderRadius.circular(8),
      ),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 11, fontWeight: FontWeight.w700)),
    );
  }

  // ── Timetable ──────────────────────────────────────────────────────────────

  Widget _buildTimetable(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.15)),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(20),
            child: Row(
              children: [
                const Icon(Icons.calendar_month_rounded,
                    color: AppTheme.goldPrimary, size: 22),
                const SizedBox(width: 10),
                Text('Complete Beginner → Club Player',
                    style: GoogleFonts.baloo2(
                      color: AppTheme.textSecondary,
                      fontSize: 14,
                      fontWeight: FontWeight.w600,
                    )),
              ],
            ),
          ),
          const Divider(color: Colors.white10, height: 1),
          ...List.generate(
              _weekPlan.length,
              (i) => _buildWeekRow(
                  context, _weekPlan[i], i == _weekPlan.length - 1)),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildWeekRow(BuildContext context, _WeekPlan plan, bool isLast) {
    final isEven = plan.week % 2 == 0;
    return GestureDetector(
      onTap: () => context.push('/learn/week/${plan.week}'),
      child: Container(
        decoration: BoxDecoration(
          color: isEven
              ? Colors.white.withOpacity(0.02)
              : Colors.transparent,
          borderRadius: isLast
              ? const BorderRadius.only(
                  bottomLeft: Radius.circular(24),
                  bottomRight: Radius.circular(24),
                )
              : null,
        ),
        padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              width: 34,
              height: 34,
              decoration: BoxDecoration(
                color: AppTheme.goldPrimary.withOpacity(0.15),
                shape: BoxShape.circle,
              ),
              child: Center(
                child: Text('${plan.week}',
                    style: GoogleFonts.fredoka(
                      color: AppTheme.goldPrimary,
                      fontSize: 14,
                      fontWeight: FontWeight.w700,
                    )),
              ),
            ),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(plan.topic,
                      style: GoogleFonts.baloo2(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 2),
                  Text('Goal: ${plan.goal}',
                      style: GoogleFonts.baloo2(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      )),
                ],
              ),
            ),
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.accentCyan.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(plan.time,
                  style: TextStyle(
                    color: AppTheme.accentCyan,
                    fontSize: 11,
                    fontWeight: FontWeight.w700,
                  )),
            ),
            const SizedBox(width: 6),
            const Icon(Icons.chevron_right_rounded,
                color: AppTheme.textMuted, size: 18),
          ],
        ),
      ),
    );
  }

  // ── Quick Tactics Quiz ─────────────────────────────────────────────────────

  Widget _buildQuickQuiz(BuildContext context) {
    const quizItems = [
      ('⚔️ Fork Trap', 'Intermediate', 'intermediate1', AppTheme.goldPrimary),
      ('📌 The Pin', 'Intermediate', 'intermediate2', AppTheme.accentPurple),
      ('💥 Back Rank Mate', 'Intermediate', 'intermediate3', AppTheme.skyBlue),
      ('🎭 The Skewer', 'Intermediate', 'intermediate4', AppTheme.accentCyan),
      (
        '🔄 Discovered Attack',
        'Intermediate',
        'intermediate5',
        Color(0xFF6BCB77)
      ),
      ("🛡️ Scholar's Mate", 'Advanced', 'advanced1', AppTheme.accentRed),
      ('💎 Zwischenzug', 'Advanced', 'advanced5', AppTheme.lavender),
    ];

    return SizedBox(
      height: 140,
      child: ListView.builder(
        padding: const EdgeInsets.symmetric(horizontal: 24),
        scrollDirection: Axis.horizontal,
        itemCount: quizItems.length,
        itemBuilder: (ctx, i) {
          final (title, diff, tutId, color) = quizItems[i];
          return GestureDetector(
            onTap: () {
              final lesson = tutorialLessons.firstWhere(
                (l) => l.id == tutId,
                orElse: () => tutorialLessons.first,
              );
              context.push('/game/play',
                  extra: GameRouteExtra(
                    config: const GameConfig(mode: GameMode.tutorial),
                    tutorial: lesson,
                  ));
            },
            child: Container(
              width: 170,
              margin: const EdgeInsets.only(right: 14),
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(20),
                border: Border.all(color: color.withOpacity(0.3)),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title,
                      style: GoogleFonts.fredoka(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 4),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 8, vertical: 2),
                    decoration: BoxDecoration(
                      color: color.withOpacity(0.12),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(diff,
                        style: TextStyle(
                            color: color,
                            fontSize: 10,
                            fontWeight: FontWeight.w800)),
                  ),
                  const Spacer(),
                  Row(children: [
                    Icon(Icons.play_circle_fill_rounded,
                        color: color, size: 20),
                    const SizedBox(width: 6),
                    Text('Try It!',
                        style: GoogleFonts.fredoka(
                            color: color,
                            fontSize: 13,
                            fontWeight: FontWeight.w600)),
                  ]),
                ],
              ),
            ),
          ).animate().fadeIn(delay: (80 * i).ms).slideX(begin: 0.08);
        },
      ),
    );
  }

  // ── Resources ──────────────────────────────────────────────────────────────

  Widget _buildResourceGrid(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 24),
      child: Column(
        children: _resources.map((r) => _buildResourceTile(r)).toList(),
      ),
    ).animate().fadeIn(delay: 150.ms);
  }

  Widget _buildResourceTile(_Resource res) {
    return GestureDetector(
      onTap: () => _launchUrl(res.url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(18),
          border: Border.all(color: AppTheme.skyBlue.withOpacity(0.15)),
        ),
        child: Row(
          children: [
            Text(res.icon, style: const TextStyle(fontSize: 28)),
            const SizedBox(width: 14),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(res.name,
                      style: GoogleFonts.baloo2(
                        color: AppTheme.textPrimary,
                        fontSize: 15,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 2),
                  Text(res.description,
                      style: GoogleFonts.baloo2(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      )),
                  const SizedBox(height: 6),
                  Text(res.url,
                      style: const TextStyle(
                        color: AppTheme.skyBlue,
                        fontSize: 11,
                        decoration: TextDecoration.underline,
                        decorationColor: AppTheme.skyBlue,
                      )),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded,
                color: AppTheme.skyBlue, size: 16),
          ],
        ),
      ),
    );
  }

  // ── Contact / Support ──────────────────────────────────────────────────────

  Widget _buildContactSection(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24),
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.accentPurple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Contact & Curriculum Sources',
              style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 16),
          _contactRow(Icons.language_rounded, 'FIDE Official', 'fide.com',
              'https://www.fide.com'),
          _contactRow(Icons.email_rounded, 'Chess Academy Support',
              'academy@chessmaster.app', 'mailto:academy@chessmaster.app'),
          _contactRow(
              Icons.school_rounded,
              'Curriculum Based On',
              'FIDE Laws of Chess 2023',
              'https://handbook.fide.com/chapter/E012023'),
          _contactRow(Icons.people_rounded, 'Community Discord',
              'discord.gg/chessmaster', 'https://discord.gg/chessmaster'),
          _contactRow(Icons.feed_rounded, 'Chess News (TWIC)',
              'theweekinchess.com', 'https://theweekinchess.com'),
          const SizedBox(height: 14),
          Container(
            padding: const EdgeInsets.all(14),
            decoration: BoxDecoration(
              color: AppTheme.goldPrimary.withOpacity(0.08),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                  color: AppTheme.goldPrimary.withOpacity(0.2)),
            ),
            child: Row(
              children: [
                const Icon(Icons.info_outline_rounded,
                    color: AppTheme.goldPrimary, size: 18),
                const SizedBox(width: 10),
                Expanded(
                  child: Text(
                    'All lessons follow FIDE Official Rules (July 2023 edition). '
                    'Puzzle ratings are calibrated using the Glicko-2 system.',
                    style: GoogleFonts.baloo2(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        height: 1.5),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _contactRow(IconData icon, String label, String value, String url) {
    return GestureDetector(
      onTap: () => _launchUrl(url),
      child: Padding(
        padding: const EdgeInsets.only(bottom: 12),
        child: Row(
          children: [
            Icon(icon, color: AppTheme.accentPurple, size: 18),
            const SizedBox(width: 10),
            Text('$label: ',
                style: GoogleFonts.baloo2(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
            Flexible(
              child: Text(value,
                  style: const TextStyle(
                    color: AppTheme.accentPurple,
                    fontSize: 13,
                    decoration: TextDecoration.underline,
                    decorationColor: AppTheme.accentPurple,
                  )),
            ),
          ],
        ),
      ),
    );
  }

  // ── Helpers ────────────────────────────────────────────────────────────────

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
