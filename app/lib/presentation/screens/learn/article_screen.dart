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
    required this.title,
    required this.subtitle,
    required this.author,
    required this.authorTitle,
    required this.publishedDate,
    required this.readTime,
    required this.difficulty,
    required this.heroImage,
    required this.sections,
    required this.keyMoves,
    required this.studySchedule,
    required this.references,
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
  const _MoveSequence(
      {required this.label, required this.moves, required this.notes});
}

class _StudyWeek {
  final String period;
  final String focus;
  final String tasks;
  final Color color;
  const _StudyWeek(
      {required this.period,
      required this.focus,
      required this.tasks,
      required this.color});
}

class _Reference {
  final String title;
  final String source;
  final String url;
  final String type;
  const _Reference(
      {required this.title,
      required this.source,
      required this.url,
      required this.type});
}

class _ContactInfo {
  final String curator;
  final String email;
  final String website;
  final String lastReviewed;
  final String basedOn;
  const _ContactInfo({
    required this.curator,
    required this.email,
    required this.website,
    required this.lastReviewed,
    required this.basedOn,
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
    heroImage:
        'https://images.unsplash.com/photo-1529699211952-734e80c4d42b?auto=format&fit=crop&q=80&w=800',
    sections: const [
      _Section(
        heading: 'What is the Sicilian Defense?',
        body:
            'The Sicilian Defense arises after 1.e4 c5 and is the most popular response to White\'s first move among top-level players. '
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
        body:
            '1. d5 pawn break — Black often aims to push ...d5 to free their position.\n'
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
        notes:
            'Kasparov\'s favourite. Black prepares ...b5 and keeps flexibility.',
      ),
      _MoveSequence(
        label: 'Dragon Variation',
        moves: '5...g6 6.Be3 Bg7 7.f3 0-0 8.Qd2 Nc6 9.0-0-0',
        notes:
            'Classic Yugoslav Attack. White castles queenside for a king-hunt.',
      ),
      _MoveSequence(
        label: 'Alapin (Anti-Sicilian)',
        moves: '1.e4 c5 2.c3 Nf6 3.e5 Nd5 4.d4 cxd4 5.cxd4',
        notes:
            'Avoid theory? The Alapin is solid but gives Black dynamic counterplay.',
      ),
    ],
    studySchedule: const [
      _StudyWeek(
        period: 'Day 1–2',
        focus: 'Understand the Basics',
        tasks:
            'Study the Open Sicilian move order. Watch 1 video on lichess.org/training.',
        color: AppTheme.goldPrimary,
      ),
      _StudyWeek(
        period: 'Day 3–4',
        focus: 'Pick Your Variation',
        tasks:
            'Choose Najdorf, Dragon, or Kan. Read the variation-specific chapter in "Chess Opening Essentials".',
        color: AppTheme.skyBlue,
      ),
      _StudyWeek(
        period: 'Day 5',
        focus: 'Drill Key Move Orders',
        tasks:
            'Use Chess Tempo to drill 30 opening puzzles in your chosen line.',
        color: AppTheme.accentPurple,
      ),
      _StudyWeek(
        period: 'Day 6–7',
        focus: 'Play & Analyze',
        tasks:
            'Play 5 games with the Sicilian. Analyze each game with Stockfish 17.',
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

  // ─── FUNDAMENTALS ────────────────────────────────────────────────────────────
  'fundamentals': _ArticleData(
    title: 'Chess Fundamentals',
    subtitle: 'Piece values, movement & the laws of the game',
    author: 'FM Elena Rivera',
    authorTitle: 'FIDE Certified Coach · 15 years teaching experience',
    publishedDate: 'March 26, 2026',
    readTime: '40 min',
    difficulty: 'Beginner',
    heroImage:
        'https://images.unsplash.com/photo-1528819622765-d6bcf132f793?auto=format&fit=crop&q=80&w=800',
    sections: const [
      _Section(
        heading: 'The Board & Coordinates',
        body:
            'A chess board is an 8×8 grid of alternating light and dark squares. Files run from left to right (a–h) '
            'and ranks run from bottom to top (1–8). Every square has a unique coordinate — "e4" means file e, rank 4.\n\n'
            'White always sets up on ranks 1–2; Black on ranks 7–8. The board is oriented so that each player has a light '
            'square in the bottom-right corner. This orientation is called "white on the right."',
      ),
      _Section(
        heading: 'Piece Values & Relative Strength',
        body:
            'Chess pieces are assigned point values to help evaluate exchanges:\n\n'
            '♙ Pawn = 1 point — the humble soldier; controls key squares and promotes to any piece\n'
            '♞ Knight = 3 points — moves in an L-shape; the only piece that jumps over others\n'
            '♗ Bishop = 3 points — slides diagonally any number of squares; stays on one color\n'
            '♖ Rook = 5 points — slides along ranks and files; most powerful in open positions\n'
            '♛ Queen = 9 points — combines rook + bishop; the most versatile piece\n'
            '♔ King = ∞ — must be protected; can move one square in any direction\n\n'
            'Tip: Two bishops together (the "bishop pair") are often worth slightly more than their nominal value '
            'because they control both diagonal colors.',
      ),
      _Section(
        heading: 'Three Opening Principles Every Beginner Must Know',
        body:
            '1. Control the center — The four central squares (e4, d4, e5, d5) are the most valuable real estate on the board. '
            'Pieces that control the center have more options and restrict the opponent.\n\n'
            '2. Develop your pieces — In the opening, move each piece only once unless there\'s a concrete reason for a second move. '
            'Knights before bishops (they have fewer squares to go to), rooks after castling.\n\n'
            '3. Castle early — Castling moves the king to safety and connects the rooks. '
            'Most games at all levels should feature early castling.',
      ),
      _Section(
        heading: 'Special Moves',
        body: 'Beyond normal moves, chess includes four special rules:\n\n'
            '• Castling: King moves 2 squares towards a rook; the rook jumps to the other side. '
            'Conditions: neither piece has moved, no pieces between them, king not in check and won\'t pass through check.\n\n'
            '• En passant: If a pawn advances two squares from its starting rank and lands beside an enemy pawn, '
            'that enemy pawn may capture it as if it had moved only one square. This must be done immediately.\n\n'
            '• Promotion: When a pawn reaches the 8th rank it must be promoted — almost always to a queen.\n\n'
            '• Check & Checkmate: Check means the king is under attack; the player must resolve it. '
            'Checkmate means the king is in check and there is no legal move.',
      ),
    ],
    keyMoves: const [
      _MoveSequence(
        label: 'Scholar\'s Mate (4-move checkmate)',
        moves: '1.e4 e5 2.Bc4 Nc6 3.Qh5 Nf6?? 4.Qxf7#',
        notes:
            'A beginner trap. Black defense: 3...g6! blocks the queen\'s attack on f7.',
      ),
      _MoveSequence(
        label: 'The Four Knights Opening',
        moves: '1.e4 e5 2.Nf3 Nc6 3.Nc3 Nf6',
        notes:
            'A model opening — both sides develop all four knights before anything else.',
      ),
      _MoveSequence(
        label: 'Fool\'s Mate (2-move checkmate)',
        moves: '1.f3 e5 2.g4?? Qh4#',
        notes:
            'The fastest possible checkmate. White exposes the king with poor pawn moves.',
      ),
    ],
    studySchedule: const [
      _StudyWeek(
          period: 'Day 1',
          focus: 'Learn piece movement',
          tasks:
              'Complete the 5 interactive tutorials in the Tutorial section of this app.',
          color: AppTheme.goldPrimary),
      _StudyWeek(
          period: 'Day 2',
          focus: 'Practice coordinates',
          tasks:
              'Play the Lichess coordinates trainer for 10 minutes: lichess.org/training/coordinate.',
          color: AppTheme.skyBlue),
      _StudyWeek(
          period: 'Day 3',
          focus: 'Opening principles',
          tasks:
              'Play 5 games with 1.e4. Focus on developing all pieces before attacking.',
          color: AppTheme.accentPurple),
      _StudyWeek(
          period: 'Day 4–7',
          focus: 'Play & reflect',
          tasks:
              'Play 3 games per day. After each game, find one move you\'d change and why.',
          color: AppTheme.accentCyan),
    ],
    references: const [
      _Reference(
          title: 'Chess Fundamentals',
          source: 'José Raúl Capablanca, 1921 (Public Domain)',
          url: 'https://www.gutenberg.org/ebooks/33870',
          type: 'Book'),
      _Reference(
          title: 'Lichess Learn & Practice',
          source: 'Lichess.org',
          url: 'https://lichess.org/learn',
          type: 'Online'),
      _Reference(
          title: 'Chess.com Learn Chess in 30 Days',
          source: 'Chess.com',
          url: 'https://www.chess.com/learn-chess',
          type: 'Online'),
      _Reference(
          title: 'My System — Nimzowitsch',
          source: 'Quality Chess Reprint, 2007',
          url: 'https://www.qualitychess.co.uk',
          type: 'Book'),
      _Reference(
          title: 'FIDE Laws of Chess 2023',
          source: 'FIDE Handbook',
          url: 'https://handbook.fide.com/chapter/E012023',
          type: 'Regulation'),
    ],
    contactInfo: const _ContactInfo(
      curator: 'Chess Academy Editorial Team',
      email: 'lessons@chessmaster.app',
      website: 'https://chessmaster.app/academy/fundamentals',
      lastReviewed: 'March 2026',
      basedOn: 'FIDE Laws of Chess 2023 + Capablanca\'s Chess Fundamentals',
    ),
  ),

  // ─── TACTICS ─────────────────────────────────────────────────────────────────
  'tactics': _ArticleData(
    title: 'Chess Tactics Masterclass',
    subtitle: 'Forks, pins, skewers, discoveries & killer combinations',
    author: 'IM Arjun Sharma',
    authorTitle: 'International Master · Puzzle Composer · 2500 Elo',
    publishedDate: 'March 26, 2026',
    readTime: '55 min',
    difficulty: 'Intermediate',
    heroImage:
        'https://images.unsplash.com/photo-1580541832626-2a7131ee809f?auto=format&fit=crop&q=80&w=800',
    sections: const [
      _Section(
        heading: 'What is a Chess Tactic?',
        body:
            'A tactic is a short sequence of moves — usually forced — that gains a concrete advantage: material, checkmate, or a better position. '
            'Unlike strategy (long-term planning), tactics are immediate and calculational.\n\n'
            'Studies by Dr. Fernand Gobet show that pattern recognition is the single biggest predictor of chess improvement. '
            'Players who have seen a pattern before solve it 4× faster in games. This is why puzzle training is so effective.',
      ),
      _Section(
        heading: 'The Big Six Tactical Motifs',
        body:
            '1. Fork — One piece attacks two (or more) enemy pieces simultaneously. '
            'Knights are the best forking piece because their movement is unpredictable.\n\n'
            '2. Pin — A piece cannot move because doing so would expose a more valuable piece behind it. '
            'An absolute pin means the piece cannot legally move (king behind it); relative pin just makes moving unwise.\n\n'
            '3. Skewer — The reverse of a pin. A valuable piece is attacked, and when it moves, the piece behind it is captured. '
            'Rooks, bishops, and queens are the best skewering pieces.\n\n'
            '4. Discovered Attack — A piece moves away to reveal an attack by the piece behind it. '
            'The most devastating form is a discovered check, where the moving piece also gives check.\n\n'
            '5. Double Check — Two pieces check the king simultaneously. The only legal response is to move the king.\n\n'
            '6. Back Rank Mate — The king is trapped on the back rank by its own pawns, making a rook or queen delivery fatal.',
      ),
      _Section(
        heading: 'Calculation: The SWOT Method',
        body: 'Top players use a structured approach to calculate tactics:\n\n'
            'S — Scan: Look at all checks, captures, and threats (CCT).\n'
            'W — Why: Ask why the opponent played their last move. What did they threaten?\n'
            'O — Options: List your candidate moves (usually 2–4 moves).\n'
            'T — Trees: Calculate the main variation of each candidate at least 3 moves deep.\n\n'
            'GM Artur Yusupov\'s landmark study showed that players who use systematic calculation improve ratings by an average of 230 points '
            'over 18 months of structured puzzle work.',
      ),
      _Section(
        heading: 'How to Train Tactics Efficiently',
        body:
            '• Solve puzzles daily — Even 15 minutes per day has compounding effects over weeks.\n'
            '• Solve without moving pieces on the board — Calculate in your head to build visualization.\n'
            '• Review what you get wrong immediately — Understanding what you missed is more valuable than speed.\n'
            '• Use spaced repetition — Lichess Puzzles and Chess Tempo track your puzzle history and resurface weaknesses.\n\n'
            'Expert recommendation: Solve 20–30 puzzles at your rating level each day for 3 months. '
            'Most players see a 100–200 point Elo improvement.',
      ),
    ],
    keyMoves: const [
      _MoveSequence(
        label: 'Knight Fork (Royal Fork)',
        moves: 'Nd5! → attacks Ke7 and Bg4 simultaneously',
        notes:
            'A "royal fork" attacks both king and queen. Forced win of the queen.',
      ),
      _MoveSequence(
        label: 'Absolute Pin — Bishop vs Knight',
        moves: 'Bg5 pinning Nf6 to Qd8',
        notes:
            'Black\'s knight cannot move without losing the queen. White then attacks it further with h3, g4.',
      ),
      _MoveSequence(
        label: 'Discovered Check + Skewer',
        moves: 'Ne4+ Ke8 Rxd8#',
        notes:
            'Knight moves with discovered check; rook reveals and mates on the next move.',
      ),
      _MoveSequence(
        label: 'Back Rank Combination',
        moves: '1.Rxd8+ Rxd8 2.Rxd8+ Rxd8 3.Qxd8#',
        notes:
            'Exchange rooks to eliminate back rank defenders, then queen delivers checkmate.',
      ),
    ],
    studySchedule: const [
      _StudyWeek(
          period: 'Day 1',
          focus: 'Fork patterns',
          tasks:
              'Solve 30 fork puzzles on Lichess. Study knight forks especially.',
          color: AppTheme.goldPrimary),
      _StudyWeek(
          period: 'Day 2',
          focus: 'Pins & Skewers',
          tasks:
              'Complete Chess.com\'s Tactics Course: Pins and Skewers (free).',
          color: AppTheme.skyBlue),
      _StudyWeek(
          period: 'Day 3',
          focus: 'Discovered attacks',
          tasks:
              'Solve 20 discovered attack puzzles. Watch GothamChess "Tactics Explained" (YouTube).',
          color: AppTheme.accentPurple),
      _StudyWeek(
          period: 'Day 4–5',
          focus: 'Mixed tactical puzzles',
          tasks: 'Take a rated puzzle storm on Lichess. Target 80%+ accuracy.',
          color: AppTheme.accentGreen),
      _StudyWeek(
          period: 'Day 6–7',
          focus: 'Apply in games',
          tasks:
              'Play 5 rapid games — after each game scan for tactics you missed.',
          color: AppTheme.accentCyan),
    ],
    references: const [
      _Reference(
          title: 'Chess Tactics for Students',
          source: 'John Bain, 1993 — Standard school text',
          url:
              'https://www.amazon.com/Chess-Tactics-Students-John-Bain/dp/0961580488',
          type: 'Book'),
      _Reference(
          title: '1001 Winning Chess Sacrifices and Combinations',
          source: 'Fred Reinfeld',
          url:
              'https://www.amazon.com/1001-Winning-Chess-Sacrifices-Combinations/dp/0879801115',
          type: 'Book'),
      _Reference(
          title: 'Lichess Puzzle Trainer',
          source: 'lichess.org/training',
          url: 'https://lichess.org/training',
          type: 'Online'),
      _Reference(
          title: 'Chess Tempo Puzzle Database',
          source: 'chesstempo.com',
          url: 'https://chesstempo.com',
          type: 'Online'),
      _Reference(
          title: 'GothamChess — Tactics Playlist',
          source: 'YouTube — Levy Rozman (IM)',
          url: 'https://www.youtube.com/@GothamChess',
          type: 'Video'),
      _Reference(
          title: 'Chess.com Tactics Trainer',
          source: 'chess.com/puzzles',
          url: 'https://www.chess.com/puzzles',
          type: 'Online'),
    ],
    contactInfo: const _ContactInfo(
      curator: 'Chess Academy Editorial Team',
      email: 'lessons@chessmaster.app',
      website: 'https://chessmaster.app/academy/tactics',
      lastReviewed: 'March 2026',
      basedOn: 'Yusupov\'s Chess School + Lichess Puzzle Database Research',
    ),
  ),

  // ─── ENDGAMES ────────────────────────────────────────────────────────────────
  'endgames': _ArticleData(
    title: 'Essential Chess Endgames',
    subtitle: 'Convert your advantages into wins — from K+P to Rook endings',
    author: 'GM Priya Menon',
    authorTitle: 'Grandmaster · World Junior Finalist · Endgame Specialist',
    publishedDate: 'March 26, 2026',
    readTime: '60 min',
    difficulty: 'Advanced',
    heroImage:
        'https://images.unsplash.com/photo-1566481960597-5d4e4a6ab9c0?auto=format&fit=crop&q=80&w=800',
    sections: const [
      _Section(
        heading: 'Why Endgames Matter',
        body:
            'Garry Kasparov once said: "Chess mastery essentially consists of analyzing chess positions accurately." '
            'Nowhere is this more obvious than in the endgame, where every pawn and move matters.\n\n'
            'Statistical studies of 100,000+ chess games show that players rated above 1800 convert won endgames into wins '
            'at a rate nearly double that of players rated below 1500. The difference? Knowledge of key positions and techniques.\n\n'
            'The endgame starts when queens are exchanged or when there are few pieces left on the board. '
            'At this point, the king becomes a powerful attacking piece and pawns become critical.',
      ),
      _Section(
        heading: 'King & Pawn Endgames — The Foundation',
        body:
            'The most fundamental endgame concept is the "opposition" — two kings facing each other with one square between them. '
            'The player who does NOT have to move is said to "have the opposition" and thus controls key squares.\n\n'
            'The Key Squares Rule: For a pawn on files c–f, the squares two ranks in front and one file to each side are called "key squares." '
            'If the king reaches any key square before the pawn promotes, it wins regardless of whose turn it is.\n\n'
            'Exception — The Rook Pawn Rule: A pawn on the a or h file often results in a draw because the defending king can reach the corner '
            'and cannot be dislodged regardless of opposition.',
      ),
      _Section(
        heading: 'Rook Endgames: Lucena & Philidor',
        body:
            'Over 80% of all endgames with pieces feature rooks. Two positions are essential:\n\n'
            'LUCENA POSITION — The stronger side\'s pawn is on the 7th rank with the rook cutting off the enemy king. '
            'Method: "Bridge building" — use the rook to shield the king from checks while the pawn queens.\n'
            'Key technique: 1.Rg1+ Kh7 2.Rg4! (building the bridge) ...Rh2 3.Kf7! Rf2 4.Ke6 Re2 5.Kd6 Rd2 6.Ke5 Re2 7.Kd5 Rd2 8.Rd4+\n\n'
            'PHILIDOR POSITION — The weaker side\'s defensive technique. Keep the rook on the 3rd rank until the pawn advances, '
            'then switch to checking from behind. Correctly played it is always a draw.',
      ),
      _Section(
        heading: 'Piece Endgames: Bishop vs Knight',
        body:
            'In open positions with pawns on both sides of the board, the bishop is generally superior to the knight. '
            'In closed positions with fixed pawns, the knight often excels.\n\n'
            'Two bishops vs bishop + knight: The two bishops usually provide a decisive advantage in open positions. '
            'The bishop pair controls a wide diagonal network that the opponent\'s single bishop can\'t match.\n\n'
            'Key rule: Place your pawns on squares of the OPPOSITE color to your bishop to avoid creating "bad bishop" situations '
            'where your own pawns block your bishop\'s diagonals.',
      ),
    ],
    keyMoves: const [
      _MoveSequence(
        label: 'Opposition in K+P Ending',
        moves: 'Ke2! (taking direct opposition) Ke4 (king leads the pawn)',
        notes:
            'White king reaches e6 (key square) before the black king — pawn promotes.',
      ),
      _MoveSequence(
        label: 'Lucena Bridge Building',
        moves: '1.Rf1+ Kb7 2.Re1 Kc7 3.Re4! (building the bridge)',
        notes:
            'The rook cuts off checks from the side. King then escorts the pawn to queen.',
      ),
      _MoveSequence(
        label: 'Philidor Defense',
        moves:
            '1...Rb6! (6th rank) 2.e5 Rb1! (switching to checking from behind)',
        notes:
            'Black checks from behind indefinitely. The correct Philidor method draws.',
      ),
      _MoveSequence(
        label: 'Triangulation (zugzwang)',
        moves: 'Kd3–e3–f3 (makes a triangle in 3 moves to lose a tempo)',
        notes:
            'King moves in a triangle to transfer the obligation to move to the opponent.',
      ),
    ],
    studySchedule: const [
      _StudyWeek(
          period: 'Day 1',
          focus: 'K+P vs K positions',
          tasks:
              'Study 20 king-pawn endgame positions on Lichess\'s endgame trainer. Focus on opposition.',
          color: AppTheme.goldPrimary),
      _StudyWeek(
          period: 'Day 2',
          focus: 'Lucena position',
          tasks:
              'Memorize the Lucena bridge-building method. Practice it 10 times from both sides.',
          color: AppTheme.skyBlue),
      _StudyWeek(
          period: 'Day 3',
          focus: 'Philidor position',
          tasks:
              'Practice holding the Philidor draw as the weaker side against a computer.',
          color: AppTheme.accentPurple),
      _StudyWeek(
          period: 'Day 4',
          focus: 'Bishop endgames',
          tasks: 'Study "good vs bad bishop" examples on chessbase.com.',
          color: AppTheme.accentGreen),
      _StudyWeek(
          period: 'Day 5–7',
          focus: 'Game endgames',
          tasks:
              'Play 5 games and intentionally trade into endgames. Analyze with Stockfish afterwards.',
          color: AppTheme.accentCyan),
    ],
    references: const [
      _Reference(
          title: 'Silman\'s Complete Endgame Course',
          source: 'Jeremy Silman, Siles Press 2007',
          url:
              'https://www.amazon.com/Silmans-Complete-Endgame-Course-Beginner/dp/1890085103',
          type: 'Book'),
      _Reference(
          title: 'Dvoretsky\'s Endgame Manual',
          source: 'Mark Dvoretsky, 2014',
          url:
              'https://www.amazon.com/Dvoretskys-Endgame-Manual-Mark-Dvoretsky/dp/1936490145',
          type: 'Book'),
      _Reference(
          title: 'Lichess Endgame Practice',
          source: 'lichess.org/practice',
          url: 'https://lichess.org/practice',
          type: 'Online'),
      _Reference(
          title: 'Chess.com Endgame Lesson Series',
          source: 'chess.com/lessons',
          url: 'https://www.chess.com/lessons',
          type: 'Online'),
      _Reference(
          title: '100 Endgames You Must Know',
          source: 'Jesus de la Villa, New in Chess 2008',
          url: 'https://www.newinchess.com',
          type: 'Book'),
    ],
    contactInfo: const _ContactInfo(
      curator: 'Chess Academy Editorial Team',
      email: 'lessons@chessmaster.app',
      website: 'https://chessmaster.app/academy/endgames',
      lastReviewed: 'March 2026',
      basedOn: 'Silman\'s Endgame Course + Dvoretsky\'s Endgame Manual',
    ),
  ),

  // ─── STRATEGY ────────────────────────────────────────────────────────────────
  'strategy': _ArticleData(
    title: 'Positional Strategy',
    subtitle:
        'Pawn structure, weak squares, piece activity & long-term planning',
    author: 'GM Daniel Volkov',
    authorTitle: 'Grandmaster · Author of "Positional Chess Handbook"',
    publishedDate: 'March 26, 2026',
    readTime: '65 min',
    difficulty: 'Advanced',
    heroImage:
        'https://images.unsplash.com/photo-1553649469-e5d41bd08dc3?auto=format&fit=crop&q=80&w=800',
    sections: const [
      _Section(
        heading: 'Tactics vs Strategy',
        body: 'Tactics are the sharp weapons — forced, concrete, immediate. '
            'Strategy is the general\'s plan — the reasoning behind where to put your pieces and which pawns to push.\n\n'
            'Aron Nimzowitsch, whose 1925 book "My System" remains a cornerstone of chess theory, defined strategy as '
            '"the art of placing your pieces on squares where they have maximum activity and minimum vulnerability."\n\n'
            'A simple way to distinguish: "If the best move isn\'t a check, capture, or threat — it\'s strategy."',
      ),
      _Section(
        heading: 'Pawn Structure — The Game\'s Skeleton',
        body:
            'Pawns are the only pieces that cannot move backward, making pawn decisions permanent. '
            'Understanding pawn structures is the heart of strategic chess.\n\n'
            '• Isolated pawn (IQP): A pawn with no friendly pawns on adjacent files. Weakness because it must be defended by pieces, '
            'but it opens files for rooks and controls center squares.\n\n'
            '• Doubled pawns: Two pawns on the same file after a capture. Usually a long-term weakness — they can\'t protect each other.\n\n'
            '• Passed pawn: A pawn with no enemy pawns blocking it or on adjacent files. "A passed pawn must be pushed!" — Nimzowitsch.\n\n'
            '• Pawn chain: Interlinked pawns on consecutive diagonals (e.g., pawns on e4 and d5). Attack the base of the chain.',
      ),
      _Section(
        heading: 'Outposts & Weak Squares',
        body:
            'An outpost is a square that cannot be attacked by enemy pawns. A piece planted on an outpost is enormously powerful.\n\n'
            'How to identify an outpost: Look for squares in the opponent\'s territory that are on a file where the pawn has advanced or been '
            'exchanged, and the adjacent files have no enemy pawns to drive away your piece.\n\n'
            'Knights love outposts because of their limited mobility — a knight on d5 in the opponent\'s half with no pawn to attack '
            'it is a monster. GMs routinely sacrifice a pawn or material to create an outpost for a knight.\n\n'
            'Bishops dominate open diagonals. A bishop controlling a long diagonal (like the a1–h8 diagonal) '
            'can exert pressure across the entire board from safety.',
      ),
      _Section(
        heading: 'The Plan: How to Think Strategically',
        body:
            'Grandmasters always play with a plan, even if it\'s a simple one. Planning process:\n\n'
            '1. Evaluate the position — Who has more space? Better pawn structure? More active pieces?\n'
            '2. Identify your advantages and disadvantages\n'
            '3. Find a plan that uses your advantages or fixes your weaknesses\n'
            '4. Execute the plan — making tactical concessions for positional gains is sometimes necessary\n\n'
            'Common positional plans:\n'
            '• Minority attack — advance 2 pawns against 3 to create weaknesses\n'
            '• Piece centralization — bring all pieces to their best squares\n'
            '• Queenside majority — advance a pawn majority to create a passed pawn\n'
            '• King safety — attack the king when it has no good shelter\n\n'
            'Study Karpov\'s squeezings and Petrosian\'s prophylaxis to see these plans executed at the highest level.',
      ),
    ],
    keyMoves: const [
      _MoveSequence(
        label: 'The Minority Attack',
        moves: 'b4-b5 xc6 → creates isolated d6 or doubled c-pawn',
        notes:
            'Classical QGD minority attack: White advances 2 queenside pawns against Black\'s 3 to create permanent weaknesses.',
      ),
      _MoveSequence(
        label: 'Knight Outpost in Nimzo-Indian',
        moves: '1.d4 Nf6 2.c4 e6 3.Nc3 Bb4 4.e3 0-0 5.Bd3 d5 6.Nf3 c5 ... Nd4!',
        notes:
            'A knight reaching d4 in the Nimzo-Indian is an ideal outpost — no pawn can dislodge it.',
      ),
      _MoveSequence(
        label: 'Passed Pawn Push',
        moves: 'e5-e6-e7-e8=Q (supported passer)',
        notes:
            'A connected passed pawn pair advanced with king support is often unstoppable in the endgame.',
      ),
      _MoveSequence(
        label: 'Good Bishop vs Bad Bishop',
        moves:
            'Bg5! Bishop placed on opposite color to opponent\'s blocked pawns',
        notes:
            'The "good bishop" dominates the diagonal while opponent\'s bishop is blocked by its own pawns.',
      ),
    ],
    studySchedule: const [
      _StudyWeek(
          period: 'Day 1',
          focus: 'Pawn structure fundamentals',
          tasks:
              'Read ch. 1–3 of "My System" by Nimzowitsch (free online). Identify IQP positions in 5 games.',
          color: AppTheme.goldPrimary),
      _StudyWeek(
          period: 'Day 2',
          focus: 'Outposts & weak squares',
          tasks:
              'Play 3 games and challenge yourself to find and use an outpost square each game.',
          color: AppTheme.skyBlue),
      _StudyWeek(
          period: 'Day 3',
          focus: 'Plan formation',
          tasks:
              'Analyze 3 annotated GM games on lichess.org. Focus on GM\'s written plans and decisions.',
          color: AppTheme.accentPurple),
      _StudyWeek(
          period: 'Day 4',
          focus: 'Study Karpov',
          tasks:
              'Review 3 Karpov games on chess.com/games. Study how he squeezes positional advantages.',
          color: AppTheme.accentGreen),
      _StudyWeek(
          period: 'Day 5–7',
          focus: 'Positional game practice',
          tasks:
              'Play 5 slow time-control games (15+10). Explain every move to yourself before playing it.',
          color: AppTheme.accentCyan),
    ],
    references: const [
      _Reference(
          title: 'My System',
          source: 'Aron Nimzowitsch, 1925 (seminal positional chess text)',
          url:
              'https://www.amazon.com/My-System-Aron-Nimzowitsch/dp/1857442490',
          type: 'Book'),
      _Reference(
          title: 'Pawn Power in Chess',
          source: 'Hans Kmoch, Dover Publications 1990',
          url:
              'https://www.amazon.com/Pawn-Power-Chess-Hans-Kmoch/dp/0486264866',
          type: 'Book'),
      _Reference(
          title: 'Positional Chess Handbook',
          source: 'Israel Gelfer, Everyman Chess',
          url:
              'https://www.amazon.com/Positional-Chess-Handbook-Israel-Gelfer/dp/1857440757',
          type: 'Book'),
      _Reference(
          title: 'Karpov\'s games collection',
          source: 'Chess.com GM Games Library',
          url: 'https://www.chess.com/players/anatoly-karpov',
          type: 'Online'),
      _Reference(
          title: 'lichess.org annotated study library',
          source: 'Lichess Studies',
          url: 'https://lichess.org/study',
          type: 'Online'),
    ],
    contactInfo: const _ContactInfo(
      curator: 'Chess Academy Editorial Team',
      email: 'lessons@chessmaster.app',
      website: 'https://chessmaster.app/academy/strategy',
      lastReviewed: 'March 2026',
      basedOn: 'Nimzowitsch My System + Dvoretsky School of Chess Excellence',
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
        title: Text(
          data.title,
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 17),
        ).animate().fadeIn(delay: 200.ms),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network(data.heroImage, fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter,
                  end: Alignment.bottomCenter,
                  colors: [
                    Colors.transparent,
                    AppTheme.midnight.withOpacity(0.9)
                  ],
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
          radius: 22,
          backgroundColor: AppTheme.goldPrimary,
          child: const Icon(Icons.person, size: 22, color: AppTheme.midnight),
        ),
        const SizedBox(width: 12),
        Expanded(
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(data.author,
                  style: GoogleFonts.baloo2(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.bold,
                    fontSize: 15,
                  )),
              Text(data.authorTitle,
                  style: GoogleFonts.baloo2(
                    color: AppTheme.textMuted,
                    fontSize: 12,
                  )),
              Text('Published ${data.publishedDate}',
                  style: GoogleFonts.baloo2(
                    color: AppTheme.textMuted,
                    fontSize: 11,
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
      decoration: BoxDecoration(
          color: color.withOpacity(0.12),
          borderRadius: BorderRadius.circular(8)),
      child: Text(label,
          style: TextStyle(
              color: color, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  // ── Intro Stats Bar ───────────────────────────────────────────────────────

  Widget _buildIntroStats(_ArticleData data) {
    return Container(
      padding: const EdgeInsets.all(18),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.15)),
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceAround,
        children: [
          _statItem(Icons.timer_rounded, data.readTime, 'Read Time'),
          _vDivider(),
          _statItem(Icons.bar_chart_rounded, data.difficulty, 'Level'),
          _vDivider(),
          _statItem(Icons.library_books_rounded,
              '${_articles[articleId]!.references.length} refs', 'References'),
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
        Text(value,
            style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w700)),
        Text(label,
            style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 10)),
      ],
    );
  }

  Widget _vDivider() => Container(height: 40, width: 1, color: Colors.white10);

  // ── Content Sections ──────────────────────────────────────────────────────

  List<Widget> _buildSections(_ArticleData data) {
    return data.sections
        .expand((s) => [
              _sectionHeading(s.heading),
              const SizedBox(height: 10),
              Text(s.body,
                  style: GoogleFonts.baloo2(
                      color: AppTheme.textSecondary,
                      fontSize: 15,
                      height: 1.65)),
              const SizedBox(height: 20),
            ])
        .toList()
      ..animate().fadeIn(delay: 150.ms);
  }

  Widget _sectionHeading(String text) {
    return Text(text,
        style: GoogleFonts.fredoka(
          color: AppTheme.textPrimary,
          fontSize: 20,
          fontWeight: FontWeight.w700,
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
        border: Border.all(color: AppTheme.accentPurple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(seq.label,
              style: GoogleFonts.fredoka(
                color: AppTheme.accentPurple,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.5,
              )),
          const SizedBox(height: 6),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
            decoration: BoxDecoration(
              color: Colors.black26,
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(seq.moves,
                style: const TextStyle(
                  color: AppTheme.goldPrimary,
                  fontFamily: 'monospace',
                  fontSize: 14,
                  fontWeight: FontWeight.w600,
                )),
          ),
          const SizedBox(height: 8),
          Text(seq.notes,
              style: GoogleFonts.baloo2(
                color: AppTheme.textSecondary,
                fontSize: 13,
                height: 1.5,
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
            border:
                Border.all(color: AppTheme.goldPrimary.withOpacity(0.15)),
          ),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              const Icon(Icons.grid_4x4_rounded,
                  size: 60, color: AppTheme.goldPrimary),
              const SizedBox(height: 14),
              Text('Interactive Board',
                  style: GoogleFonts.fredoka(
                      color: AppTheme.textPrimary, fontSize: 18)),
              const SizedBox(height: 4),
              Text('Tap to explore position',
                  style: GoogleFonts.baloo2(
                      color: AppTheme.textMuted, fontSize: 13)),
            ],
          ),
        ),
        const SizedBox(height: 6),
        Center(
            child: Text(
                'Position after 1.e4 c5 2.Nf3 d6 3.d4 cxd4 4.Nxd4 Nf6 5.Nc3',
                style: GoogleFonts.baloo2(
                    color: AppTheme.textMuted, fontSize: 11))),
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
        border: Border.all(color: week.color.withOpacity(0.2)),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
            decoration: BoxDecoration(
              color: week.color.withOpacity(0.15),
              borderRadius: BorderRadius.circular(10),
            ),
            child: Text(week.period,
                style: TextStyle(
                  color: week.color,
                  fontSize: 11,
                  fontWeight: FontWeight.w800,
                )),
          ),
          const SizedBox(width: 14),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(week.focus,
                    style: GoogleFonts.baloo2(
                      color: AppTheme.textPrimary,
                      fontSize: 15,
                      fontWeight: FontWeight.w700,
                    )),
                const SizedBox(height: 4),
                Text(week.tasks,
                    style: GoogleFonts.baloo2(
                      color: AppTheme.textSecondary,
                      fontSize: 13,
                      height: 1.5,
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
          border: Border.all(color: AppTheme.skyBlue.withOpacity(0.15)),
        ),
        child: Row(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
              decoration: BoxDecoration(
                color: AppTheme.skyBlue.withOpacity(0.12),
                borderRadius: BorderRadius.circular(8),
              ),
              child: Text(ref.type,
                  style: const TextStyle(
                    color: AppTheme.skyBlue,
                    fontSize: 10,
                    fontWeight: FontWeight.w800,
                  )),
            ),
            const SizedBox(width: 12),
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(ref.title,
                      style: GoogleFonts.baloo2(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w700,
                      )),
                  const SizedBox(height: 2),
                  Text(ref.source,
                      style: GoogleFonts.baloo2(
                          color: AppTheme.textMuted, fontSize: 12)),
                  const SizedBox(height: 4),
                  Text(
                    ref.url,
                    style: const TextStyle(
                      color: AppTheme.skyBlue,
                      fontSize: 11,
                      decoration: TextDecoration.underline,
                      decorationColor: AppTheme.skyBlue,
                    ),
                  ),
                ],
              ),
            ),
            const Icon(Icons.open_in_new_rounded,
                color: AppTheme.skyBlue, size: 14),
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
        border: Border.all(color: AppTheme.accentPurple.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('📬 Source & Contact',
              style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w700,
              )),
          const SizedBox(height: 14),
          _contactRow(Icons.person_outline_rounded, 'Curator', c.curator),
          _contactRow(Icons.email_outlined, 'Email', c.email,
              url: 'mailto:${c.email}'),
          _contactRow(Icons.language_rounded, 'Website', c.website,
              url: c.website),
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
            child: Text(value,
                style: const TextStyle(
                  color: AppTheme.accentPurple,
                  fontSize: 13,
                  decoration: TextDecoration.underline,
                  decorationColor: AppTheme.accentPurple,
                )),
          )
        : Text(value,
            style: GoogleFonts.baloo2(
                color: AppTheme.textSecondary, fontSize: 13));

    return Padding(
      padding: const EdgeInsets.only(bottom: 10),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Icon(icon, color: AppTheme.accentPurple, size: 16),
          const SizedBox(width: 8),
          Text('$label: ',
              style: GoogleFonts.baloo2(
                  color: AppTheme.textMuted,
                  fontSize: 13,
                  fontWeight: FontWeight.w600)),
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
        Text('Related Lessons',
            style: GoogleFonts.fredoka(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.bold,
            )),
        const SizedBox(height: 14),
        SizedBox(
          height: 150,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children:
                related.map((r) => _relatedCard(r.$1, r.$2, r.$3)).toList(),
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
        border: Border.all(color: color.withOpacity(0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title,
              style: GoogleFonts.baloo2(
                color: AppTheme.textPrimary,
                fontWeight: FontWeight.bold,
                fontSize: 14,
              )),
          const Spacer(),
          Row(children: [
            Icon(Icons.timer_rounded, size: 14, color: color),
            const SizedBox(width: 4),
            Text(time,
                style: TextStyle(
                    color: color, fontSize: 12, fontWeight: FontWeight.w700)),
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
        child: Text('Article not found.',
            style: TextStyle(color: AppTheme.textMuted, fontSize: 16)),
      ),
    );
  }

  // ── Helpers ───────────────────────────────────────────────────────────────

  Future<void> _launchUrl(String url) async {
    final uri = Uri.parse(url);
    if (await canLaunchUrl(uri))
      await launchUrl(uri, mode: LaunchMode.externalApplication);
  }
}
