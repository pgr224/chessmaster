import 'package:equatable/equatable.dart';

class TutorialLesson extends Equatable {
  final String id;
  final String title;
  final String description;
  final String initialFEN;
  final List<TutorialStep> steps;

  const TutorialLesson({
    required this.id,
    required this.title,
    required this.description,
    required this.initialFEN,
    required this.steps,
  });

  @override
  List<Object?> get props => [id, title, description, initialFEN, steps];
}

class TutorialStep extends Equatable {
  final String text;
  final String? expectedMove; // e.g., 'e2e4'
  final String? successMessage;
  final String? hintText; // persistent hint shown under instruction
  final bool isCompletion;

  const TutorialStep({
    required this.text,
    this.expectedMove,
    this.successMessage,
    this.hintText,
    this.isCompletion = false,
  });

  @override
  List<Object?> get props =>
      [text, expectedMove, successMessage, hintText, isCompletion];
}

final List<TutorialLesson> tutorialLessons = [
  // ═══════════════════════════════════════════
  // BEGINNER 1: Pawn Mastery — 4 interactive moves
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'beginner1',
    title: '♟️ Pawn Mastery',
    description: 'Learn how pawns move, capture and control the center.',
    initialFEN: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    steps: [
      TutorialStep(
        text:
            'Welcome! Pawns are the soul of chess. They move forward one square, but can move two squares from their starting position.\n\n👉 Move your e-pawn from e2 to e4.',
        expectedMove: 'e2e4',
        hintText: 'Tap the pawn on e2, then tap the e4 square.',
        successMessage:
            '✨ Excellent! You\'ve seized the center. Controlling e4 and d4 is the foundation of every opening.',
      ),
      TutorialStep(
        text:
            'Great start! Now strengthen your center by pushing the d-pawn.\n\n👉 Move your d-pawn from d2 to d4.',
        expectedMove: 'd2d4',
        hintText: 'Tap the pawn on d2, then tap d4.',
        successMessage:
            '🎯 Perfect! Two pawns side by side in the center form a powerful "pawn duo." They control 4 key squares: c5, d5, e5, f5.',
      ),
      TutorialStep(
        text:
            'Now let\'s advance a flank pawn. Push a2 to a3 — this creates "luft" (breathing room) and prevents enemy pieces from landing on b4.\n\n👉 Move a2 to a3.',
        expectedMove: 'a2a3',
        hintText: 'Tap the pawn on a2, then tap a3.',
        successMessage:
            '👍 Nice! Small pawn moves like this prevent back-rank tricks and control important squares.',
      ),
      TutorialStep(
        text:
            'Lesson complete! You\'ve learned:\n• Pawns move forward 1 square (or 2 from start)\n• Center pawns (e4, d4) are the most important\n• Flank pawns create useful space\n\n🎓 Ready for the next lesson!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // BEGINNER 2: Knight's Dance — 4 moves
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'beginner2',
    title: '♞ Knight\'s Dance',
    description: 'Master the unique L-shaped knight movement.',
    initialFEN: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1',
    steps: [
      TutorialStep(
        text:
            'Knights move in an "L" shape: 2 squares in one direction and 1 square perpendicular. They\'re the only piece that can jump over others!\n\n👉 Develop your king\'s knight from g1 to f3.',
        expectedMove: 'g1f3',
        hintText: 'Tap the knight on g1, then tap f3.',
        successMessage:
            '⚡ Great! The knight on f3 attacks the center squares e5 and d4.',
      ),
      TutorialStep(
        text:
            'Now develop the other knight. Knights are strongest in the center and weakest on the edge ("A knight on the rim is dim!").\n\n👉 Move your queen\'s knight from b1 to c3.',
        expectedMove: 'b1c3',
        hintText: 'Tap the knight on b1, then tap c3.',
        successMessage:
            '🌟 Both knights are developed! They now protect e4 and control d5. Knights work best in pairs.',
      ),
      TutorialStep(
        text:
            'Let\'s push the d-pawn to support the center. Knights need good pawn structure to thrive.\n\n👉 Push d2 to d4.',
        expectedMove: 'd2d4',
        hintText: 'Tap d2, then d4.',
        successMessage:
            '💪 Strong center! Your knights and pawns now form a commanding presence.',
      ),
      TutorialStep(
        text:
            'Lesson complete! You\'ve learned:\n• Knights move in an L-shape (2+1)\n• Knights can jump over pieces\n• "Develop knights toward the center"\n• Knights on the rim are weaker\n\n🎓 Moving on!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // BEGINNER 3: Bishop's Diagonal — 3 moves
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'beginner3',
    title: '♗ Bishop\'s Diagonal',
    description: 'Learn how bishops dominate long diagonals.',
    initialFEN: 'rnbqkbnr/pppppppp/8/8/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 2',
    steps: [
      TutorialStep(
        text:
            'Bishops slide diagonally any number of squares. Each bishop stays on its own color for the entire game (light or dark squares).\n\n👉 Develop your light-squared bishop from f1 to c4.',
        expectedMove: 'f1c4',
        hintText: 'Tap the bishop on f1, then tap c4.',
        successMessage:
            '📍 Excellent! Your bishop on c4 aims at f7 — the weakest square near Black\'s king (only the king defends it).',
      ),
      TutorialStep(
        text:
            'Now push d2 to d3 to open a path for the dark-squared bishop on c1.\n\n👉 Move d2 to d3.',
        expectedMove: 'd2d3',
        hintText: 'Tap d2, then d3.',
        successMessage:
            '🎨 Good! The diagonal c1-h6 is now open for your dark-squared bishop.',
      ),
      TutorialStep(
        text:
            'Lesson complete! You\'ve learned:\n• Bishops move diagonally (unlimited range)\n• Each bishop stays on one color forever\n• The "bishop pair" (both bishops) is very strong\n• f7 is a natural target for the light bishop\n\n🎓 Great job!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // BEGINNER 4: Castling — 3 moves
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'beginner4',
    title: '🏰 Castling',
    description: 'Protect your king and activate your rook in one move!',
    initialFEN:
        'r1bqk2r/pppp1ppp/2n2n2/2b1p3/2B1P3/5N2/PPPP1PPP/RNBQK2R w KQkq - 4 4',
    steps: [
      TutorialStep(
        text:
            'Castling is a special move: the king moves 2 squares toward a rook, and the rook jumps over the king. You can only castle if:\n• Neither piece has moved\n• No pieces between them\n• King not in check and doesn\'t pass through check\n\n👉 Castle kingside! Move king from e1 to g1.',
        expectedMove: 'e1g1',
        hintText: 'Tap your king on e1, then tap g1.',
        successMessage:
            '🏰 Perfect castle! Your king is safe behind pawns, and your rook is active on f1.',
      ),
      TutorialStep(
        text:
            'Lesson complete! Key castling rules:\n• Castle EARLY (within the first 10 moves ideally)\n• Kingside castling (O-O) is more common\n• Queenside castling (O-O-O) is slower but activates the rook faster\n• Never castle into an attack!\n\n🎓 You\'re building a solid foundation!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // BEGINNER 5: Queen Power — 3 moves
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'beginner5',
    title: '♕ Queen Power',
    description: 'The queen combines rook + bishop movement. Use her wisely!',
    initialFEN: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1',
    steps: [
      TutorialStep(
        text:
            'The queen is the most powerful piece — she can move any number of squares in any direction (diagonal, horizontal, vertical).\n\n⚠️ But DON\'T develop her too early! She becomes a target.\n\n👉 First develop a knight: move g1 to f3.',
        expectedMove: 'g1f3',
        hintText: 'Develop minor pieces (knights, bishops) before the queen.',
        successMessage:
            '👏 Smart! Develop minor pieces first, THEN bring out the queen.',
      ),
      TutorialStep(
        text:
            'Now push d2 to d4 to control the center before thinking about queen moves.\n\n👉 Move d2 to d4.',
        expectedMove: 'd2d4',
        hintText: 'Tap d2, then d4.',
        successMessage:
            '💡 Good judgment! Center control first, queen deployment later. This is how grandmasters think.',
      ),
      TutorialStep(
        text:
            'Lesson complete! Queen principles:\n• The queen = rook + bishop combined\n• Don\'t bring her out early (she gets chased)\n• Develop knights and bishops first\n• The queen is strongest in the middlegame and endgame\n\n🎓 You\'re on track to mastery!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // INTERMEDIATE 1: Fork Trap — 2 real tactical moves
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'intermediate1',
    title: '⚔️ Fork Trap',
    description: 'Attack two enemy pieces at once with a single move.',
    initialFEN:
        'r1bqkb1r/pppppppp/2n2n2/4N3/8/8/PPPPPPPP/RNBQKB1R w KQkq - 0 1',
    steps: [
      TutorialStep(
        text:
            'A FORK attacks two (or more) pieces simultaneously with one piece. The opponent can only save one!\n\nYour knight on e5 is perfectly placed. Move it to d7 — it will fork the queen on d8 and the bishop on f8!\n\n👉 Move knight from e5 to c6.',
        expectedMove: 'e5c6',
        hintText:
            'Tap the knight on e5, then tap c6. This attacks both the queen on d8 and the pawn on d7.',
        successMessage:
            '🍴 Brilliant fork! Your knight on c6 attacks the queen on d8 AND threatens b8. Black must lose material!',
      ),
      TutorialStep(
        text:
            'Lesson complete! Fork principles:\n• Knights are the BEST forking pieces (they jump!)\n• Look for undefended pieces to target\n• Queens, pawns, and bishops can also fork\n• Royal forks (attacking king + another piece) are devastating\n\n🎓 Practice spotting forks in every game!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // INTERMEDIATE 2: Pin — 2 real moves
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'intermediate2',
    title: '📌 The Pin',
    description:
        'Immobilize a piece that\'s shielding something more valuable.',
    initialFEN:
        'rnbqk2r/pppp1ppp/5n2/4p3/1b2P3/2N2N2/PPPP1PPP/R1BQKB1R w KQkq - 0 1',
    steps: [
      TutorialStep(
        text:
            'A PIN locks a piece in place because moving it would expose a more valuable piece behind it.\n\nBlack\'s bishop on b4 is pinning your knight on c3 to your king! Let\'s create our own pin.\n\n👉 Move your bishop from c1 to g5 to pin Black\'s knight on f6 to the queen on d8.',
        expectedMove: 'c1g5',
        hintText:
            'Tap the bishop on c1, then tap g5. The f6 knight cannot move because it shields the queen.',
        successMessage:
            '📍 Superb pin! Black\'s knight on f6 is now frozen — if it moves, you capture the queen! This is called an "absolute pin" when the king is behind, and a "relative pin" when another valuable piece is behind.',
      ),
      TutorialStep(
        text:
            'Lesson complete! Pin principles:\n• Bishops, rooks, and queens can create pins\n• "Absolute pin" = piece shields the king (illegal to move)\n• "Relative pin" = piece shields a valuable piece (legal but costly)\n• Pin → pile pressure → win the pinned piece\n\n🎓 Look for pins in every position!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // INTERMEDIATE 3: Back Rank Mate — 1 killer move
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'intermediate3',
    title: '💥 Back Rank Mate',
    description: 'Trap the king on the back rank and deliver checkmate!',
    initialFEN: '6k1/5ppp/8/8/8/8/5PPP/R5K1 w - - 0 1',
    steps: [
      TutorialStep(
        text:
            'The BACK RANK MATE is one of the most common tactical patterns. When a king is trapped behind its own pawns with no escape square, a rook or queen on the back rank delivers checkmate.\n\nBlack\'s king is trapped behind f7, g7, h7 with no escape squares!\n\n👉 Deliver checkmate: Move your rook from a1 to a8.',
        expectedMove: 'a1a8',
        hintText: 'Tap the rook on a1, then tap a8. That\'s checkmate!',
        successMessage:
            '⚫ CHECKMATE! The king has no escape — blocked by its own pawns. This is the classic back rank mate.',
      ),
      TutorialStep(
        text:
            'Lesson complete! Back rank defense tips:\n• Create "luft" (breathing room) with h3/g3\n• Don\'t leave your back rank unguarded\n• A rook on the back rank can defend AND attack\n• Watch for back rank tactics in every game!\n\n🎓 This pattern wins thousands of games!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // INTERMEDIATE 4: Skewer — 1 tactical move
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'intermediate4',
    title: '🎭 The Skewer',
    description:
        'Force a valuable piece to move, then capture what\'s behind it.',
    initialFEN: '4k3/8/8/8/8/8/4R3/4K3 w - - 0 1',
    steps: [
      TutorialStep(
        text:
            'A SKEWER is the reverse of a pin: you attack the more valuable piece FIRST, forcing it to move, then capture the piece behind it.\n\nYour rook can skewer the Black king! Move the rook to e8 to give check — the king MUST move, and you\'ll dominate the 8th rank.\n\n👉 Move rook from e2 to e8.',
        expectedMove: 'e2e8',
        hintText: 'Tap the rook on e2, then tap e8. Check!',
        successMessage:
            '⚔️ Check! The king must flee, and your rook now controls the entire back rank. In positions with pieces behind the king, you\'d capture them.',
      ),
      TutorialStep(
        text:
            'Lesson complete! Skewer principles:\n• Skewer = attack valuable piece first (it must move)\n• Bishops and rooks are the best skewering pieces\n• Queen skewers are devastating but less common\n• Pin = valuable behind, Skewer = valuable in front\n\n🎓 Devastating technique!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // INTERMEDIATE 5: Discovered Attack — real position
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'intermediate5',
    title: '🔄 Discovered Attack',
    description: 'Move one piece to reveal an attack from another.',
    initialFEN:
        'r1bqkbnr/pppp1ppp/2n5/4N3/4P3/8/PPPP1PPP/RNBQKB1R w KQkq - 0 1',
    steps: [
      TutorialStep(
        text:
            'A DISCOVERED ATTACK happens when you move one piece, revealing an attack from a piece behind it. If the discovered attack is a check, it\'s called a "discovered check" — extremely powerful!\n\nYour knight on e5 is blocking your queen\'s view of h5. If you move the knight, the queen\'s d1-h5 diagonal opens!\n\n👉 Move the knight from e5 to f7 (attacking the rook on h8 while the queen gains power).',
        expectedMove: 'e5f7',
        hintText:
            'Move the knight to f7. It attacks the rook AND unblocks the queen\'s diagonal.',
        successMessage:
            '💥 Double threat! Your knight attacks the rook on h8, AND your queen now has access to powerful diagonals. Black can\'t defend everything!',
      ),
      TutorialStep(
        text:
            'Lesson complete! Discovered attack principles:\n• The moving piece creates one threat\n• The revealed piece creates a second threat\n• Discovered CHECK is nearly always winning\n• Look for pieces "lined up" behind each other\n\n🎓 This is how brilliancies are created!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // ADVANCED 1: Scholar's Mate Defense
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'advanced1',
    title: '🛡️ Defend Scholar\'s Mate',
    description: 'Learn to punish the most common beginner trap.',
    initialFEN:
        'rnbqkbnr/pppp1ppp/8/4p3/2B1P3/8/PPPP1PPP/RNBQK1NR w KQkq - 0 1',
    steps: [
      TutorialStep(
        text:
            'Scholar\'s Mate (Qh5-f7#) is the #1 beginner trap. White plays Bc4 + Qh5 aiming at f7. Let\'s learn the ATTACKER\'s plan first to understand how to beat it.\n\nAs White, play the Scholar\'s Mate setup.\n\n👉 Move queen from d1 to h5 (threatening Qxf7#).',
        expectedMove: 'd1h5',
        hintText: 'Tap the queen on d1, then h5. This threatens mate on f7.',
        successMessage:
            '🎯 The Scholar\'s Mate threat is set! Qh5 attacks e5 AND f7. Against an unprepared opponent, Qxf7 is checkmate. But a prepared opponent will punish this easily (Nf6 or Qe7 blocks everything).',
      ),
      TutorialStep(
        text:
            'Lesson complete! Scholar\'s Mate defense:\n• Black plays ...Qe7 or ...Nf6 to block\n• After defending, Black gains TEMPO by attacking the queen\n• The queen will be chased and White loses time\n• Never fall for it, and don\'t rely on it!\n\n🎓 Knowledge is power!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // ADVANCED 2: Opposition in King Endgame
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'advanced2',
    title: '👑 King Opposition',
    description: 'The key endgame concept: control squares with your king.',
    initialFEN: '8/8/8/4k3/8/4K3/4P3/8 w - - 0 1',
    steps: [
      TutorialStep(
        text:
            'In King + Pawn vs King endgames, OPPOSITION is the most important concept. The side whose king is directly facing the opponent\'s king (with one square between) and it\'s the OTHER side\'s turn has the opposition.\n\nYou need to advance your pawn while keeping opposition.\n\n👉 Push your pawn from e2 to e3 (not e4 — that loses the opposition!).',
        expectedMove: 'e2e3',
        hintText:
            'Push e2 to e3. Going e4 would let Black take opposition and force a draw.',
        successMessage:
            '🧠 Correct! e3 (not e4!) is the key move. If you played e4, Black plays ...Ke6 and takes direct opposition, drawing the game. With e3, you maintain flexibility.',
      ),
      TutorialStep(
        text:
            'Lesson complete! Opposition rules:\n• Kings directly facing = whoever\'s turn it is does NOT have opposition\n• The side WITH opposition can force the other king back\n• In K+P vs K: push the KING first, then the pawn\n• This concept decides 90% of king & pawn endings\n\n🎓 Master endgames, master chess!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // ADVANCED 3: Sacrifice for Mate
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'advanced3',
    title: '⚡ The Greek Gift Sacrifice',
    description: 'The classic bishop sacrifice on h7 leading to checkmate.',
    initialFEN:
        'r1bq1rk1/pppn1ppp/4pn2/3p4/2PP4/2NBPN2/PP3PPP/R1BQ1RK1 w - - 0 1',
    steps: [
      TutorialStep(
        text:
            'The GREEK GIFT (Bxh7+) is one of chess\'s most famous sacrificial patterns. You sacrifice a bishop to expose the enemy king, then bring in the knight and queen for a mating attack.\n\nConditions: Bishop aims at h7, knight can reach g5, queen can reach the h-file.\n\n👉 Sacrifice your bishop! Move bishop from d3 to h7 (Bxh7+).',
        expectedMove: 'd3h7',
        hintText:
            'Tap the bishop on d3, then capture on h7. It\'s a sacrifice with check!',
        successMessage:
            '🔥 BRILLIANT! Bxh7+! The king must capture. Then Ng5+ brings the knight with check, and the queen swings to h5 for a devastating attack. This is the "Greek Gift" — one of the most beautiful patterns in chess.',
      ),
      TutorialStep(
        text:
            'Lesson complete! Greek Gift sacrifice checklist:\n✅ Bishop aimed at h7 (or h2 for Black)\n✅ Knight can reach g5 (or g4)\n✅ Queen can access h-file quickly\n✅ No defenders block the attack\n\nClassic continuation: 1.Bxh7+ Kxh7 2.Ng5+ Kg8 3.Qh5 → unstoppable!\n\n🎓 Brilliant sacrifices separate masters from amateurs!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // ADVANCED 4: Deflection Tactic
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'advanced4',
    title: '🎯 Deflection',
    description: 'Force a key defender away from its duty.',
    initialFEN: '2rq1rk1/pp2ppbp/2n3p1/8/4P3/2N2N2/PPP2PPP/R2QR1K1 w - - 0 1',
    steps: [
      TutorialStep(
        text:
            'DEFLECTION forces a defender away from a critical square or piece. If a piece is overloaded (defending two things), you can attack one responsibility to win the other.\n\nBlack\'s queen on d8 defends the rook on f8. If you attack d8, the queen must leave!\n\n👉 Move your queen from d1 to d7 to attack Black\'s back rank while the queen is occupied.',
        expectedMove: 'd1d7',
        hintText:
            'Tap the queen on d1, then d7. This invades with the queen and creates multiple threats.',
        successMessage:
            '🎯 Qd7! Your queen invades with threats against the 7th rank and the e7 pawn. Black\'s queen is torn between defending f8 and responding to your invasion. This is deflection in action!',
      ),
      TutorialStep(
        text:
            'Lesson complete! Deflection principles:\n• Identify OVERLOADED pieces (defending 2+ things)\n• Attack one responsibility to win the other\n• Works beautifully with back rank threats\n• Combine with pins and forks for devastating combos\n\n🎓 Think: "What is that piece defending?"',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // ADVANCED 5: Zwischenzug (In-Between Move)
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'advanced5',
    title: '💎 Zwischenzug',
    description: 'The "in-between move" that changes everything.',
    initialFEN:
        'r1bqk2r/pppp1ppp/2n2n2/4p3/1bB1P3/2NP4/PPP2PPP/R1BQK1NR w KQkq - 0 1',
    steps: [
      TutorialStep(
        text:
            'A ZWISCHENZUG ("in-between move") is an unexpected intermediate move played before the expected response. Instead of recapturing or making the "obvious" reply, you insert a surprise move that improves your position.\n\nBlack\'s bishop on b4 is attacking your knight. Instead of defending passively, play an in-between pawn push!\n\n👉 Push a2 to a3, attacking the bishop before it can retreat safely.',
        expectedMove: 'a2a3',
        hintText:
            'Tap a2, then a3. This forces the bishop to make a decision before you address the pin.',
        successMessage:
            '💎 Excellent Zwischenzug! Before dealing with the pin, you\'ve inserted a2-a3 which forces the bishop to commit. This is a master-level technique used in virtually every high-level game.',
      ),
      TutorialStep(
        text:
            'Lesson complete! Zwischenzug principles:\n• Before making the "obvious" move, ask: "Is there something better first?"\n• Checks, attacks, and captures are common in-between moves\n• This technique is used by EVERY grandmaster\n• It turns losing positions into winning ones\n\n🎓 The mark of a truly strong player!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // WEEK 6: Italian Game
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'opening_italian',
    title: '🌿 The Italian Game',
    description:
        'Learn the principles of the Italian Game, a classic and solid opening.',
    initialFEN:
        'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
    steps: [
      TutorialStep(
        text:
            'The Italian Game begins after 1.e4 e5 2.Nf3. Black has just replied 2...Nc6 to defend the pawn.\n\n👉 Now, develop your light-squared bishop to its most active square: c4.',
        expectedMove: 'f1c4',
        hintText: 'Tap your bishop on f1, then move it to c4.',
        successMessage:
            '✨ Excellent! 3.Bc4 controls the center and aims directly at f7, Black\'s weakest point in the opening.',
      ),
      TutorialStep(
        text:
            'Black responds with 3...Bc5 (The Giuoco Piano). Now, prepare to build a strong pawn center and open a path for your queen.\n\n👉 Play the solid move c2-c3.',
        expectedMove: 'c2c3',
        hintText: 'Move your pawn from c2 to c3.',
        successMessage:
            '🎯 Spot on! 4.c3 prepares to challenge the center with d2-d4 on the next move. This is the main idea of the Giuoco Piano.',
      ),
      TutorialStep(
        text:
            'Lesson complete! Italian Game principles:\n• Develop pieces rapidly towards the center\n• Bc4 targets the weak f7 pawn\n• Prepare a strong pawn center with c3 and d4\n• Castle early to secure the king\n\n🎓 A timeless opening for all levels!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // WEEK 6 (Bonus): Ruy López
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'opening_ruylopez',
    title: '⚔️ The Ruy López',
    description: 'Master the Spanish Opening, a favorite of World Champions.',
    initialFEN:
        'r1bqkbnr/pppp1ppp/2n5/4p3/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 3',
    steps: [
      TutorialStep(
        text:
            'After 1.e4 e5 2.Nf3 Nc6, instead of Bc4, White can play the even more ambitious Ruy López (Spanish Game).\n\n👉 Develop your bishop to b5 to attack the knight defending the e5 pawn.',
        expectedMove: 'f1b5',
        hintText: 'Tap your bishop on f1, and move it to b5.',
        successMessage:
            '🔥 Great! 3.Bb5 puts immediate pressure on the c6 knight. If White removes the defender, the e5 pawn becomes a target.',
      ),
      TutorialStep(
        text:
            'Black plays 3...a6 (The Morphy Defense), "putting the question" to your bishop.\n\n👉 Retreat the bishop safely to a4 to maintain the pin/pressure.',
        expectedMove: 'b5a4',
        hintText: 'Move the bishop from b5 to a4.',
        successMessage:
            '🎯 Good choice! 4.Ba4 maintains the tension. The bishop remains active on the long diagonal pointing towards the kingside.',
      ),
      TutorialStep(
        text:
            'Now secure your king immediately.\n\n👉 Castle kingside: Move king from e1 to g1.',
        expectedMove: 'e1g1',
        hintText: 'Tap your king on e1, then tap g1.',
        successMessage:
            '🏰 Perfect! Castling early is a key principle. Your king is safe, and your rook is now connected and ready for action.',
      ),
      TutorialStep(
        text:
            'Lesson complete! Ruy López principles:\n• Bb5 creates long-term strategic pressure on Black\'s center\n• Maintain tension — don\'t exchange too early\n• Castle quickly to keep the king safe\n• The Ruy López has been played by every World Champion in history!\n\n🎓 You are walking in the footsteps of legends!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // WEEK 7: Pawn Structure
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'strategy_pawns',
    title: '🧱 Pawn Structure Basics',
    description: 'Understand how pawn structure dictates the flow of the game.',
    initialFEN:
        'r1bqk2r/pp2bppp/2n1pn2/3p4/2PP4/2N2N2/PP2BPPP/R1BQ1RK1 w kq - 0 1',
    steps: [
      TutorialStep(
        text:
            'Pawn structure forms the "skeleton" of a chess position.\nHere, White has an opportunity to create an "Isolated Queen\'s Pawn" (IQP) for Black, which can be both a strength and a weakness.\n\n👉 Capture the pawn on d5 with your c4 pawn.',
        expectedMove: 'c4d5',
        hintText: 'Move the pawn on c4 to capture on d5.',
        successMessage:
            '💡 Nice! After Black recaptures, Black will have an isolated d5 pawn. It controls center squares but requires pieces to defend it.',
      ),
      TutorialStep(
        text:
            'Lesson complete! Pawn structure lessons:\n• Isolated Pawns must be blockaded, preferably by knights\n• Pawn breaks change the structure and open lines\n• Passed pawns must be pushed!\n\n🎓 Strategy flows from the pawns.',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // WEEK 8: Lucena Position
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'endgame_lucena',
    title: '🌉 The Lucena Position',
    description:
        'Master the "bridge building" technique to win key rook endgames.',
    initialFEN: '1K1k4/1P6/8/8/8/8/r7/2R5 w - - 0 1',
    steps: [
      TutorialStep(
        text:
            'The Lucena Position is the most important winning method in Rook endgames. Your king is stuck in front of your passed pawn (b7). You need to get him out, but Black\'s rook will check him.\n\nThe solution is "Building a Bridge." First, force the enemy king further away.\n\n👉 Check the Black king: Move your rook to c8.',
        expectedMove: 'c1c8',
        hintText: 'Move the rook from c1 to c8, giving check.',
        successMessage:
            '🛡️ Check! The Black king must move away (e.g., to d7). Now you have space to execute the plan.',
      ),
      TutorialStep(
        text:
            'Now for the magic move! You must prepare a shield for your king so he can step out without being endlessly checked.\n\n👉 Move your rook to c4 (the 4th rank).',
        expectedMove: 'c8c4',
        hintText: 'Move your rook from c8 to c4.',
        successMessage:
            '🌉 Brilliant! Rc4 prepares the "bridge." Now when your King comes out to a7, and Black checks you on a2, you can walk down to b5 and block the check with Rb4, guaranteeing promotion!',
      ),
      TutorialStep(
        text:
            'Lesson complete! The Lucena method:\n• Force the enemy king one file further away\n• Bring your rook to the 4th rank\n• Walk the king out and use the rook as a shield\n\n🎓 You now know how to win countless drawn-looking endgames!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // WEEK 8 (Bonus): Philidor Defense
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'endgame_philidor',
    title: '🛡️ Philidor Defense',
    description:
        'Learn the essential drawing technique for Rook + Pawn endgames.',
    initialFEN: '4k3/8/8/4K3/4P3/r7/8/8 b - - 0 1',
    steps: [
      TutorialStep(
        text:
            'The Philidor position is THE must-know drawing method when you are down a pawn in a Rook endgame.\n\nWhite wants to bring their King to the 6th rank (e6). You must prevent this!\n\n👉 Move your rook up to the 6th rank.',
        expectedMove: 'a3a6',
        hintText: 'Move your rook to a6 to guard the 6th rank.',
        successMessage:
            '🚧 The Wall! Your rook on the 6th rank prevents the White king from advancing. White has no choice but to push the pawn to e5.',
      ),
      TutorialStep(
        text:
            'Imagine White just pushed the pawn to e5 (P-e5). White\'s King no longer has a shelter on the 6th rank because the pawn is blocking it.\n\n👉 Drop your rook all the way to the 1st rank to start a barrage of checks from behind!',
        expectedMove: 'a6a1',
        hintText: 'Move your rook to a1.',
        successMessage:
            '🌪️ Perfect! With the rook on the 1st rank, you can check the White king endlessly from behind. Since the pawn is on e5, the White king has nowhere to hide, and the game is a draw!',
      ),
      TutorialStep(
        text:
            'Lesson complete! The Philidor method:\n• Keep your rook on the 6th rank to block the enemy king\n• Wait for the opponent to push their pawn to the 6th rank\n• Drop your rook back and check endlessly from behind\n\n🎓 A fundamental endgame rescue!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // WEEK 9: King Opposition
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'endgame_opposition',
    title: '👑 King + Pawn: Opposition',
    description: 'Learn the most critical endgame concept: the opposition.',
    initialFEN: '8/8/8/4k3/8/4K3/4P3/8 w - - 0 1',
    steps: [
      TutorialStep(
        text:
            'In King + Pawn endgames, the OPPOSITION is king vs king. Two kings "facing" each other with one square between them — the side NOT to move "has the opposition" and controls the key squares.\n\nYou need to advance your pawn while keeping flexibility.\n\n👉 Push your pawn from e2 to e3 (NOT e4 — that loses the opposition!).',
        expectedMove: 'e2e3',
        hintText:
            'Push e2 to e3. Going e4 would let Black take opposition and draw.',
        successMessage:
            '🧠 Correct! e3 (not e4!) is the key move. If you played e4, Black plays ...Ke6 and takes direct opposition, drawing the game. With e3, you maintain flexibility.',
      ),
      TutorialStep(
        text:
            'Black must respond. After any Black king move, you will advance your king to take the opposition.\n\n👉 Now advance your king: Move Ke3 to e4.',
        expectedMove: 'e3e4',
        hintText: 'Move your king from e3 to e4.',
        successMessage:
            '🎯 Now YOU have the opposition! Black\'s king is pushed back. You will advance to the key squares (d6, e6, f6) and escort your pawn to promotion.',
      ),
      TutorialStep(
        text:
            'Lesson complete! Opposition rules:\n• Kings directly facing = whoever\'s turn it is does NOT have opposition\n• The side WITH opposition can force the other king back\n• In K+P vs K: push the KING first, then the pawn\n• This concept decides 90% of king & pawn endings\n\n🎓 Master endgames, master chess!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // WEEK 11: The Opera Game
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'analysis_opera',
    title: '🎭 Morphy\'s Opera Game',
    description: 'Finish the most famous chess game of all time from 1858.',
    initialFEN: '1n2kb1r/p4ppp/4q3/4p1B1/4P3/1Q6/PPP2PPP/2KR4 w k - 0 1',
    steps: [
      TutorialStep(
        text:
            'Paul Morphy is playing White. Black\'s king is stuck in the center. All of White\'s pieces are developed and attacking perfectly.\n\nMorphy finds a spectacular queen sacrifice to force checkmate.\n\n👉 Sacrifice the queen to draw the knight away from defending d8: Move your Queen to b8.',
        expectedMove: 'b3b8',
        hintText:
            'Move the queen to b8, capturing the invisible knight and checking the king.',
        successMessage:
            '💥 Qb8+!! The legendary sacrifice. Black is forced to capture with the knight (Nxb8).',
      ),
      TutorialStep(
        text:
            'With the d8 square no longer defended by the knight, Morphy\'s rook and bishop team up for a beautiful geometric mate.\n\n👉 Deliver checkmate with the rook.',
        expectedMove: 'd1d8',
        hintText: 'Move your rook from d1 to d8.',
        successMessage:
            '🎉 CHECKMATE! The rook delivers mate, supported by the bishop on g5. This is the immortal "Opera Game" finish.',
      ),
      TutorialStep(
        text:
            'Lesson complete! Morphy\'s Opera Game teaches:\n• Rapid development is key\n• Do not waste time making multiple pawn moves\n• Keep your king safe, and punish opponents who leave their king in the center\n\n🎓 A masterpiece of attacking chess!',
        isCompletion: true,
      ),
    ],
  ),

  // ═══════════════════════════════════════════
  // WEEK 12: Graduation Puzzle
  // ═══════════════════════════════════════════
  TutorialLesson(
    id: 'practice_full',
    title: '🎓 Graduation: Smothered Mate',
    description: 'Spot a beautiful tactical pattern to secure your victory.',
    initialFEN:
        'r1b1k2r/ppppqppp/2n5/4n3/2P5/2N5/PP1NPPPP/R2QKB1R b KQkq - 0 1',
    steps: [
      TutorialStep(
        text:
            'You have reached the final puzzle! White has neglected their development and left their King vulnerable.\n\nEven though the White King is surrounded by his own pieces, you have a knight move that ends the game immediately.\n\n👉 Deliver checkmate with your knight on e5.',
        expectedMove: 'e5d3',
        hintText: 'Move your e5 knight to d3.',
        successMessage:
            '🔥 BREATHTAKING! Nd3 is Checkmate! This is called a "Smothered Mate" because the king is completely boxed in by his own pieces.',
      ),
      TutorialStep(
        text:
            'Lesson complete! You have completed the 12-week curriculum!\n• Now you understand piece values, openings, tactics, and endgames\n• Continue practicing puzzles every day\n• Play full games and use the post-game analysis to review\n\n🎓 Congratulations, Chess Master!',
        isCompletion: true,
      ),
    ],
  ),
];
