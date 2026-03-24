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

  static Future<Move?> getBestMove(
    ChessEngine engine,
    AIDifficulty difficulty, {
    Duration timeout = const Duration(seconds: 10),
  }) async {
    final config = _configs[difficulty]!;
    final fen = engine.toFEN();

    // Run synchronously (avoids serialization issues on web with compute())
    return _computeMove(fen, config);
  }

  static Move? _computeMove(String fen, _AIConfig config) {
    final engine = ChessEngine.fromFEN(fen);
    final moves = engine.allLegalMoves();
    if (moves.isEmpty) return null;

    // Random factor for lower difficulties
    if (Random().nextDouble() < config.randomness) {
      return moves[Random().nextInt(moves.length)];
    }

    // Minimax with alpha-beta pruning
    Move? bestMove;
    int bestScore = -999999;

    for (final move in moves) {
      final newEngine = ChessEngine.fromFEN(fen);
      newEngine.makeMove(move);
      final score = -_minimax(newEngine, config.depth - 1, -999999, 999999);
      if (score > bestScore) {
        bestScore = score;
        bestMove = move;
      }
    }
    return bestMove;
  }

  static int _minimax(ChessEngine engine, int depth, int alpha, int beta) {
    if (depth == 0 || engine.status == GameStatus.checkmate ||
        engine.status == GameStatus.stalemate || engine.status == GameStatus.draw) {
      return _evaluate(engine);
    }

    final moves = engine.allLegalMoves();
    // Move ordering: captures first (improves alpha-beta efficiency)
    moves.sort((a, b) => (b.capturedPiece != null ? 1 : 0) - (a.capturedPiece != null ? 1 : 0));

    int value = -999999;
    for (final move in moves) {
      final newEngine = ChessEngine.fromFEN(engine.toFEN());
      newEngine.makeMove(move);
      value = max(value, -_minimax(newEngine, depth - 1, -beta, -alpha));
      alpha = max(alpha, value);
      if (alpha >= beta) break; // Alpha-beta cutoff
    }
    return value;
  }

  static int _evaluate(ChessEngine engine) {
    if (engine.status == GameStatus.checkmate) {
      return engine.currentTurn == PieceColor.white ? -10000 : 10000;
    }
    if (engine.status == GameStatus.stalemate || engine.status == GameStatus.draw) {
      return 0;
    }

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

    // Adjust relative to who's to move
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
