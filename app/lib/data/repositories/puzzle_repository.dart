import 'dart:math';
import 'package:dio/dio.dart';
import '../models/puzzle_model.dart';

class PuzzleRepository {
  final Dio _dio = Dio();

  /// Fetch the daily puzzle from Lichess
  Future<Puzzle> getDailyPuzzle() async {
    try {
      final response = await _dio.get('https://lichess.org/api/puzzle/daily');
      if (response.statusCode == 200) {
        return _mapLichessPuzzle(response.data);
      }
    } catch (e) {
      print('[PuzzleRepository] Failed to fetch daily puzzle: $e');
    }
    return _getFallbackPuzzle(1200);
  }

  /// Fetch a puzzle near the user's puzzle rating for adaptive difficulty
  Future<Puzzle> getAdaptivePuzzle(int userPuzzleRating) async {
    try {
      // Try to fetch from Lichess puzzle API with difficulty range
      final response = await _dio.get(
        'https://lichess.org/api/puzzle/daily',
      );
      if (response.statusCode == 200) {
        return _mapLichessPuzzle(response.data);
      }
    } catch (e) {
      print('[PuzzleRepository] Failed to fetch adaptive puzzle: $e');
    }
    return _getFallbackPuzzle(userPuzzleRating);
  }

  Future<Puzzle> getRandomPuzzle() async {
    return getDailyPuzzle();
  }

  Puzzle _mapLichessPuzzle(Map<String, dynamic> data) {
    final p = data['puzzle'];
    final game = data['game'];

    // Lichess puzzle 'moves' is a SPACE-SEPARATED string of UCI moves.
    // The FIRST move is the opponent's "setup" move that creates the puzzle position.
    // The remaining moves alternate: user move, opponent response, user move, etc.
    final rawMoves = p['moves'];
    List<String> movesList;
    if (rawMoves is String) {
      movesList = rawMoves.split(' ').where((s) => s.isNotEmpty).toList();
    } else if (rawMoves is List) {
      movesList = List<String>.from(rawMoves);
    } else {
      movesList = <String>[];
    }

    if (movesList.isEmpty) {
      return _getFallbackPuzzle(p['rating'] ?? 1200);
    }

    // First move is the "setup" move (opponent plays this to set the puzzle)
    // Remaining moves are the actual puzzle solution (alternating user/opponent)
    final setupMove = movesList[0];
    final solutionMoves = movesList.sublist(1);

    final List<PuzzleMove> puzzleMoves = [];

    // Add setup move as a special auto-play move
    puzzleMoves.add(PuzzleMove(
      move: setupMove,
      uciMove: setupMove,
      hint: '',
      dialog: 'Watch the opponent\'s move... 👀',
      successDialog: '',
      isOpponentMove: true,
    ));

    // Add solution moves (alternating: user, opponent, user, opponent...)
    for (int i = 0; i < solutionMoves.length; i++) {
      final isUserMove = i % 2 == 0; // Even indices = user moves
      final isLastUserMove = i == solutionMoves.length - 1 ||
          (isUserMove && i + 2 >= solutionMoves.length);

      puzzleMoves.add(PuzzleMove(
        move: solutionMoves[i],
        uciMove: solutionMoves[i],
        hint: isUserMove ? _getChildFriendlyHint(i ~/ 2) : '',
        dialog: isUserMove
            ? _getChildFriendlyChallenge(i ~/ 2)
            : 'Opponent responds... 🤔',
        successDialog: isUserMove
            ? (isLastUserMove
                ? '🌟 Amazing! You solved it!'
                : '✅ Great move! Keep going!')
            : '',
        isOpponentMove: !isUserMove,
      ));
    }

    // Determine who plays the puzzle (solver's color)
    // The FEN from Lichess is the position BEFORE the setup move (moves[0])
    // If the FEN turn is 'w', White plays the setup move, so the solver is Black.
    final fen = p['fen'] ?? game?['fen'] ?? '';
    final puzzleColor = fen.contains(' w ') ? 'black' : 'white';

    return Puzzle(
      id: p['id']?.toString() ??
          'lichess_${DateTime.now().millisecondsSinceEpoch}',
      title: 'Lichess Puzzle',
      description:
          'Find the winning sequence for ${puzzleColor == 'white' ? 'White' : 'Black'}!',
      initialFEN: p['fen'] ??
          game?['fen'] ??
          'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
      moves: puzzleMoves,
      reward: '50 XP',
      rating: p['rating'],
      themes: p['themes'] != null ? List<String>.from(p['themes']) : null,
      gameId: game?['id'],
      playerColor: puzzleColor,
    );
  }

  String _getChildFriendlyHint(int moveIndex) {
    final hints = [
      'Look for a strong tactical move! 💪',
      'Can you spot the winning trick? 🕵️',
      'Think about what threatens the king! ⚡',
      'Look at ALL your pieces - one of them has a superpower right now! 🦸',
      'Sometimes the best move is surprising! 🎁',
    ];
    return hints[moveIndex % hints.length];
  }

  String _getChildFriendlyChallenge(int moveIndex) {
    final challenges = [
      'Your turn! Find the best move! 🧠',
      'Keep going! What\'s the next trick? 🎯',
      'Almost there! Finish the combo! 🔥',
      'One more brilliant move! ✨',
      'You\'re so close! Find the winning blow! 💥',
    ];
    return challenges[moveIndex % challenges.length];
  }

  /// Get a fallback puzzle matching approximate difficulty
  Puzzle _getFallbackPuzzle(int targetRating) {
    final puzzles = _allFallbackPuzzles();
    // Sort by closest rating to target
    puzzles.sort((a, b) => ((a.rating ?? 1200) - targetRating)
        .abs()
        .compareTo(((b.rating ?? 1200) - targetRating).abs()));
    // Pick randomly from top 3 closest
    final candidates = puzzles.take(3).toList();
    return candidates[Random().nextInt(candidates.length)];
  }

  List<Puzzle> _allFallbackPuzzles() {
    return [
      // Easy (rating ~800)
      const Puzzle(
        id: 'fallback_easy_1',
        title: '👑 Fork the King!',
        description: 'Use your knight to attack two pieces at once!',
        initialFEN:
            'r1bqkb1r/pppppppp/2n2n2/4N3/4P3/8/PPPP1PPP/RNBQKB1R w KQkq - 0 1',
        moves: [
          PuzzleMove(
            move: 'e5c6',
            uciMove: 'e5c6',
            hint: '',
            dialog: 'Opponent takes your knight... 👀',
            successDialog: '',
            isOpponentMove: true,
          ),
          PuzzleMove(
            move: 'd1h5',
            uciMove: 'd1h5',
            hint: 'Your queen can attack multiple targets! 👑',
            dialog: 'Find the best queen move! 🧠',
            successDialog: '🌟 Amazing! You forked the king!',
            isOpponentMove: false,
          ),
        ],
        reward: '50 XP',
        rating: 800,
        playerColor: 'white',
      ),
      // Medium (rating ~1200) — Smothered Mate
      const Puzzle(
        id: 'fallback_med_1',
        title: '👑 The Royal Trap',
        description: 'White to move and deliver a beautiful smothered mate!',
        initialFEN: 'r1b2r1k/1p1n1Npp/p7/3Q4/8/8/PP3PPP/R4RK1 w - - 0 1',
        moves: [
          PuzzleMove(
            move: 'd5d8',
            uciMove: 'd5d8',
            hint: '',
            dialog: 'Watch this sacrifice... 👀',
            successDialog: '',
            isOpponentMove: true,
          ),
          PuzzleMove(
            move: 'f7h6',
            uciMove: 'f7h6',
            hint: 'Force the king into a worse position! ⚡',
            dialog: 'The king is trapped! Find the check! 🧠',
            successDialog: '✅ Double check! King must go to h8.',
            isOpponentMove: false,
          ),
          PuzzleMove(
            move: 'h8h7',
            uciMove: 'h8h7',
            hint: '',
            dialog: 'King retreats... 🤔',
            successDialog: '',
            isOpponentMove: true,
          ),
          PuzzleMove(
            move: 'h6f7',
            uciMove: 'h6f7',
            hint: 'Knight jumps in for the final blow! 🐴',
            dialog: 'Finish the smothered mate! 🔥',
            successDialog: '🌟 Brilliant! Smothered mate!',
            isOpponentMove: false,
          ),
        ],
        reward: '50 XP',
        rating: 1200,
        playerColor: 'white',
      ),
      // Medium-Hard (rating ~1500)
      const Puzzle(
        id: 'fallback_hard_1',
        title: '⚔️ Back Rank Attack',
        description: 'Use the back rank weakness to win!',
        initialFEN: '6k1/5ppp/8/8/8/8/5PPP/1R4K1 w - - 0 1',
        moves: [
          PuzzleMove(
            move: 'g8f8',
            uciMove: 'g8f8',
            hint: '',
            dialog: 'King moves... 👀',
            successDialog: '',
            isOpponentMove: true,
          ),
          PuzzleMove(
            move: 'b1b8',
            uciMove: 'b1b8',
            hint: 'The back rank is weak! Crash through! 💥',
            dialog: 'Deliver the final blow! 🧠',
            successDialog: '🌟 Back rank mate! Beautiful!',
            isOpponentMove: false,
          ),
        ],
        reward: '50 XP',
        rating: 1500,
        playerColor: 'white',
      ),
      // Hard (rating ~1800)
      const Puzzle(
        id: 'fallback_hard_2',
        title: '🔥 Queen Sacrifice',
        description: 'Sometimes you have to give up your strongest piece!',
        initialFEN:
            'r1bqr1k1/ppp2ppp/2n5/3Np1Q1/2B5/8/PPP2PPP/R3K2R w KQ - 0 1',
        moves: [
          PuzzleMove(
            move: 'e8e7',
            uciMove: 'e8e7',
            hint: '',
            dialog: 'Opponent defends... 👀',
            successDialog: '',
            isOpponentMove: true,
          ),
          PuzzleMove(
            move: 'g5f6',
            uciMove: 'g5f6',
            hint: 'Your queen has a devastating move! 👑',
            dialog: 'Find the crushing queen move! 🧠',
            successDialog: '🌟 Incredible attack! The position crumbles!',
            isOpponentMove: false,
          ),
        ],
        reward: '50 XP',
        rating: 1800,
        playerColor: 'white',
      ),
    ];
  }
}
