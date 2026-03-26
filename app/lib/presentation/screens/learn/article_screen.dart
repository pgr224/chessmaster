import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';

// ─── Article Data Model ───────────────────────────────────────────────────────

class _ArticleData {
  final String title;
  final String subtitle;
  final String author;
  final String authorTitle;
  final String publishedDate;
  final String readTime;
  final String difficulty;
  final String heroImage;
  final List<_Section> sections;
  final List<_MoveSequence> keyMoves;
  final List<_StudyWeek> studySchedule;
  final List<_Reference> references;
  final _ContactInfo contactInfo;

  const _ArticleData({
    required this.title, required this.subtitle, required this.author,
    required this.authorTitle, required this.publishedDate, required this.readTime,
    required this.difficulty, required this.heroImage, required this.sections,
    required this.keyMoves, required this.studySchedule, required this.references,
    required this.contactInfo,
  });
}

class _Section {
  final String heading;
  final String body;
  const _Section({required this.heading, required this.body});
}

class _MoveSequence {
  final String label;
  final String moves;
  final String notes;
  const _MoveSequence({required this.label, required this.moves, required this.notes});
}

class _StudyWeek {
  final String period;
  final String focus;
  final String tasks;
  final Color color;
  const _StudyWeek({required this.period, required this.focus, required this.tasks, required this.color});
}

class _Reference {
  final String title;
  final String source;
  final String url;
  final String type;
  const _Reference({required this.title, required this.source, required this.url, required this.type});
}

class _ContactInfo {
  final String curator;
  final String email;
  final String website;
  final String lastReviewed;
  final String basedOn;
  const _ContactInfo({
    required this.curator, required this.email, required this.website,
    required this.lastReviewed, required this.basedOn,
  });
}

// ─── Article Registry ─────────────────────────────────────────────────────────

final _articles = <String, _ArticleData>{
  'sicilian': _ArticleData(
    title: 'Sicilian Defense',
    subtitle: 'The most popular & fighting reply to 1.e4',
    author: 'GM Magnus Bot',
    authorTitle: 'Senior Chess Instructor · Elo 2800+',
    publishedDate: 'March 25, 2026',
    readTime: '45 min',
    difficulty: 'Intermediate',
    heroImage: 'https://images.unsplash.com/photo-1529699211952-734e80c4d42b?auto=format&fit=crop&q=80&w=800',
    sections: const [
      _Section(
        heading: 'What is the Sicilian Defense?',
        body: 'The Sicilian Defense arises after 1.e4 c5 and is the most popular response to White\'s first move among top-level players. '
          'It immediately fights for the d4 square without symmetrical pawn exchanges, creating an imbalanced game that Black can use to play for a win.',
      ),
      _Section(
        heading: 'Why do top players choose it?',
        body: '• Asymmetry creates winning chances for both sides\n'
          '• Black avoids early symmetrical equality\n'
          '• Leads to rich middlegame positions with specific plans\n'
          '• Statistically the highest-scoring opening for Black vs 1.e4\n\n'
          'According to ChessBase MegaDatabase (2024), the Sicilian accounts for over 25% of all 1.e4 games at the GM level.',
      ),
      _Section(
        heading: 'Main Variations',
        body: 'After 1.e4 c5 2.Nf3, Black has several major systems:\n\n'
          '• Najdorf (2...d6 3.d4 cxd4 4.Nxd4 Nf6 5.Nc3 a6) — the sharpest and most fashionable. Kasparov\'s weapon of choice.\n'
          '• Dragon (5...g6) — Black fianchettoes the bishop and creates kingside counterplay.\n'
          '• Scheveningen (5...e6) — flexible, solid; Black builds a small center.\n'
          '• Classical (5...Nc6) — piece development first; leads to the Richter-Rauzer and Sozin attacks.\n'
          '• Kan / Taimanov (4...e6 or 4...Nc6) — flexible structures, avoiding early commitments.',
      ),
      _Section(
        heading: 'Strategic Themes',
        body: '1. d5 pawn break — Black often aims to push ...d5 to free their position.\n'
          '2. Minority attack — White plays a4-a5 to undermine Black\'s queenside.\n'
          '3. Kingside attack — White castles queenside and storms with g4-g5-h4.\n'
          '4. ...b5-b4 counterplay — Black advances on the queenside to distract White.\n\n'
          'Mastering these themes is the key to playing the Sicilian well in both directions.',
      ),
    ],
    keyMoves: const [
      _MoveSequence(
        label: 'Basic Sicilian',
        moves: '1.e4 c5 2.Nf3 d6 3.d4 cxd4 4.Nxd4 Nf6 5.Nc3',
        notes: 'The Open Sicilian — White immediately opens the center.',
      ),
      _MoveSequence(
        label: 'Najdorf Move Order',
        moves: '5...a6 6.Bg5 e6 7.f4 Be7 8.Qf3 Qc7',
        notes: 'Kasparov\'s favourite. Black prepares ...b5 and keeps flexibility.',
      ),
      _MoveSequence(
        label: 'Dragon Variation',
        moves: '5...g6 6.Be3 Bg7 7.f3 0-0 8.Qd2 Nc6 9.0-0-0',
        notes: 'Classic Yugoslav Attack. White castles queenside for a king-hunt.',
      ),
      _MoveSequence(
        label: 'Alapin (Anti-Sicilian)',
        moves: '1.e4 c5 2.c3 Nf6 3.e5 Nd5 4.d4 cxd4 5.cxd4',
        notes: 'Avoid theory? The Alapin is solid but gives Black dynamic counterplay.',
      ),
    ],
    studySchedule: const [
      _StudyWeek(
        period: 'Day 1–2',
        focus: 'Understand the Basics',
        tasks: 'Study the Open Sicilian move order. Watch 1 video on lichess.org/training.',
        color: AppTheme.goldPrimary,
      ),
      _StudyWeek(
        period: 'Day 3–4',
        focus: 'Pick Your Variation',
        tasks: 'Choose Najdorf, Dragon, or Kan. Read the variation-specific chapter in "Chess Opening Essentials".',
        color: AppTheme.skyBlue,
      ),
      _StudyWeek(
        period: 'Day 5',
        focus: 'Drill Key Move Orders',
        tasks: 'Use Chess Tempo to drill 30 opening puzzles in your chosen line.',
        color: AppTheme.accentPurple,
      ),
      _StudyWeek(
        period: 'Day 6–7',
        focus: 'Play & Analyze',
        tasks: 'Play 5 games with the Sicilian. Analyze each game with Stockfish 17.',
        color: AppTheme.accentCyan,
      ),
    ],
    references: const [
      _Reference(
        title: 'Kasparov on the Sicilian Najdorf (DVD)',
        source: 'ChessBase Publishing, 2009',
        url: 'https://shop.chessbase.com',
        type: 'Book/DVD',
      ),
      _Reference(
        title: 'Sicilian Defense Opening Explorer',
        source: 'Lichess.org',
        url: 'https://lichess.org/opening/Sicilian_Defense',
        type: 'Online',
      ),
      _Reference(
        title: 'Chess Opening Essentials Vol. 1',
        source: 'New in Chess, 2007 — Djurić, Komarov, Pantaleoni',
        url: 'https://www.newinchess.com',
        type: 'Book',
      ),
      _Reference(
        title: 'Sicilian Defense Statistics & Games',
        source: 'Chess.com Explorer',
        url: 'https://www.chess.com/openings/Sicilian-Defense',
        type: 'Online',
      ),
      _Reference(
        title: 'Aagaard: Attacking Manual 1 & 2',
        source: 'Quality Chess, 2010',
        url: 'https://www.qualitychess.co.uk',
        type: 'Book',
      ),
      _Reference(
        title: 'FIDE Laws of Chess (2023 Edition)',
        source: 'FIDE Handbook',
        url: 'https://handbook.fide.com/chapter/E012023',
        type: 'Regulation',
      ),
    ],
    contactInfo: _ContactInfo(
      curator: 'Chess Academy Editorial Team',
      email: 'lessons@chessmaster.app',
      website: 'https://chessmaster.app/academy',
      lastReviewed: 'March 2026',
      basedOn: 'FIDE Laws of Chess 2023 + ChessBase MegaDatabase 2024',
    ),
  ),
};

// ─── Screen ───────────────────────────────────────────────────────────────────

class ArticleScreen extends StatelessWidget {
  final String articleId;
  const ArticleScreen({super.key, required this.articleId});

  @override
  Widget build(BuildContext context) {
    final data = _articles[articleId];
    if (data == null) return _buildNotFound(context);

    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context, data),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAuthorInfo(data),
                  const SizedBox(height: 28),
                  _buildIntroStats(data),
                  const SizedBox(height: 28),
                  ..._buildSections(data),
                  const SizedBox(height: 28),
                  _buildKeyMovesSection(data),
                  const SizedBox(height: 28),
                  _buildBoardDiagram(),
                  const SizedBox(height: 28),
                  _buildStudySchedule(data),
                  const SizedBox(height: 28),
                  _buildReferences(data),
                  const SizedBox(height: 28),
                  _buildContactInfo(data),
                  const SizedBox(height: 28),
                  _buildRelatedLessons(),
                  const SizedBox(height: 32),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  // ── Hero App Bar ──────────────────────────────────────────────────────────

  Widget _buildSliverAppBar(BuildContext context, _ArticleData data) {
    return SliverAppBar(
      expandedHeight: 250,
      pinned: true,
      backgroundColor: AppTheme.midnight,
      leading: Padding(
        padding: const EdgeInsets.only(left: 8),
        child: CircleAvatar(
          backgroundColor: Colors.black38,
          child: IconButton(
            icon: const Icon(Icons.close_rounded, color: Colors.white),
            onPressed: () => context.pop(),
          ),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(data.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ).animate().fadeIn(delay: 200.ms),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(data.heroImage, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppTheme.midnight.withValues(alpha: 0.9)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  // ── Author Info ───────────────────────────────────────────────────────────

  Widget _buildAuthorInfo(_ArticleData data) {
    return Row(
      children: [
        CircleAvatar(
          radius: 22, backgroundColor: AppTheme.goldPrimary,
          child: const Icon(Icons.person, size: 22, color: AppTheme.midnight),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.author, style: GoogleFonts.baloo2(
                color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 15,
              )),
              Text(data.authorTitle, style: GoogleFonts.baloo2(
                color: AppTheme.textMuted, fontSize: 12,
              )),
              Text('Published ${data.publishedDate}', style: GoogleFonts.baloo2(
                color: AppTheme.textMuted, fontSize: 11,
              )),
            ],
          ),
        ),
        _badge('FEATURED', AppTheme.goldPrimary),
      ],
    ).animate().fadeIn();
  }

  Widget _badge(String label, Color color) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 5),
      decoration: BoxDecoration(color: color.withValues(alpha: 0.12), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: TextStyle(color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  // ── Intro Stats Bar ───────────────────────────────────────────────────────

  Widget _buildIntroStats(_ArticleData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.timer_rounded, data.readTime, 'Read Time'),
          _vDivider(),
          _statItem(Icons.bar_chart_rounded, data.difficulty, 'Level'),
          _vDivider(),
          _statItem(Icons.library_books_rounded, '${_articles[articleId]!.references.length} refs', 'References'),
          _vDivider(),
          _statItem(Icons.event_note_rounded, '7 days', 'Study Plan'),
        ],
      ),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _statItem(IconData icon, String value, String label) {
    return Column(
      children: [
        Icon(icon, color: AppTheme.goldPrimary, size: 18),
        const SizedBox(height: 4),
        Text(value, style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700)),
        Text(label, style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _vDivider() => Container(height: 40, width: 1, color: Colors.white10);

  // ── Content Sections ──────────────────────────────────────────────────────

  List<Widget> _buildSections(_ArticleData data) {
    return data.sections.expand((s) => [
      _sectionHeading(s.heading),
      const SizedBox(height: 10),
      Text(s.body, style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 15, height: 1.65)),
      const SizedBox(height: 20),
    ]).toList()..animate().fadeIn(delay: 150.ms);
  }

  Widget _sectionHeading(String text) {
    return Text(text, style: GoogleFonts.fredoka(
      color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w700,
    ));
  }

  // ── Key Moves Section ─────────────────────────────────────────────────────

  Widget _buildKeyMovesSection(_ArticleData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('♟ Key Move Sequences'),
        const SizedBox(height: 12),
        ...data.keyMoves.map((m) => _buildMoveCard(m)),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildMoveCard(_MoveSequence seq) {
    return Container(
      margin: const EdgeInsets.only(bottom: 12),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.navyCard,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(seq.label, style: GoogleFonts.fredoka(
            color: AppTheme.accentPurple, fontSize: 13, fontWeight: FontWeight.w700, letterSpacing: 0.5,
          )),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(seq.moves, style: const TextStyle(
              color: AppTheme.goldPrimary, fontFamily: 'monospace', fontSize: 14, fontWeight: FontWeight.w600,
            )),
          ),
          const SizedBox(height: 8),
          Text(seq.notes, style: GoogleFonts.baloo2(
            color: AppTheme.textSecondary, fontSize: 13, height: 1.5,
          )),
        ],
      ),
    );
  }

  // ── Board Diagram Placeholder ─────────────────────────────────────────────

  Widget _buildBoardDiagram() {
    return Column(
      children: [
        Container(
          height: 280,
          width: double.infinity,
          decoration: BoxDecoration(
            color: AppTheme.navyCard,
            borderRadius: BorderRadius.circular(20),
            border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.grid_4x4_rounded, size: 60, color: AppTheme.goldPrimary),
              const SizedBox(height: 14),
              Text('Interactive Board', style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 18)),
              const SizedBox(height: 4),
              Text('Tap to explore position', style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Center(child: Text('Position after 1.e4 c5 2.Nf3 d6 3.d4 cxd4 4.Nxd4 Nf6 5.Nc3',
          style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 11))),
      ],
    ).animate().fadeIn(delay: 250.ms);
  }

  // ── Study Schedule ────────────────────────────────────────────────────────

  Widget _buildStudySchedule(_ArticleData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('📅 7-Day Study Schedule'),
        const SizedBox(height: 4),
        Text('Recommended plan to master this opening in one week.',
          style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 13)),
        const SizedBox(height: 14),
        ...data.studySchedule.map((w) => _buildStudyRow(w)),
      ],
    ).animate().fadeIn(delay: 300.ms);
  }

  Widget _buildStudyRow(_StudyWeek week) {
    return Container(
      margin: const EdgeInsets.only(bottom: 10),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: week.color.withValues(alpha: 0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: week.color.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(week.period, style: TextStyle(
              color: week.color, fontSize: 11, fontWeight: FontWeight.w800,
            )),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(week.focus, style: GoogleFonts.baloo2(
                  color: AppTheme.textPrimary, fontSize: 15, fontWeight: FontWeight.w700,
                )),
                const SizedBox(height: 4),
                Text(week.tasks, style: GoogleFonts.baloo2(
                  color: AppTheme.textSecondary, fontSize: 13, height: 1.5,
                )),
              ],
            ),
          ),
        ],
      ),
    );
  }

  // ── References ────────────────────────────────────────────────────────────

  Widget _buildReferences(_ArticleData data) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        _sectionHeading('🔗 References & Further Reading'),
        const SizedBox(height: 12),
        ...data.references.map((r) => _buildRefTile(r)),
      ],
    ).animate().fadeIn(delay: 350.ms);
  }

  Widget _buildRefTile(_Reference ref) {
    return GestureDetector(
      onTap: () => _launchUrl(ref.url),
      child: Container(
        margin: const EdgeInsets.only(bottom: 10),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.skyBlue.withValues(alpha: 0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(ref.type, style: const TextStyle(
                color: AppTheme.skyBlue, fontSize: 10, fontWeight: FontWeight.w800,
              )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ref.title, style: GoogleFonts.baloo2(
                    color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 2),
                  Text(ref.source, style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(ref.url,
                    style: const TextStyle(
                      color: AppTheme.skyBlue, fontSize: 11,
                      decoration: TextDecoration.underline, decorationColor: AppTheme.skyBlue,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded, color: AppTheme.skyBlue, size: 14),
          ],
        ),
      ),
    );
  }

  // ── Contact / Source Info ─────────────────────────────────────────────────

  Widget _buildContactInfo(_ArticleData data) {
    final c = data.contactInfo;
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentPurple.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📬 Source & Contact', style: GoogleFonts.fredoka(
            color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w700,
          )),
          const SizedBox(height: 14),
          _contactRow(Icons.person_outline_rounded, 'Curator', c.curator),
          _contactRow(Icons.email_outlined, 'Email',  c.email, url: 'mailto:${c.email}'),
          _contactRow(Icons.language_rounded, 'Website', c.website, url: c.website),
          _contactRow(Icons.update_rounded, 'Last Reviewed', c.lastReviewed),
          _contactRow(Icons.menu_book_rounded, 'Based On', c.basedOn),
        ],
      ),
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _contactRow(IconData icon, String label, String value, {String? url}) {
    final Widget text = url != null
      ? GestureDetector(
          onTap: () => _launchUrl(url),
          child: Text(value, style: const TextStyle(
            color: AppTheme.accentPurple, fontSize: 13,
            decoration: TextDecoration.underline, decorationColor: AppTheme.accentPurple,
          )),
        )
      : Text(value, style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 13));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accentPurple, size: 16),
          const SizedBox(width: 8),
          Text('$label: ', style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 13, fontWeight: FontWeight.w600)),
          Flexible(child: text),
        ],
      ),
    );
  }

  // ── Related Lessons ───────────────────────────────────────────────────────

  Widget _buildRelatedLessons() {
    const related = [
      ('The Najdorf Variation', '30 min', AppTheme.goldPrimary),
      ('Sicilian Dragon Basics', '20 min', AppTheme.accentPurple),
      ('The Rossolimo Attack', '15 min', AppTheme.skyBlue),
      ('Ruy López Opening', '25 min', Color(0xFF6BCB77)),
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('Related Lessons', style: GoogleFonts.fredoka(
          color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.bold,
        )),
        const SizedBox(height: 14),
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: related.map((r) => _relatedCard(r.$1, r.$2, r.$3)).toList(),
          ),
        ),
      ],
    ).animate().fadeIn(delay: 450.ms);
  }

  Widget _relatedCard(String title, String time, Color color) {
    return Container(
      width: 190,
      margin: const EdgeInsets.only(right: 14),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: color.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.baloo2(
            color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14,
          )),
          const Spacer(),
          Row(children: [
            Icon(Icons.timer_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text(time, style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w700)),
          ]),
        ],
      ),
    );
  }

  // ── Not Found ─────────────────────────────────────────────────────────────

  Widget _buildNotFound(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        leading: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      body: const Center(
        child: Text('Article not found.', style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri)) await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
