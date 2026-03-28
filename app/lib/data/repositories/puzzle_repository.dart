import 'package:dio/dio.dart';
import '../models/puzzle_model.dart';

class PuzzleRepository {
  final Dio _dio = Dio();

  Future<Puzzle> getDailyPuzzle() async {
    try {
      final response = await _dio.get('https://lichess.org/api/puzzle/daily');
      if (response.statusCode == 200) {
        return _mapLichessPuzzle(response.data);
      }
    } catch (e) {
      print('[PuzzleRepository] Failed to fetch daily puzzle: $e');
    }
    return _getFallbackPuzzle();
  }

  Future<Puzzle> getRandomPuzzle() async {
    // Lichess doesn't have a simple "random" endpoint without auth, 
    // but we can fetch the daily one or use a pool of IDs. 
    // For now, we'll try to fetch the daily one as a baseline.
    return getDailyPuzzle();
  }

  Puzzle _mapLichessPuzzle(Map<String, dynamic> data) {
    final p = data['puzzle'];
    final game = data['game'];
    final moves = p['moves'] as List;
    
    // Lichess gives a list of UCI moves.
    // The first move is usually the opponent's move that triggers the puzzle.
    final List<PuzzleMove> puzzleMoves = [];
    for (int i = 0; i < moves.length; i++) {
        puzzleMoves.add(PuzzleMove(
          move: _uciToSimpleSan(moves[i]), // Placeholder for SAN conversion
          uciMove: moves[i],
          hint: 'Look for a strong tactical response!',
          dialog: 'Can you find the best move?',
          successDialog: i == moves.length - 1 ? 'Fantastic! You solved it!' : 'Great move! Keep going.',
        ));
    }

    return Puzzle(
      id: p['id'],
      title: 'Lichess Daily Puzzle',
      description: 'Find the winning sequence for ${game['players'][0]['color'] == 'white' ? 'Black' : 'White'}!',
      initialFEN: p['fen'],
      moves: puzzleMoves,
      reward: '100 XP',
      rating: p['rating'],
      themes: List<String>.from(p['themes'] ?? []),
      gameId: game['id'],
    );
  }

  String _uciToSimpleSan(String uci) {
    // Basic conversion logic if needed, or just return UCI for simplicity
    return uci;
  }

  Puzzle _getFallbackPuzzle() {
    return const Puzzle(
      id: 'fallback_1',
      title: '👑 The Royal Trap',
      description: 'White to move and deliver a beautiful smothered mate!',
      initialFEN: 'r1b2r1k/1p1n1Npp/p7/3Q4/8/8/PP3PPP/R4RK1 w - - 0 1',
      moves: [
        PuzzleMove(
          move: 'f7h6', uciMove: 'f7h6',
          hint: 'Force the king into a worse position.',
          dialog: 'The king is trapped!',
          successDialog: 'Double check! King to h8.',
        ),
        PuzzleMove(
          move: 'd5g8', uciMove: 'd5g8',
          hint: 'Sometimes you have to sacrifice the queen.',
          dialog: 'Force the rook to take.',
          successDialog: 'Brilliant! The king is surrounded.',
        ),
        PuzzleMove(
          move: 'h6f7', uciMove: 'h6f7',
          hint: 'Knight jumps in for the kill.',
          dialog: 'Smothered mate!',
          successDialog: 'Victory!',
        ),
      ],
      reward: '500 XP',
    );
  }
}
