import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:url_launcher/url_launcher.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

import '../../../data/models/tutorial_model.dart';

// ─── Week Data ────────────────────────────────────────────────────────────────

class WeekDetail {
  final int week;
  final String topic;
  final String goal;
  final String time;
  final String conceptTitle;
  final String conceptBody;
  final List<String> dailyTasks;
  final List<_FenPosition> keyPositions;
  final String? tutorialId;
  final List<_ExtLink> resources;

  const WeekDetail({
    required this.week,
    required this.topic,
    required this.goal,
    required this.time,
    required this.conceptTitle,
    required this.conceptBody,
    required this.dailyTasks,
    required this.keyPositions,
    this.tutorialId,
    required this.resources,
  });
}

class _FenPosition {
  final String fen;
  final String label;
  const _FenPosition(this.fen, this.label);
}

class _ExtLink {
  final String title;
  final String url;
  const _ExtLink(this.title, this.url);
}

// ─── All 12 Weeks ─────────────────────────────────────────────────────────────

final List<WeekDetail> weekDetails = [
  WeekDetail(
    week: 1,
    topic: 'Piece Values & Movement',
    goal: 'Know every piece\'s power',
    time: '3 hrs',
    conceptTitle: 'Piece Values',
    conceptBody:
        'Each piece has a relative value: Pawn=1, Knight=3, Bishop=3, Rook=5, Queen=9. '
        'The King is invaluable. Understanding these values helps you avoid bad trades and find winning combinations.',
    dailyTasks: [
      'Learn pawn movement and capture patterns',
      'Practice knight\'s L-shape on an empty board',
      'Study bishop diagonal control',
      'Understand rook files & ranks',
      'Practice queen movement (rook + bishop)',
      'Learn king movement and safety',
      'Play 3 practice games using all pieces',
    ],
    keyPositions: [
      _FenPosition('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'Starting position'),
      _FenPosition('8/8/8/4N3/8/8/8/8 w - - 0 1',
          'Knight: 8 possible moves from center'),
      _FenPosition('8/8/8/4B3/8/8/8/8 w - - 0 1', 'Bishop: diagonal control'),
    ],
    tutorialId: 'beginner1',
    resources: [
      _ExtLink('Lichess Learn Basics', 'https://lichess.org/learn'),
      _ExtLink('Chess.com Piece Movement',
          'https://www.chess.com/learn-how-to-play-chess'),
    ],
  ),
  WeekDetail(
    week: 2,
    topic: 'Basic Checkmates',
    goal: 'Mate with Q+K, R+K',
    time: '3 hrs',
    conceptTitle: 'Checkmate Patterns',
    conceptBody:
        'Checkmate ends the game. The two most essential patterns are: Queen+King vs King (drive to edge, '
        'use queen to cut off squares) and Rook+King vs King (use the rook to cut off ranks, king to oppose).',
    dailyTasks: [
      'Study Q+K vs K checkmate method',
      'Practice Q+K mate 5 times against computer',
      'Study R+K vs K checkmate method',
      'Practice R+K mate 5 times against computer',
      'Learn 2-rook ladder checkmate',
      'Study back-rank mate pattern',
      'Solve 10 checkmate-in-1 puzzles',
    ],
    keyPositions: [
      _FenPosition(
          '4k3/8/8/8/8/8/8/4K2Q w - - 0 1', 'Q+K vs K: drive king to edge'),
      _FenPosition('4k3/8/8/8/8/8/8/R3K3 w - - 0 1', 'R+K vs K: cut off ranks'),
    ],
    tutorialId: 'beginner5',
    resources: [
      _ExtLink('Lichess Checkmate Practice', 'https://lichess.org/practice'),
      _ExtLink(
          'Checkmate Patterns Video', 'https://www.youtube.com/@GothamChess'),
    ],
  ),
  WeekDetail(
    week: 3,
    topic: 'Opening Principles',
    goal: 'Control center, develop pieces',
    time: '2 hrs',
    conceptTitle: 'The Golden Rules of the Opening',
    conceptBody:
        '1) Control the center with pawns (e4/d4). 2) Develop minor pieces (knights before bishops). '
        '3) Castle early for king safety. 4) Don\'t move the same piece twice. 5) Don\'t bring the queen out too early.',
    dailyTasks: [
      'Study the 3 golden opening rules',
      'Play 3 games focusing only on center control',
      'Practice developing knights to f3/c3',
      'Practice developing bishops actively',
      'Learn when and how to castle',
      'Review 3 games — did you follow principles?',
      'Watch one opening principles video',
    ],
    keyPositions: [
      _FenPosition('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          '1.e4 — controlling center'),
      _FenPosition(
          'r1bqkbnr/pppppppp/2n5/8/4P3/5N2/PPPP1PPP/RNBQKB1R b KQkq - 2 2',
          'Knights developed first'),
    ],
    tutorialId: 'beginner2',
    resources: [
      _ExtLink('Chess.com Opening Principles',
          'https://www.chess.com/article/view/chess-openings-the-basics'),
      _ExtLink(
          'GothamChess Opening Guide', 'https://www.youtube.com/@GothamChess'),
    ],
  ),
  WeekDetail(
    week: 4,
    topic: 'Tactics: Forks & Pins',
    goal: 'Win material systematically',
    time: '4 hrs',
    conceptTitle: 'Forks & Pins',
    conceptBody:
        'A fork attacks two pieces at once — knights are best at this. A pin immobilizes a piece because '
        'moving it would expose a more valuable piece behind it. Master these two patterns and you\'ll win material consistently.',
    dailyTasks: [
      'Study knight fork patterns (10 examples)',
      'Solve 15 fork puzzles on Lichess',
      'Study absolute vs relative pins',
      'Solve 15 pin puzzles',
      'Practice finding forks in your own games',
      'Play 3 games — try to create fork/pin threats',
      'Review missed tactics from your games',
    ],
    keyPositions: [
      _FenPosition(
          '6k1/5ppp/8/4N3/8/8/5PPP/6K1 w - - 0 1', 'Knight fork potential'),
      _FenPosition(
          '6k1/5ppp/8/8/3b4/5B2/5PPP/6K1 w - - 0 1', 'Pin along diagonal'),
    ],
    tutorialId: 'intermediate1',
    resources: [
      _ExtLink('Lichess Tactics Trainer', 'https://lichess.org/training'),
      _ExtLink('Chess.com Puzzles', 'https://www.chess.com/puzzles'),
    ],
  ),
  WeekDetail(
    week: 5,
    topic: 'Tactics: Skewers & Discovered Attacks',
    goal: 'Spot 2-move combos',
    time: '4 hrs',
    conceptTitle: 'Skewers & Discoveries',
    conceptBody:
        'A skewer is a reversed pin — attack a valuable piece, and when it moves, capture what\'s behind it. '
        'A discovered attack moves one piece to reveal an attack from another. Discovered check is devastating.',
    dailyTasks: [
      'Study 10 skewer examples',
      'Solve 15 skewer puzzles',
      'Study discovered attack patterns',
      'Solve 15 discovered attack puzzles',
      'Learn double check — king must move',
      'Play 3 games seeking these patterns',
      'Analyze games for missed discoveries',
    ],
    keyPositions: [
      _FenPosition('6k1/5ppp/8/8/8/8/3Q1PPP/6K1 w - - 0 1', 'Skewer potential'),
      _FenPosition(
          '6k1/5ppp/8/8/3r4/5B2/5PPP/6K1 w - - 0 1', 'Discovered attack setup'),
    ],
    tutorialId: 'intermediate3',
    resources: [
      _ExtLink('Chess Tempo Tactics', 'https://chesstempo.com'),
      _ExtLink(
          'Tactics Explained Video', 'https://www.youtube.com/@GothamChess'),
    ],
  ),
  WeekDetail(
    week: 6,
    topic: 'Common Openings',
    goal: 'Learn Sicilian, Italian, Ruy López',
    time: '3 hrs',
    conceptTitle: 'Three Must-Know Openings',
    conceptBody: 'Italian Game (1.e4 e5 2.Nf3 Nc6 3.Bc4) — simple development. '
        'Ruy López (3.Bb5) — strategic pressure on Black\'s center. '
        'Sicilian Defense (1.e4 c5) — Black fights for an asymmetrical game.',
    dailyTasks: [
      'Study Italian Game main line (5 moves deep)',
      'Play 2 games as White with the Italian',
      'Study Ruy López Berlin Defense',
      'Study Sicilian Defense Open variation',
      'Play 2 games as Black with the Sicilian',
      'Review opening explorer on Lichess',
      'Pick your favorite opening — play 3 games with it',
    ],
    keyPositions: [
      _FenPosition(
          'r1bqkbnr/pppp1ppp/2n5/4p3/2B1P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
          'Italian Game'),
      _FenPosition(
          'r1bqkbnr/pppp1ppp/2n5/1B2p3/4P3/5N2/PPPP1PPP/RNBQK2R b KQkq - 3 3',
          'Ruy López'),
    ],
    tutorialId: 'opening_italian',
    resources: [
      _ExtLink('Lichess Opening Explorer', 'https://lichess.org/opening'),
      _ExtLink('Chess.com Opening Guide', 'https://www.chess.com/openings'),
    ],
  ),
  WeekDetail(
    week: 7,
    topic: 'Pawn Structure',
    goal: 'Understand weak & passed pawns',
    time: '3 hrs',
    conceptTitle: 'Pawn Structure Basics',
    conceptBody:
        'Pawns can\'t move backward — every pawn move is permanent. Key concepts: isolated pawns (weakness), '
        'doubled pawns (inflexible), passed pawns (must be pushed!), and pawn chains (attack the base).',
    dailyTasks: [
      'Study isolated pawn positions',
      'Study doubled pawn weaknesses',
      'Study passed pawn endgames',
      'Identify pawn structures in 5 GM games',
      'Play 2 games — note your pawn structure',
      'Study pawn chain theory (Nimzowitsch)',
      'Review — classify your game pawn structures',
    ],
    keyPositions: [
      _FenPosition(
          '8/pp3ppp/3p4/8/3P4/8/PP3PPP/8 w - - 0 1', 'Isolated d-pawn'),
      _FenPosition('8/pp3ppp/8/3P4/8/8/PP3PPP/8 w - - 0 1', 'Passed d-pawn'),
    ],
    tutorialId: 'strategy_pawns',
    resources: [
      _ExtLink('Pawn Structure 101',
          'https://www.chess.com/article/view/pawn-structure-101'),
      _ExtLink('My System — Nimzowitsch',
          'https://www.amazon.com/My-System-Aron-Nimzowitsch/dp/1857442490'),
    ],
  ),
  WeekDetail(
    week: 8,
    topic: 'Rook Endgames',
    goal: 'Lucena & Philidor positions',
    time: '3 hrs',
    conceptTitle: 'Rook Endgame Essentials',
    conceptBody:
        '80% of piece endgames involve rooks. The Lucena position (bridge building) wins for the stronger side. '
        'The Philidor position (6th rank defense) draws for the weaker side. Master both!',
    dailyTasks: [
      'Study the Lucena position thoroughly',
      'Practice Lucena bridge building 5 times',
      'Study the Philidor defensive method',
      'Practice Philidor defense 5 times',
      'Study rook activity — rooks behind passed pawns',
      'Solve 10 rook endgame puzzles',
      'Play 2 games — trade into rook endgames intentionally',
    ],
    keyPositions: [
      _FenPosition('1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1', 'Lucena position'),
      _FenPosition('8/4k3/R7/4P3/8/8/8/3rK3 w - - 0 1', 'Philidor defense'),
    ],
    tutorialId: 'endgame_lucena',
    resources: [
      _ExtLink('Lichess Endgame Practice', 'https://lichess.org/practice'),
      _ExtLink('Silman\'s Endgame Course',
          'https://www.amazon.com/Silmans-Complete-Endgame-Course-Beginner/dp/1890085103'),
    ],
  ),
  WeekDetail(
    week: 9,
    topic: 'King & Pawn Endgames',
    goal: 'Opposition & promotion races',
    time: '2 hrs',
    conceptTitle: 'Opposition & Key Squares',
    conceptBody:
        'Opposition = two kings facing each other with one square gap. The side NOT to move "has the opposition" '
        'and controls key squares. Key squares are 2 ranks ahead of a pawn — reach them to promote.',
    dailyTasks: [
      'Study direct opposition concept',
      'Practice opposition exercises (10 positions)',
      'Study key squares for central pawns',
      'Study the "rule of the square" for pawn races',
      'Practice K+P vs K — winning and drawing',
      'Solve 10 king-pawn endgame puzzles',
      'Play positions against computer',
    ],
    keyPositions: [
      _FenPosition('8/8/4k3/8/4P3/4K3/8/8 w - - 0 1', 'Direct opposition'),
      _FenPosition('8/8/8/8/k7/8/1P6/1K6 w - - 0 1', 'Key squares for b-pawn'),
    ],
    tutorialId: 'endgame_opposition',
    resources: [
      _ExtLink('Lichess K+P Endgames',
          'https://lichess.org/practice/pawn-endgames/the-opposition/bwoBhlP5/7Lnx9Xbm'),
      _ExtLink('100 Endgames You Must Know', 'https://www.newinchess.com'),
    ],
  ),
  WeekDetail(
    week: 10,
    topic: 'Middlegame Plans',
    goal: 'Build & execute plans',
    time: '4 hrs',
    conceptTitle: 'Planning in the Middlegame',
    conceptBody:
        'After the opening, ask: What are my advantages? Where should I attack? '
        'Common plans: minority attack (push b4-b5), kingside attack (pawn storm), piece centralization, and prophylaxis.',
    dailyTasks: [
      'Study 3 annotated GM middlegame plans',
      'Learn minority attack concept',
      'Learn kingside pawn storm concept',
      'Practice identifying plans in 3 positions',
      'Play 2 slow games — write your plan before each move',
      'Study Karpov\'s positional squeeze technique',
      'Review your games — were your plans logical?',
    ],
    keyPositions: [
      _FenPosition(
          'r1bq1rk1/pp2bppp/2n1pn2/3p4/3P4/2N1PN2/PPB2PPP/R1BQ1RK1 w - - 0 9',
          'Typical QGD middlegame'),
    ],
    tutorialId: 'advanced2',
    resources: [
      _ExtLink('Chess.com Annotated Games', 'https://www.chess.com/games'),
      _ExtLink('Lichess Study Library', 'https://lichess.org/study'),
    ],
  ),
  WeekDetail(
    week: 11,
    topic: 'Game Analysis',
    goal: 'Review 10 annotated GM games',
    time: '5 hrs',
    conceptTitle: 'Learning from the Masters',
    conceptBody:
        'Analyzing annotated grandmaster games is the single best way to improve after tactics training. '
        'Focus on WHY each move was played, not just the moves themselves.',
    dailyTasks: [
      'Analyze Morphy\'s Opera Game (1858)',
      'Analyze Kasparov vs Topalov (1999)',
      'Analyze Capablanca vs Marshall (1918)',
      'Analyze Fischer vs Byrne (1956) "Game of the Century"',
      'Analyze Carlsen\'s best endgame win',
      'Analyze 2 games from your favorite player',
      'Write key lessons learned from each game',
    ],
    keyPositions: [
      _FenPosition('rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
          'Start of every masterpiece'),
    ],
    tutorialId: 'analysis_opera',
    resources: [
      _ExtLink('Morphy Opera Game',
          'https://www.chess.com/article/view/paul-morphys-opera-game'),
      _ExtLink('Evergreen & Immortal Games',
          'https://lichess.org/study/great-games'),
    ],
  ),
  WeekDetail(
    week: 12,
    topic: 'Full Game Practice',
    goal: 'Apply everything in live games',
    time: '6 hrs',
    conceptTitle: 'Putting It All Together',
    conceptBody:
        'This is your graduation week. Play longer time controls (15+10 or 30 min), think about opening principles, '
        'tactical patterns, strategic plans, and endgame technique. Analyze every game afterwards.',
    dailyTasks: [
      'Play 2 slow games (15+10) — full concentration',
      'Analyze both games with engine after',
      'Play 2 more games — focus on your weakest area',
      'Solve 20 mixed puzzles for tactical sharpness',
      'Play 2 tournament-style games (30 min)',
      'Do a full self-assessment: opening, tactics, endgame',
      'Set your goals for the next 12 weeks!',
    ],
    keyPositions: [
      _FenPosition('rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR b KQkq - 0 1',
          'Your journey begins with 1.e4'),
    ],
    tutorialId: 'practice_full',
    resources: [
      _ExtLink('Play on Lichess', 'https://lichess.org'),
      _ExtLink('Play on Chess.com', 'https://www.chess.com/play'),
    ],
  ),
];

// ─── Week Screen ──────────────────────────────────────────────────────────────

class WeekScreen extends StatefulWidget {
  final int weekNumber;
  const WeekScreen({super.key, required this.weekNumber});

  @override
  State<WeekScreen> createState() => _WeekScreenState();
}

class _WeekScreenState extends State<WeekScreen> {
  late WeekDetail _week;
  List<bool> _completed = [];

  @override
  void initState() {
    super.initState();
    _week = weekDetails[widget.weekNumber - 1];
    _completed = List.filled(_week.dailyTasks.length, false);
    _loadProgress();
  }

  Future<void> _loadProgress() async {
    final prefs = await SharedPreferences.getInstance();
    final key = 'week_${_week.week}_tasks';
    final saved = prefs.getStringList(key);
    if (saved != null && saved.length == _week.dailyTasks.length) {
      setState(() => _completed = saved.map((s) => s == '1').toList());
    }
  }

  Future<void> _toggleTask(int index) async {
    setState(() => _completed[index] = !_completed[index]);
    final prefs = await SharedPreferences.getInstance();
    await prefs.setStringList(
      'week_${_week.week}_tasks',
      _completed.map((b) => b ? '1' : '0').toList(),
    );
  }

  double get _progress {
    if (_completed.isEmpty) return 0;
    return _completed.where((b) => b).length / _completed.length;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: CustomScrollView(
          slivers: [
            _buildAppBar(),
            SliverToBoxAdapter(
                child: Padding(
              padding: const EdgeInsets.all(20),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildProgressCard(),
                  const SizedBox(height: 24),
                  _buildConceptCard(),
                  const SizedBox(height: 24),
                  _buildDailyTasks(),
                  const SizedBox(height: 24),
                  if (_week.keyPositions.isNotEmpty) _buildKeyPositions(),
                  const SizedBox(height: 24),
                  if (_week.tutorialId != null) _buildPracticeButton(),
                  const SizedBox(height: 18),
                  _buildResources(),
                  const SizedBox(height: 32),
                ],
              ),
            )),
          ],
        ),
      ),
    );
  }

  Widget _buildAppBar() {
    return SliverAppBar(
      expandedHeight: 180,
      pinned: true,
      backgroundColor: AppTheme.midnight,
      leading: IconButton(
        icon: const Icon(Icons.arrow_back_rounded, color: Colors.white),
        onPressed: () => context.pop(),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text('Week ${_week.week}',
            style:
                GoogleFonts.fredoka(fontWeight: FontWeight.w700, fontSize: 20)),
        background: Container(
          decoration: BoxDecoration(
            gradient: LinearGradient(
              colors: [
                AppTheme.goldPrimary.withOpacity(0.4),
                AppTheme.midnight
              ],
              begin: Alignment.topCenter,
              end: Alignment.bottomCenter,
            ),
          ),
          child: Center(
              child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const SizedBox(height: 20),
              Text(_week.topic,
                  style: GoogleFonts.fredoka(
                    color: AppTheme.goldPrimary,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  )),
              const SizedBox(height: 6),
              Text('🎯 ${_week.goal}  •  ⏱ ${_week.time}',
                  style: GoogleFonts.baloo2(
                    color: AppTheme.textSecondary,
                    fontSize: 14,
                  )),
            ],
          )),
        ),
      ),
    );
  }

  Widget _buildProgressCard() {
    final pct = (_progress * 100).toInt();
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.2)),
      ),
      child: Column(children: [
        Row(children: [
          Text('📊 Progress',
              style: GoogleFonts.fredoka(
                  color: AppTheme.textPrimary,
                  fontSize: 16,
                  fontWeight: FontWeight.w700)),
          const Spacer(),
          Text('$pct%',
              style: GoogleFonts.fredoka(
                  color: AppTheme.goldPrimary,
                  fontSize: 22,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 12),
        ClipRRect(
          borderRadius: BorderRadius.circular(8),
          child: LinearProgressIndicator(
            value: _progress,
            minHeight: 10,
            backgroundColor: Colors.white10,
            valueColor: const AlwaysStoppedAnimation(AppTheme.goldPrimary),
          ),
        ),
      ]),
    ).animate().fadeIn();
  }

  Widget _buildConceptCard() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.accentPurple.withOpacity(0.2)),
      ),
      child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
        Row(children: [
          const Icon(Icons.lightbulb_rounded,
              color: AppTheme.accentPurple, size: 20),
          const SizedBox(width: 8),
          Text('Key Concept',
              style: GoogleFonts.fredoka(
                  color: AppTheme.accentPurple,
                  fontSize: 14,
                  fontWeight: FontWeight.w700)),
        ]),
        const SizedBox(height: 10),
        Text(_week.conceptTitle,
            style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 8),
        Text(_week.conceptBody,
            style: GoogleFonts.baloo2(
                color: AppTheme.textSecondary, fontSize: 14, height: 1.6)),
      ]),
    ).animate().fadeIn(delay: 100.ms);
  }

  Widget _buildDailyTasks() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('📋 Daily Tasks',
            style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ...List.generate(_week.dailyTasks.length, (i) {
          return GestureDetector(
            onTap: () => _toggleTask(i),
            child: Container(
              margin: const EdgeInsets.only(bottom: 8),
              padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(14),
                border: Border.all(
                    color: _completed[i]
                        ? AppTheme.accentGreen.withOpacity(0.4)
                        : Colors.white.withOpacity(0.05)),
              ),
              child: Row(children: [
                Icon(
                  _completed[i]
                      ? Icons.check_circle_rounded
                      : Icons.radio_button_unchecked,
                  color:
                      _completed[i] ? AppTheme.accentGreen : AppTheme.textMuted,
                  size: 22,
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Text(
                  'Day ${i + 1}: ${_week.dailyTasks[i]}',
                  style: GoogleFonts.baloo2(
                    color: _completed[i]
                        ? AppTheme.textSecondary
                        : AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w500,
                    decoration:
                        _completed[i] ? TextDecoration.lineThrough : null,
                  ),
                )),
              ]),
            ),
          ).animate().fadeIn(delay: (50 * i).ms).slideX(begin: 0.03);
        }),
      ],
    );
  }

  Widget _buildKeyPositions() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('♟ Key Positions',
            style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 12),
        ..._week.keyPositions.map((pos) => Container(
              margin: const EdgeInsets.only(bottom: 10),
              padding: const EdgeInsets.all(14),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(16),
                border:
                    Border.all(color: AppTheme.skyBlue.withOpacity(0.15)),
              ),
              child: Row(children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: AppTheme.skyBlue.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(10),
                  ),
                  child: const Center(
                      child: Icon(Icons.grid_4x4_rounded,
                          color: AppTheme.skyBlue, size: 22)),
                ),
                const SizedBox(width: 12),
                Expanded(
                    child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(pos.label,
                        style: GoogleFonts.baloo2(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w600)),
                    const SizedBox(height: 2),
                    Text(pos.fen,
                        style: TextStyle(
                            color: AppTheme.textMuted,
                            fontFamily: 'monospace',
                            fontSize: 10)),
                  ],
                )),
              ]),
            )),
      ],
    );
  }

  Widget _buildPracticeButton() {
    return SizedBox(
      width: double.infinity,
      height: 56,
      child: ElevatedButton.icon(
        onPressed: () {
          final lesson = tutorialLessons.firstWhere(
            (t) => t.id == _week.tutorialId,
            orElse: () => tutorialLessons.first,
          );
          context.push('/game/play',
              extra: GameRouteExtra(
                config: const GameConfig(
                    mode: GameMode.tutorial, playerColor: 'white'),
                tutorial: lesson,
              ));
        },
        icon: const Icon(Icons.play_arrow_rounded, size: 24),
        label: Text('Practice on Board! 🎮',
            style:
                GoogleFonts.fredoka(fontSize: 16, fontWeight: FontWeight.w600)),
        style: ElevatedButton.styleFrom(
          backgroundColor: AppTheme.goldPrimary,
          foregroundColor: AppTheme.midnight,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        ),
      ),
    ).animate().fadeIn(delay: 200.ms).scale(begin: const Offset(0.95, 0.95));
  }

  Widget _buildResources() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Text('🔗 Resources',
            style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700)),
        const SizedBox(height: 10),
        ..._week.resources.map((r) => GestureDetector(
              onTap: () async {
                final uri = Uri.parse(r.url);
                if (await canLaunchUrl(uri))
                  await launchUrl(uri, mode: LaunchMode.externalApplication);
              },
              child: Container(
                margin: const EdgeInsets.only(bottom: 8),
                padding: const EdgeInsets.all(14),
                decoration: BoxDecoration(
                  gradient: AppTheme.cardGradient,
                  borderRadius: BorderRadius.circular(14),
                  border: Border.all(
                      color: AppTheme.skyBlue.withOpacity(0.15)),
                ),
                child: Row(children: [
                  const Icon(Icons.open_in_new_rounded,
                      color: AppTheme.skyBlue, size: 16),
                  const SizedBox(width: 10),
                  Expanded(
                      child: Text(r.title,
                          style: GoogleFonts.baloo2(
                              color: AppTheme.skyBlue,
                              fontSize: 14,
                              fontWeight: FontWeight.w600))),
                ]),
              ),
            )),
      ],
    );
  }
}
