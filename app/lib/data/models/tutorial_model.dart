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
  final String? errorMessage;
  final bool isCompletion;

  const TutorialStep({
    required this.text,
    this.expectedMove,
    this.successMessage,
    this.errorMessage,
    this.isCompletion = false,
  });

  @override
  List<Object?> get props => [text, expectedMove, successMessage, errorMessage, isCompletion];
}

final List<TutorialLesson> tutorialLessons = [
  // BEGINNER LEVEL - Basic Piece Movement
  TutorialLesson(
    id: 'beginner1',
    title: '♟️ Pawn Mastery',
    description: 'Learn pawn movement and its role in controlling the center.',
    initialFEN: 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
    steps: [
      TutorialStep(
        text: 'Pawns move forward! Move your kingside pawn (e2) two squares forward to e4.',
        expectedMove: 'e2e4',
        successMessage: '✨ Excellent! You\'ve controlled the center. Pawns can move 2 squares from their starting position.',
      ),
      TutorialStep(
        text: 'Now push your queen\'s pawn from d2 to d4 to strengthen your center.',
        expectedMove: 'd2d4',
        successMessage: '🎯 Perfect! A strong center is the foundation of good chess. Your pawns control the most important squares.',
        isCompletion: true,
      ),
    ],
  ),
  TutorialLesson(
    id: 'beginner2',
    title: '♞ Knight\'s Dance',
    description: 'Master the unique L-shaped knight movement.',
    initialFEN: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1',
    steps: [
      TutorialStep(
        text: 'Knights move in an L-shape (2 squares one direction, 1 square perpendicular). Move your kingside knight from g1 to f3.',
        expectedMove: 'g1f3',
        successMessage: '⚡ Great! The knight on f3 attacks e5 and d4, supporting your center.',
      ),
      TutorialStep(
        text: 'Now develop your queenside knight to c3 by moving from b1 to c3.',
        expectedMove: 'b1c3',
        successMessage: '🌟 Excellent! Both knights are developed and protecting the center.',
        isCompletion: true,
      ),
    ],
  ),
  TutorialLesson(
    id: 'beginner3',
    title: '♗ Bishop\'s Diagonal',
    description: 'Learn how bishops control diagonals.',
    initialFEN: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1',
    steps: [
      TutorialStep(
        text: 'Bishops move diagonally any number of squares. Move your light-squared bishop from f1 to c4.',
        expectedMove: 'f1c4',
        successMessage: '📍 Perfect! Your bishop now controls the diagonal and attacks f7, a weak square near the opponent\'s king.',
      ),
      TutorialStep(
        text: 'Move your dark-squared bishop from c1 to g5 to develop it.',
        expectedMove: 'c1g5',
        successMessage: '🎨 Nicely done! Both bishops are now active and apply pressure.',
        isCompletion: true,
      ),
    ],
  ),
  TutorialLesson(
    id: 'beginner4',
    title: '♕ Queen Power',
    description: 'The queen moves like a rook and bishop combined. Use her correctly!',
    initialFEN: 'rnbqkbnr/pppppppp/8/8/4P3/8/PPPP1PPP/RNBQKBNR w KQkq - 0 1',
    steps: [
      TutorialStep(
        text: 'Develop your queen to a good square. Move her from d1 to f3.',
        expectedMove: 'd1f3',
        successMessage: '⚜️ Good move! Your queen now attacks f7 and controls the center while staying relatively safe.',
      ),
      TutorialStep(
        text: '⚠️ Be careful! Early queen moves can make your queen a target. Move her to h5 for an aggressive setup.',
        expectedMove: 'f3h5',
        successMessage: '🔥 Your queen is now attacking on the kingside. Remember: An active queen can be powerful, but also vulnerable!',
        isCompletion: true,
      ),
    ],
  ),
  TutorialLesson(
    id: 'beginner5',
    title: '👑 King\'s Escape Route',
    description: 'Learn how to castle and protect your king.',
    initialFEN: 'r1bqkbnr/pppppppp/2n5/8/4P3/5N2/PPPP1PPP/RNBQKB1R w KQkq - 2 4',
    steps: [
      TutorialStep(
        text: 'After developing your pieces, castle kingside! This moves your king to safety on g1 and activates your rook.',
        expectedMove: 'e1g1',
        successMessage: '🏰 Perfect! You\'ve successfully castled. Your king is safer, and your rook is ready for the game.',
      ),
      TutorialStep(
        text: 'Castling is a special move that combines king and rook movement. You can only castle once per game.',
        expectedMove: '',
        successMessage: '✅ Remember: Castle early to get your king to safety!',
        isCompletion: true,
      ),
    ],
  ),
  // INTERMEDIATE LEVEL - Tactics and Strategy
  TutorialLesson(
    id: 'intermediate1',
    title: '⚔️ The Fork Trap',
    description: 'Attack two pieces at once with one piece (a fork).',
    initialFEN: '6k1/5ppp/8/4N3/8/8/5PPP/6K1 w - - 0 1',
    steps: [
      TutorialStep(
        text: 'Look for opportunities to attack multiple enemy pieces at once. Move your knight from e5 to g6 to threaten two pawns!',
        expectedMove: 'e5g6',
        successMessage: '🍴 Excellent fork! You\'re attacking both the f8 and h8 pieces. Your opponent can only defend one.',
      ),
      TutorialStep(
        text: 'Forks are powerful because they create multiple threats that can\'t all be defended.',
        expectedMove: '',
        successMessage: '💡 Master forks to win material consistently!',
        isCompletion: true,
      ),
    ],
  ),
  TutorialLesson(
    id: 'intermediate2',
    title: '📌 Pin the Piece',
    description: 'Immobilize a piece that\'s protecting something more valuable.',
    initialFEN: '6k1/5ppp/8/8/3b4/5B2/5PPP/6K1 w - - 0 1',
    steps: [
      TutorialStep(
        text: 'Your bishop can pin the enemy bishop to the king! Move your bishop from f3 to c6.',
        expectedMove: 'f3c6',
        successMessage: '📍 Great pin! The opponent\'s bishop on d4 can\'t move without exposing the king to check.',
      ),
      TutorialStep(
        text: 'Pinned pieces are nearly helpless. Forks and pins are your fundamental tactical weapons.',
        expectedMove: '',
        successMessage: '🎯 Master pins to paralyze your opponent\'s pieces!',
        isCompletion: true,
      ),
    ],
  ),
  TutorialLesson(
    id: 'intermediate3',
    title: '🎭 The Skewer Reversal',
    description: 'Force a valuable piece to move and capture what\'s behind it.',
    initialFEN: '6k1/5ppp/8/8/8/8/3Q1PPP/6K1 w - - 0 1',
    steps: [
      TutorialStep(
        text: 'A skewer is like a reverse pin: you attack the valuable piece first! Move your queen to d7 to attack the king and f7 pawn.',
        expectedMove: 'd2d7',
        successMessage: '⚔️ Perfect skewer! After the king moves, you\'ll capture the pawn.',
      ),
      TutorialStep(
        text: 'Remember: Pin = valuable piece in front → Skewer = valuable piece in back.',
        expectedMove: '',
        successMessage: '✅ Skewers are great for winning material!',
        isCompletion: true,
      ),
    ],
  ),
  TutorialLesson(
    id: 'intermediate4',
    title: '💥 The Back Rank Mate',
    description: 'Trap the king on the back rank and deliver checkmate.',
    initialFEN: '6kr/5ppp/8/8/8/8/R5PP/6K1 w - - 0 1',
    steps: [
      TutorialStep(
        text: 'When a king is trapped on the back rank with no escape squares, it\'s vulnerable to checkmate. Move your rook to a8 for checkmate!',
        expectedMove: 'a1a8',
        successMessage: '⚫ Checkmate! The back rank is a classic mating pattern. Always watch for back rank threats.',
      ),
      TutorialStep(
        text: 'Always keep escape squares for your own king and prevent back rank mates against you.',
        expectedMove: '',
        successMessage: '👑 The back rank mate is one of the most important patterns to know!',
        isCompletion: true,
      ),
    ],
  ),
  // ADVANCED LEVEL - Deep Strategy
  TutorialLesson(
    id: 'advanced1',
    title: '🔄 The Discovered Attack',
    description: 'Move one piece to attack while revealing an attack from another piece.',
    initialFEN: '6k1/5ppp/8/8/3r4/5B2/5PPP/6K1 w - - 0 1',
    steps: [
      TutorialStep(
        text: 'Move your bishop from f3 to e4. This creates a discovered attack—your rook now attacks the king!',
        expectedMove: 'f3e4',
        successMessage: '💥 Brilliant discovered attack! You\'ve created multiple threats.',
      ),
      TutorialStep(
        text: 'Discovered attacks are powerful because the moving piece and the revealed piece both create threats.',
        expectedMove: '',
        successMessage: '🌟 Discovered attacks can lead to devastating combinations!',
        isCompletion: true,
      ),
    ],
  ),
  TutorialLesson(
    id: 'advanced2',
    title: '🎯 The Quiet Move Strategy',
    description: 'Sometimes the strongest move creates a subtle, unstoppable threat.',
    initialFEN: '6k1/5ppp/8/8/8/8/3Q1PPP/6K1 w - - 0 1',
    steps: [
      TutorialStep(
        text: 'Not every strong move is a capture or check! Move your queen to d5 to centralize it and threaten multiple squares.',
        expectedMove: 'd2d5',
        successMessage: '🤔 An excellent quiet move! You\'re threatening to dominate the board with no immediate tactics.',
      ),
      TutorialStep(
        text: 'In advanced play, improving piece placement is often stronger than forcing immediate tactics.',
        expectedMove: '',
        successMessage: '📚 Quiet moves separate masters from amateurs!',
        isCompletion: true,
      ),
    ],
  ),
  TutorialLesson(
    id: 'advanced3',
    title: '⚡ The Sacrificial Attack',
    description: 'Give up material for a devastating mating attack.',
    initialFEN: '6k1/5ppp/8/8/8/8/3Q1PPP/R5K1 w - - 0 1',
    steps: [
      TutorialStep(
        text: 'Sometimes sacrificing material creates an unstoppable attack! Move your queen to d8 to begin a mating net.',
        expectedMove: 'd2d8',
        successMessage: '🔥 A fearless sacrifice! You\'ve given up the queen but now have an unstoppable mating attack.',
      ),
      TutorialStep(
        text: 'Sacrifices require deep calculation. Always verify the attack leads to checkmate before sacrificing.',
        expectedMove: '',
        successMessage: '💎 Master sacrifices to unleash brilliant combinations!',
        isCompletion: true,
      ),
    ],
  ),
];
