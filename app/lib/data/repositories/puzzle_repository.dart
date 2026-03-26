import '../models/puzzle_model.dart';

class PuzzleRepository {
  Future<Puzzle> getDailyPuzzle() async {
    // In a real app, this would fetch from an API
    // For now, return a unique and challenging hard-coded puzzle
    return const Puzzle(
      id: 'daily_2026_03_26',
      title: '👑 The Royal Trap',
      description: 'White to move and deliver a beautiful smothered mate in 3 moves!',
      initialFEN: 'r1b2r1k/1p1n1Npp/p7/3Q4/8/8/PP3PPP/R4RK1 w - - 0 1',
      moves: [
        PuzzleMove(
          move: 'f7h6',
          hint: 'The knight is already checking the king, but we need to force it into a worse position.',
          dialog: 'The king is trapped in the corner! Can you find the way to squeeze him?',
          successDialog: 'Double check! The king is forced back to h8.',
        ),
        PuzzleMove(
          move: 'd5g8',
          hint: 'Sometimes you have to give up the most powerful piece to win the game.',
          dialog: 'A heart-stopping queen sacrifice! This forces the rook to take.',
          successDialog: 'Brilliant! The king is now completely surrounded by his own pieces.',
        ),
        PuzzleMove(
          move: 'h6f7',
          hint: 'The knight jumps in for the kill.',
          dialog: 'One final leap for the knight...',
          successDialog: 'SMOTHERED MATE! The king was suffocated by his own loyal defenders.',
        ),
      ],
      reward: '500 XP & Legendary Tactician Badge 🏅',
    );
  }
}
