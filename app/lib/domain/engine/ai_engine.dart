import 'dart:isolate';
import 'dart:math';
import '../engine/chess_engine.dart';
import '../../data/models/game_config.dart';
import './personality_engine.dart';

class AIEngine {
  static const Map<AIDifficulty, _AIConfig> _configs = {
    AIDifficulty.basic: _AIConfig(depth: 1, randomness: 0.7),
    AIDifficulty.intermediate: _AIConfig(depth: 4, randomness: 0.1),
    AIDifficulty.advanced: _AIConfig(depth: 5, randomness: 0.0),
    AIDifficulty.impossible: _AIConfig(depth: 6, randomness: 0.0),
    AIDifficulty.aiMode: _AIConfig(depth: 8, randomness: 0.0),
  };

  // Transposition Table for memoizing search results
  static final Map<String, _TTEntry> _tt = {};

  // Opening Book: Common starters for instant play
  static const Map<String, String> _openingBook = {
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1':
        'e2e4', // King's Pawn
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPPPPPP/RNBQKBNR b KQkq e3 0 1':
        'c7c5', // Sicilian Defense
    'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1':
        'd7d5', // Queen's Gambit setup
    'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2':
        'g1f3', // Open Sicilian
  };

  static Future<Move?> getBestMove(
    ChessEngine engine,
    AIDifficulty difficulty, {
    Duration timeout = const Duration(seconds: 5),
    AIPersonality personality = AIPersonality.coach,
  }) async {
    // Run AI search on a background isolate so UI actions stay responsive.
    final fenSnapshot = engine.toFEN();
    final bestMoveAlg = await Isolate.run<String?>(() {
      final isolatedEngine = ChessEngine.fromFEN(fenSnapshot);
      final move = _getBestMoveSync(isolatedEngine, difficulty,
          timeout: timeout, personality: personality);
      return move?.toAlgebraic();
    });

    if (bestMoveAlg == null) return null;
    final legalMoves = engine.allLegalMoves();
    return legalMoves.where((m) => m.toAlgebraic() == bestMoveAlg).firstOrNull;
  }

  /// Get multiple top moves for humanization/styling (Isolate-safe)
  static Future<List<(Move, int)>> getTopMoves(
    ChessEngine engine,
    AIDifficulty difficulty, {
    int count = 3,
    AIPersonality personality = AIPersonality.coach,
  }) async {
    final fenSnapshot = engine.toFEN();
    final results = await Isolate.run<List<(String, int)>>(() {
      final isolatedEngine = ChessEngine.fromFEN(fenSnapshot);
      final config = _configs[difficulty]!;

      final moves = isolatedEngine.allLegalMoves();
      final List<(String, int)> scored = [];

      for (final move in moves) {
        isolatedEngine.applyMoveInternal(move);
        final score = -_search(isolatedEngine, config.depth, -999999, 999999,
                DateTime.now(), const Duration(seconds: 10), personality)
            .score;
        isolatedEngine.undoMove();
        scored.add((move.toAlgebraic(), score));
      }

      scored.sort((a, b) => b.$2.compareTo(a.$2));
      return scored.take(count).toList();
    });

    final legal = engine.allLegalMoves();
    return results.map((r) {
      final m = legal.firstWhere((lm) => lm.toAlgebraic() == r.$1);
      return (m, r.$2);
    }).toList();
  }

  /// Synchronously evaluate position score (Isolate-safe)
  static Future<int> evaluatePosition(ChessEngine engine) async {
    final fenSnapshot = engine.toFEN();
    return await Isolate.run<int>(() {
      final isolatedEngine = ChessEngine.fromFEN(fenSnapshot);
      return _evaluate(isolatedEngine);
    });
  }

  static Move? _getBestMoveSync(
    ChessEngine engine,
    AIDifficulty difficulty, {
    Duration timeout = const Duration(seconds: 5),
    AIPersonality personality = AIPersonality.coach,
  }) {
    final startTime = DateTime.now();
    final config = _configs[difficulty]!;
    final fen = engine.toFEN();

    // 1. Check Opening Book
    if (_openingBook.containsKey(fen)) {
      final san = _openingBook[fen]!;
      final moves = engine.allLegalMoves();
      return moves.where((m) => m.toAlgebraic() == san).firstOrNull ??
          moves.first;
    }

    // 2. Iterative Deepening with Humanoid Selection
    Move? bestMove;
    int currentDepth = 1;
    List<(Move, int)> topCandidates = [];

    // Clear TT occasionally to avoid memory issues on web
    if (_tt.length > 50000) _tt.clear();

    while (currentDepth <= config.depth) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed > timeout && currentDepth > 1) break;

      final moves = engine.allLegalMoves();
      final List<(Move, int)> scored = [];

      for (final move in moves) {
        engine.applyMoveInternal(move);
        final res = _search(engine, currentDepth - 1, -999999, 999999,
            startTime, timeout, personality);
        engine.undoMove();
        scored.add((move, -res.score));
      }

      scored.sort((a, b) => b.$2.compareTo(a.$2));

      if (scored.isNotEmpty) {
        bestMove = scored.first.$1;
        topCandidates = scored;
      }

      currentDepth++;
    }

    // 3. Apply Multi-Choice Randomness (Humanization)
    if (config.randomness > 0 && topCandidates.length > 1) {
      final rand = Random().nextDouble();
      if (rand < config.randomness) {
        // Pick one of the top 3 moves instead of #1
        final count = min(topCandidates.length, 3);
        final idx = Random().nextInt(count);
        return topCandidates[idx].$1;
      }
    }

    return bestMove ?? engine.allLegalMoves().firstOrNull;
  }

  static _SearchResult _search(ChessEngine engine, int depth, int alpha,
      int beta, DateTime startTime, Duration timeout,
      [AIPersonality personality = AIPersonality.coach]) {
    if (depth == 0) {
      return _SearchResult(
          score:
              _quiescence(engine, alpha, beta, startTime, timeout, personality));
    }

    final fen = engine.toFEN();
    if (_tt.containsKey(fen)) {
      final entry = _tt[fen]!;
      if (entry.depth >= depth) {
        return _SearchResult(score: entry.score, move: entry.bestMove);
      }
    }

    final moves = engine.allLegalMoves();
    if (moves.isEmpty) {
      if (engine.status == GameStatus.checkmate) {
        return _SearchResult(score: -100000 - depth);
      }
      return _SearchResult(score: 0);
    }

    // Move Ordering (Best move from TT or captures first)
    moves.sort((a, b) {
      if (b.capturedPiece != null) return 1;
      return 0;
    });

    Move? bestMove;
    int bestScore = -999999;

    for (final move in moves) {
      // Check for timeout deep in the tree every few nodes
      if (depth > 2 &&
          DateTime.now().difference(startTime).inMilliseconds >
              timeout.inMilliseconds) {
        break;
      }

      engine.applyMoveInternal(move);
      final score = -_search(
              engine, depth - 1, -beta, -alpha, startTime, timeout, personality)
          .score;
      engine.undoMove();

      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
      alpha = max(alpha, bestScore);
      if (alpha >= beta) break;
    }

    _tt[fen] = _TTEntry(score: bestScore, depth: depth, bestMove: bestMove);
    return _SearchResult(score: bestScore, move: bestMove);
  }

  static int _quiescence(ChessEngine engine, int alpha, int beta,
      DateTime startTime, Duration timeout,
      [AIPersonality personality = AIPersonality.coach]) {
    int standPat = _evaluate(engine, personality);
    if (standPat >= beta) return beta;
    if (alpha < standPat) alpha = standPat;

    final moves =
        engine.allLegalMoves().where((m) => m.capturedPiece != null).toList();
    for (final move in moves) {
      if (DateTime.now().difference(startTime).inMilliseconds >
          timeout.inMilliseconds) {
        break;
      }
      engine.applyMoveInternal(move);
      final score = -_quiescence(engine, -beta, -alpha, startTime, timeout);
      engine.undoMove();

      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  static int _evaluate(ChessEngine engine, [AIPersonality personality = AIPersonality.coach]) {
    if (engine.status == GameStatus.checkmate) return -100000;
    if (engine.status == GameStatus.stalemate ||
        engine.status == GameStatus.draw) return 0;

    int score = 0;
    final board = engine.board;

    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        final piece = board[r][f];
        if (piece == null) continue;

        int value = _pieceValue(piece.type) + _positionalBonus(piece, f, r);
        
        // --- Personality Bias ---
        if (personality == AIPersonality.aggressive) {
          // Favor forward development and attacking squares
          if (piece.type == PieceType.knight || piece.type == PieceType.bishop) {
            final homeRank = piece.color == PieceColor.white ? 7 : 0;
            if (r != homeRank) value += 10; // Bonus for developed pieces
          }
          if (engine.status == GameStatus.check) value += 15;
        } else if (personality == AIPersonality.defensive) {
          // Favor king safety and solid structures
          if (piece.type == PieceType.king) value += 20;
          if (piece.type == PieceType.pawn) value += 5; // Favor pawn chains
        }

        score += piece.color == PieceColor.white ? value : -value;
      }
    }
    return engine.currentTurn == PieceColor.white ? score : -score;
  }

  static int _pieceValue(PieceType type) => switch (type) {
        PieceType.pawn => 100,
        PieceType.knight => 320,
        PieceType.bishop => 330,
        PieceType.rook => 500,
        PieceType.queen => 900,
        PieceType.king => 20000,
      };

  // Piece-square tables (simplified)
  static const List<List<int>> _pawnTable = [
    [0, 0, 0, 0, 0, 0, 0, 0],
    [50, 50, 50, 50, 50, 50, 50, 50],
    [10, 10, 20, 30, 30, 20, 10, 10],
    [5, 5, 10, 25, 25, 10, 5, 5],
    [0, 0, 0, 20, 20, 0, 0, 0],
    [5, -5, -10, 0, 0, -10, -5, 5],
    [5, 10, 10, -20, -20, 10, 10, 5],
    [0, 0, 0, 0, 0, 0, 0, 0],
  ];

  static const List<List<int>> _knightTable = [
    [-50, -40, -30, -30, -30, -30, -40, -50],
    [-40, -20, 0, 0, 0, 0, -20, -40],
    [-30, 0, 10, 15, 15, 10, 0, -30],
    [-30, 5, 15, 20, 20, 15, 5, -30],
    [-30, 0, 15, 20, 20, 15, 0, -30],
    [-30, 5, 10, 15, 15, 10, 5, -30],
    [-40, -20, 0, 5, 5, 0, -20, -40],
    [-50, -40, -30, -30, -30, -30, -40, -50],
  ];

  static int _positionalBonus(ChessPiece piece, int file, int rank) {
    final r = piece.color == PieceColor.white ? 7 - rank : rank;
    return switch (piece.type) {
      PieceType.pawn => _pawnTable[r][file],
      PieceType.knight => _knightTable[r][file],
      _ => 0,
    };
  }
}

class _AIConfig {
  final int depth;
  final double randomness;
  const _AIConfig({required this.depth, required this.randomness});
}

class _SearchResult {
  final int score;
  final Move? move;
  const _SearchResult({required this.score, this.move});
}

class _TTEntry {
  final int score;
  final int depth;
  final Move? bestMove;
  const _TTEntry({required this.score, required this.depth, this.bestMove});
}
