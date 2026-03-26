import 'dart:isolate';
import 'dart:math';
import '../engine/chess_engine.dart';
import '../../data/models/game_config.dart';

class AIEngine {
  static const Map<AIDifficulty, _AIConfig> _configs = {
    AIDifficulty.basic:        _AIConfig(depth: 1, randomness: 0.7),
    AIDifficulty.intermediate: _AIConfig(depth: 4, randomness: 0.1),
    AIDifficulty.advanced:     _AIConfig(depth: 5, randomness: 0.0),
    AIDifficulty.impossible:   _AIConfig(depth: 6, randomness: 0.0),
  };

  // Transposition Table for memoizing search results
  static final Map<String, _TTEntry> _tt = {};
  
  // Opening Book: Common starters for instant play
  static const Map<String, String> _openingBook = {
    'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1': 'e2e4', // King's Pawn
    'rnbqkbnr/pppppppp/8/8/4P3/8/PPPPPPPP/RNBQKBNR b KQkq e3 0 1': 'c7c5', // Sicilian Defense
    'rnbqkbnr/pppppppp/8/8/3P4/8/PPP1PPPP/RNBQKBNR b KQkq d3 0 1': 'd7d5', // Queen's Gambit setup
    'rnbqkbnr/pp1ppppp/8/2p5/4P3/8/PPPP1PPP/RNBQKBNR w KQkq c6 0 2': 'g1f3', // Open Sicilian
  };

  static Future<Move?> getBestMove(
    ChessEngine engine,
    AIDifficulty difficulty, {
    Duration timeout = const Duration(seconds: 5),
  }) async {
    // Run AI search on a background isolate so UI actions stay responsive.
    final fenSnapshot = engine.toFEN();
    final bestMoveAlg = await Isolate.run<String?>(() {
      final isolatedEngine = ChessEngine.fromFEN(fenSnapshot);
      final move = _getBestMoveSync(isolatedEngine, difficulty, timeout: timeout);
      return move?.toAlgebraic();
    });

    if (bestMoveAlg == null) return null;
    final legalMoves = engine.allLegalMoves();
    return legalMoves.where((m) => m.toAlgebraic() == bestMoveAlg).firstOrNull;
  }

  static Move? _getBestMoveSync(
    ChessEngine engine,
    AIDifficulty difficulty, {
    Duration timeout = const Duration(seconds: 5),
  }) {
    final startTime = DateTime.now();
    final config = _configs[difficulty]!;
    final fen = engine.toFEN();

    // 1. Check Opening Book
    if (_openingBook.containsKey(fen)) {
      final san = _openingBook[fen]!;
      final moves = engine.allLegalMoves();
      return moves.where((m) => m.toAlgebraic() == san).firstOrNull ?? moves.first;
    }

    // 2. Iterative Deepening
    Move? bestMove;
    int currentDepth = 1;
    
    // Clear TT occasionally to avoid memory issues on web
    if (_tt.length > 50000) _tt.clear();

    while (currentDepth <= config.depth) {
      final elapsed = DateTime.now().difference(startTime);
      if (elapsed > timeout && currentDepth > 1) break;

      final result = _search(engine, currentDepth, -999999, 999999);
      if (result.move != null) bestMove = result.move;
      
      currentDepth++;
    }

    return bestMove ?? engine.allLegalMoves().firstOrNull;
  }

  static _SearchResult _search(ChessEngine engine, int depth, int alpha, int beta) {
    if (depth == 0) return _SearchResult(score: _quiescence(engine, alpha, beta));

    final fen = engine.toFEN();
    if (_tt.containsKey(fen)) {
      final entry = _tt[fen]!;
      if (entry.depth >= depth) return _SearchResult(score: entry.score, move: entry.bestMove);
    }

    final moves = engine.allLegalMoves();
    if (moves.isEmpty) {
      if (engine.status == GameStatus.checkmate) return _SearchResult(score: -100000 - depth);
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
      engine.applyMoveInternal(move);
      final score = -_search(engine, depth - 1, -beta, -alpha).score;
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

  static int _quiescence(ChessEngine engine, int alpha, int beta) {
    int standPat = _evaluate(engine);
    if (standPat >= beta) return beta;
    if (alpha < standPat) alpha = standPat;

    final moves = engine.allLegalMoves().where((m) => m.capturedPiece != null).toList();
    for (final move in moves) {
      engine.applyMoveInternal(move);
      final score = -_quiescence(engine, -beta, -alpha);
      engine.undoMove();

      if (score >= beta) return beta;
      if (score > alpha) alpha = score;
    }
    return alpha;
  }

  static int _evaluate(ChessEngine engine) {
    if (engine.status == GameStatus.checkmate) return -100000;
    if (engine.status == GameStatus.stalemate || engine.status == GameStatus.draw) return 0;

    int score = 0;
    final board = engine.board;

    for (int r = 0; r < 8; r++) {
      for (int f = 0; f < 8; f++) {
        final piece = board[r][f];
        if (piece == null) continue;

        final value = _pieceValue(piece.type) + _positionalBonus(piece, f, r);
        score += piece.color == PieceColor.white ? value : -value;
      }
    }
    return engine.currentTurn == PieceColor.white ? score : -score;
  }

  static int _pieceValue(PieceType type) => switch (type) {
    PieceType.pawn   => 100,
    PieceType.knight => 320,
    PieceType.bishop => 330,
    PieceType.rook   => 500,
    PieceType.queen  => 900,
    PieceType.king   => 20000,
  };

  // Piece-square tables (simplified)
  static const List<List<int>> _pawnTable = [
    [0, 0, 0, 0, 0, 0, 0, 0],
    [50,50,50,50,50,50,50,50],
    [10,10,20,30,30,20,10,10],
    [5, 5,10,25,25,10, 5, 5],
    [0, 0, 0,20,20, 0, 0, 0],
    [5,-5,-10, 0, 0,-10,-5, 5],
    [5,10,10,-20,-20,10,10, 5],
    [0, 0, 0, 0, 0, 0, 0, 0],
  ];

  static const List<List<int>> _knightTable = [
    [-50,-40,-30,-30,-30,-30,-40,-50],
    [-40,-20,  0,  0,  0,  0,-20,-40],
    [-30,  0, 10, 15, 15, 10,  0,-30],
    [-30,  5, 15, 20, 20, 15,  5,-30],
    [-30,  0, 15, 20, 20, 15,  0,-30],
    [-30,  5, 10, 15, 15, 10,  5,-30],
    [-40,-20,  0,  5,  5,  0,-20,-40],
    [-50,-40,-30,-30,-30,-30,-40,-50],
  ];

  static int _positionalBonus(ChessPiece piece, int file, int rank) {
    final r = piece.color == PieceColor.white ? 7 - rank : rank;
    return switch (piece.type) {
      PieceType.pawn   => _pawnTable[r][file],
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
