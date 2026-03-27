import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:dio/dio.dart';

import '../../../core/theme/app_theme.dart';
import '../../../core/di/injection_container.dart' as di;

class ChessWorldScreen extends StatefulWidget {
  const ChessWorldScreen({super.key});

  @override
  State<ChessWorldScreen> createState() => _ChessWorldScreenState();
}

class _ChessWorldScreenState extends State<ChessWorldScreen> {
  List<Map<String, dynamic>> _dailyContent = [];
  bool _loading = true;
  bool _fromApi = false;
  String? _lastUpdated;

  // ── Static fallback content ──
  static final _fallbackCards = <Map<String, dynamic>>[
    {
      'emoji': '🌍',
      'title': 'Global Tournament News',
      'subtitle': 'Fresh updates from around the chess world.',
      'items': <String>[
        'FIDE World Championship: final prep games are trending this week.',
        'Candidates Tournament watch: new young stars are climbing fast.',
        'Junior Chess Cup registrations opened in 20+ countries.',
      ],
      'gradient': <Color>[Color(0xFF74B9FF), Color(0xFFA29BFE)],
    },
    {
      'emoji': '📅',
      'title': 'Upcoming & Participation',
      'subtitle': 'How to join kids and amateur events.',
      'items': <String>[
        'Kids Rapid Weekend: register via contact@chesskids.org.',
        'City Open (U-12 / U-16): ask your local chess club for qualifiers.',
        'Online Youth League: team signups at events@chessfuture.net.',
      ],
      'gradient': <Color>[Color(0xFF6BCB77), Color(0xFF4ECDC4)],
    },
    {
      'emoji': '🚀',
      'title': 'Career in Chess',
      'subtitle': 'Grow from beginner to champion with a clear path.',
      'items': <String>[
        'Learn ratings: start with local events, then national and FIDE-rated tournaments.',
        'Build your toolkit: tactics puzzles, endgame practice, and game review habits.',
        'Dream big: track your progress toward titled-player milestones.',
      ],
      'gradient': <Color>[Color(0xFFFF6B9D), Color(0xFFFF8A5C)],
    },
  ];

  @override
  void initState() {
    super.initState();
    _fetchDailyContent();
  }

  Future<void> _fetchDailyContent() async {
    setState(() => _loading = true);
    try {
      final dio = di.sl<Dio>();
      final response = await dio.get('/api/content/daily');
      final data = response.data as Map<String, dynamic>;
      final list = (data['content'] as List?) ?? [];
      if (list.isNotEmpty) {
        setState(() {
          _dailyContent = list.cast<Map<String, dynamic>>();
          _fromApi = true;
          _lastUpdated = DateTime.now().toIso8601String().substring(0, 16);
          _loading = false;
        });
        return;
      }
    } catch (_) {
      // Fall through to static content
    }
    setState(() { _loading = false; _fromApi = false; });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: RefreshIndicator(
            onRefresh: _fetchDailyContent,
            color: AppTheme.goldPrimary,
            child: ListView(
              physics: const BouncingScrollPhysics(parent: AlwaysScrollableScrollPhysics()),
              padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
              children: [
                _buildHeader(),
                if (_lastUpdated != null) _buildUpdateBanner(),
                const SizedBox(height: 16),
                if (_loading)
                  const Padding(
                    padding: EdgeInsets.only(top: 80),
                    child: Center(child: CircularProgressIndicator(color: AppTheme.goldPrimary)),
                  )
                else if (_fromApi && _dailyContent.isNotEmpty)
                  ..._dailyContent.asMap().entries.map((e) => _buildApiCard(e.value, e.key))
                else
                  ..._fallbackCards.asMap().entries.map((e) => _buildFallbackCard(e.value, e.key)),
              ],
            ),
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.rainbowGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.goldPrimary.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public_rounded, color: AppTheme.midnight, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chess World',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.midnight,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'News, events, and inspiration for your chess journey.',
            style: GoogleFonts.baloo2(
              color: AppTheme.midnight.withValues(alpha: 0.9),
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildUpdateBanner() {
    return Container(
      margin: const EdgeInsets.only(top: 10),
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: AppTheme.accentGreen.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.accentGreen.withValues(alpha: 0.2)),
      ),
      child: Row(
        children: [
          const Icon(Icons.cloud_done_rounded, color: AppTheme.accentGreen, size: 16),
          const SizedBox(width: 8),
          Text('Updated from live feed · $_lastUpdated', style: GoogleFonts.baloo2(
            color: AppTheme.accentGreen, fontSize: 12, fontWeight: FontWeight.w600,
          )),
        ],
      ),
    );
  }

  Widget _buildApiCard(Map<String, dynamic> item, int index) {
    final title = item['title'] as String? ?? 'Update';
    final body = item['body'] as String? ?? item['content'] as String? ?? '';
    final category = item['category'] as String? ?? 'news';
    final gradientColors = _gradientForCategory(category);

    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: LinearGradient(colors: gradientColors),
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Text(_emojiForCategory(category), style: const TextStyle(fontSize: 26)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(title, style: GoogleFonts.fredoka(
                      color: AppTheme.midnight, fontSize: 20, fontWeight: FontWeight.w700,
                    )),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 14),
            Text(body, style: GoogleFonts.baloo2(
              color: AppTheme.textSecondary, fontSize: 15, fontWeight: FontWeight.w500, height: 1.4,
            )),
          ],
        ),
      ),
    ).animate().fadeIn(delay: (index * 120).ms, duration: 350.ms).slideY(begin: 0.08);
  }

  Widget _buildFallbackCard(Map<String, dynamic> card, int index) {
    final items = (card['items'] as List).cast<String>();
    final colors = (card['gradient'] as List).cast<Color>();
    return _WorldCard(
      emoji: card['emoji'] as String,
      title: card['title'] as String,
      subtitle: card['subtitle'] as String,
      gradient: LinearGradient(colors: colors),
      items: items,
    ).animate().fadeIn(delay: (index * 120).ms, duration: 350.ms).slideY(begin: 0.08);
  }

  List<Color> _gradientForCategory(String category) => switch (category) {
    'tournament' || 'events' => [const Color(0xFF6BCB77), const Color(0xFF4ECDC4)],
    'career' => [const Color(0xFFFF6B9D), const Color(0xFFFF8A5C)],
    _ => [const Color(0xFF74B9FF), const Color(0xFFA29BFE)],
  };

  String _emojiForCategory(String category) => switch (category) {
    'tournament' || 'events' => '📅',
    'career' => '🚀',
    _ => '🌍',
  };
}

class _WorldCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final List<String> items;

  const _WorldCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: 14),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.fredoka(
                        color: AppTheme.midnight,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: GoogleFonts.baloo2(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.goldPrimary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.baloo2(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}