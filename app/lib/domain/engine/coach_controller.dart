/// AI Coach Controller
/// Core evaluation logic: classifies moves, detects patterns, generates feedback,
/// and provides hints with contextual explanations.
library;

import 'dart:async';
import '../../domain/engine/chess_engine.dart';
import '../../domain/engine/ai_engine.dart';
import '../../data/models/game_config.dart';
import '../../data/models/coach_model.dart';

class CoachController {
  // ═══════════════════════════════════════════
  // CONFIGURATION
  // ═══════════════════════════════════════════
  CoachSettings _settings;
  AIDifficulty _difficulty;

  // Evaluation cache to avoid redundant computation
  final Map<String, int> _evalCache = {};

  CoachController({
    CoachSettings? settings,
    AIDifficulty difficulty = AIDifficulty.intermediate,
  })  : _settings = settings ?? const CoachSettings(),
        _difficulty = difficulty;

  CoachSettings get settings => _settings;

  void updateSettings(CoachSettings settings) => _settings = settings;
  void updateDifficulty(AIDifficulty diff) => _difficulty = diff;

  // ═══════════════════════════════════════════
  // MOVE EVALUATION — Core Analysis
  // ═══════════════════════════════════════════

  /// Evaluates a player's move by comparing it to the engine's best move.
  /// Returns a [CoachFeedback] with classification, message, and explanation.
  ///
  /// [engineBeforeMove] - A snapshot of the engine BEFORE the player's move
  /// [playedMove] - The move the player actually made
  /// [engineAfterMove] - The engine AFTER the move was made
  Future<CoachFeedback> evaluateMove({
    required ChessEngine engineBeforeMove,
    required Move playedMove,
    required ChessEngine engineAfterMove,
  }) async {
    try {
      // Get the best move from the position before the player moved
      final topMoves = await AIEngine.getTopMoves(
        engineBeforeMove,
        _difficulty,
        count: 3,
      );

      if (topMoves.isEmpty) {
        return _buildFeedback(MoveClassification.good, 0, null, null);
      }

      final bestMove = topMoves[0];
      final bestMoveScore = bestMove.$2;
      final playedMoveStr = playedMove.toAlgebraic();
      final bestMoveStr = bestMove.$1.toAlgebraic();

      // Check if the played move IS the best move
      if (playedMoveStr == bestMoveStr) {
        // It's the best move! Check if it's brilliant (was it the ONLY good move?)
        if (topMoves.length >= 2) {
          final secondBestScore = topMoves[1].$2;
          final gap = bestMoveScore - secondBestScore;
          if (gap > 200) {
            return _buildFeedback(
              MoveClassification.brilliant,
              0,
              bestMoveStr,
              null,
              pattern:
                  _detectPattern(engineBeforeMove, engineAfterMove, playedMove),
            );
          }
        }
        return _buildFeedback(MoveClassification.best, 0, bestMoveStr, null);
      }

      // Find the played move's score among top moves
      int? playedScore;
      for (final tm in topMoves) {
        if (tm.$1.toAlgebraic() == playedMoveStr) {
          playedScore = tm.$2;
          break;
        }
      }

      // If not in top moves, evaluate separately
      playedScore ??= -(await AIEngine.evaluatePosition(engineAfterMove));

      final centipawnLoss = bestMoveScore - playedScore;

      // Classify the move
      final classification = _classifyMove(centipawnLoss);

      // Detect tactical pattern
      final pattern =
          _detectPattern(engineBeforeMove, engineAfterMove, playedMove);

      // Find alternative move
      String? altMove;
      if (topMoves.length >= 2 &&
          topMoves[1].$1.toAlgebraic() != playedMoveStr) {
        altMove = topMoves[1].$1.toAlgebraic();
      }

      return _buildFeedback(
        classification,
        centipawnLoss,
        bestMoveStr,
        altMove,
        pattern: pattern,
      );
    } catch (e) {
      // Fallback — don't crash if evaluation fails
      return _buildFeedback(MoveClassification.good, 0, null, null);
    }
  }

  // ═══════════════════════════════════════════
  // MOVE CLASSIFICATION — Centipawn Logic
  // ═══════════════════════════════════════════
  MoveClassification _classifyMove(int centipawnLoss) {
    if (centipawnLoss < 20) return MoveClassification.best;
    if (centipawnLoss < 50) return MoveClassification.good;
    if (centipawnLoss < 100) return MoveClassification.needsImprovement;
    if (centipawnLoss < 500) return MoveClassification.mistake;
    return MoveClassification.blunder;
  }

  // ═══════════════════════════════════════════
  // PATTERN DETECTION
  // ═══════════════════════════════════════════
  TacticalPattern _detectPattern(
    ChessEngine before,
    ChessEngine after,
    Move move,
  ) {
    // Check for checkmate
    if (after.status == GameStatus.checkmate) {
      return TacticalPattern.checkmate;
    }

    // Detect material gain (capture)
    if (move.capturedPiece != null) {
      return TacticalPattern.materialGain;
    }

    // Detect check
    if (after.status == GameStatus.check) {
      // Could be a fork if after check, another piece is under attack
      return TacticalPattern.fork;
    }

    // Detect pawn promotion opportunity
    final piece = before.pieceAt(move.from);
    if (piece?.type == PieceType.pawn) {
      final promoRank = piece!.color == PieceColor.white ? 6 : 1;
      if (move.to.rank == promoRank || move.promotion != null) {
        return TacticalPattern.pawnPromotion;
      }
    }

    // Detect center control (e4, d4, e5, d5)
    final centerSquares = [
      const Square(3, 3),
      const Square(4, 3),
      const Square(3, 4),
      const Square(4, 4),
    ];
    if (centerSquares.any((s) => s == move.to)) {
      return TacticalPattern.centerControl;
    }

    // Detect piece development (moving from back rank)
    if (piece != null && piece.type != PieceType.pawn) {
      final homeRank = piece.color == PieceColor.white ? 0 : 7;
      if (move.from.rank == homeRank && move.to.rank != homeRank) {
        return TacticalPattern.development;
      }
    }

    // Detect castling (king safety)
    if (move.isCastle) {
      return TacticalPattern.kingSafety;
    }

    return TacticalPattern.none;
  }

  // ═══════════════════════════════════════════
  // FEEDBACK CONSTRUCTION — Personality-Aware
  // ═══════════════════════════════════════════
  CoachFeedback _buildFeedback(
    MoveClassification classification,
    int cpLoss,
    String? bestMove,
    String? altMove, {
    TacticalPattern pattern = TacticalPattern.none,
  }) {
    final personality = _settings.personality;
    final level = _settings.level;

    final message = _getMessage(classification, personality, pattern);
    final explanation =
        _getExplanation(classification, level, cpLoss, bestMove, pattern);

    return CoachFeedback(
      classification: classification,
      message: message,
      explanation: explanation,
      pattern: pattern,
      centipawnLoss: cpLoss,
      bestMoveAlgebraic: bestMove,
      bestMoveExplanation: pattern != TacticalPattern.none
          ? '${pattern.emoji} ${pattern.explanation}'
          : null,
      alternativeMoveAlgebraic: altMove,
      showUndo: classification == MoveClassification.blunder,
      timestamp: DateTime.now(),
    );
  }

  // ═══════════════════════════════════════════
  // MESSAGE TEMPLATES — By Personality
  // ═══════════════════════════════════════════
  String _getMessage(
    MoveClassification classification,
    CoachPersonality personality,
    TacticalPattern pattern,
  ) {
    return switch (personality) {
      CoachPersonality.friendly => _friendlyMessage(classification, pattern),
      CoachPersonality.strict => _strictMessage(classification, pattern),
      CoachPersonality.motivational =>
        _motivationalMessage(classification, pattern),
    };
  }

  String _friendlyMessage(MoveClassification c, TacticalPattern p) {
    return switch (c) {
      MoveClassification.brilliant => 'WOW! Brilliant move! 💎✨',
      MoveClassification.best => 'Nice move! That was the best one! ⭐',
      MoveClassification.good => 'Good move! 👍',
      MoveClassification.needsImprovement =>
        'Not bad, but there was a stronger option 🤔',
      MoveClassification.mistake => 'Oops! You missed something better ⚠️',
      MoveClassification.blunder => 'Oh no! That was a big mistake! 😱',
    };
  }

  String _strictMessage(MoveClassification c, TacticalPattern p) {
    return switch (c) {
      MoveClassification.brilliant => 'Excellent. A precise move.',
      MoveClassification.best => 'Correct. That was the strongest move.',
      MoveClassification.good => 'Acceptable move.',
      MoveClassification.needsImprovement =>
        'That was inaccurate. Think deeper.',
      MoveClassification.mistake =>
        'That was a mistake. Analyze before moving.',
      MoveClassification.blunder =>
        'Critical error. You lost significant advantage.',
    };
  }

  String _motivationalMessage(MoveClassification c, TacticalPattern p) {
    return switch (c) {
      MoveClassification.brilliant =>
        'INCREDIBLE! You played like a grandmaster! 🔥',
      MoveClassification.best => 'Perfect! Keep up this amazing play! 🚀',
      MoveClassification.good => 'Great job! You\'re getting stronger! 💪',
      MoveClassification.needsImprovement =>
        'So close! You\'re improving every move! 📈',
      MoveClassification.mistake =>
        'That\'s OK! Champions learn from mistakes! 🌟',
      MoveClassification.blunder =>
        'Don\'t worry! Every master was once a beginner! 💝',
    };
  }

  // ═══════════════════════════════════════════
  // EXPLANATION BUILDER — Skill-Adaptive
  // ═══════════════════════════════════════════
  String? _getExplanation(
    MoveClassification classification,
    CoachingLevel level,
    int cpLoss,
    String? bestMove,
    TacticalPattern pattern,
  ) {
    if (classification == MoveClassification.best ||
        classification == MoveClassification.brilliant) {
      if (pattern != TacticalPattern.none) {
        return '${pattern.emoji} This ${pattern.explanation}';
      }
      return null;
    }

    final parts = <String>[];

    // Pattern explanation
    if (pattern != TacticalPattern.none) {
      parts.add('${pattern.emoji} ${pattern.explanation}');
    }

    // Best move suggestion (don't reveal full solution instantly)
    if (bestMove != null &&
        classification.index >= MoveClassification.needsImprovement.index) {
      if (level == CoachingLevel.beginner) {
        // Beginner: hint at the square without full move
        final toSquare = bestMove.substring(2, 4);
        parts.add('💡 Look at square $toSquare');
      } else {
        // Intermediate/Advanced: show the best move
        parts.add('💡 Better was $bestMove');
      }
    }

    return parts.isEmpty ? null : parts.join('\n');
  }

  // ═══════════════════════════════════════════
  // HINT SYSTEM — On Demand
  // ═══════════════════════════════════════════

  /// Returns a hint for the current position.
  /// Each hint costs 10 XP.
  Future<HintResult?> getHint(ChessEngine engine) async {
    try {
      final topMoves = await AIEngine.getTopMoves(
        engine,
        _difficulty,
        count: 2,
      );

      if (topMoves.isEmpty) return null;

      final bestMove = topMoves[0];
      final bestMoveStr = bestMove.$1.toAlgebraic();

      // Build explanation
      final pattern = _detectPatternForHint(engine, bestMove.$1);
      String explanation;

      if (pattern != TacticalPattern.none) {
        explanation = _buildHintExplanation(bestMove.$1, pattern, engine);
      } else {
        explanation = _buildGenericHintExplanation(bestMove.$1, engine);
      }

      String? altMoveStr;
      if (topMoves.length >= 2) {
        altMoveStr = topMoves[1].$1.toAlgebraic();
      }

      return HintResult(
        bestMoveAlgebraic: bestMoveStr,
        shortExplanation: explanation,
        alternativeMoveAlgebraic: altMoveStr,
        pattern: pattern,
        xpCost: 10,
      );
    } catch (e) {
      return null;
    }
  }

  TacticalPattern _detectPatternForHint(ChessEngine engine, Move move) {
    final piece = engine.pieceAt(move.from);
    if (piece == null) return TacticalPattern.none;

    // Check for capture
    final target = engine.pieceAt(move.to);
    if (target != null) return TacticalPattern.materialGain;

    // Check for castling
    if (move.isCastle) return TacticalPattern.kingSafety;

    // Check pawn promotion
    if (piece.type == PieceType.pawn && move.promotion != null) {
      return TacticalPattern.pawnPromotion;
    }

    // Center control
    final centerSquares = [
      const Square(3, 3),
      const Square(4, 3),
      const Square(3, 4),
      const Square(4, 4),
    ];
    if (centerSquares.any((s) => s == move.to)) {
      return TacticalPattern.centerControl;
    }

    // Development
    final homeRank = piece.color == PieceColor.white ? 0 : 7;
    if (piece.type != PieceType.pawn &&
        move.from.rank == homeRank &&
        move.to.rank != homeRank) {
      return TacticalPattern.development;
    }

    return TacticalPattern.none;
  }

  String _buildHintExplanation(
      Move move, TacticalPattern pattern, ChessEngine engine) {
    final piece = engine.pieceAt(move.from);
    if (piece == null) return 'Try this move!';

    final pieceName = _pieceName(piece.type);

    return switch (pattern) {
      TacticalPattern.fork =>
        'Try moving your $pieceName to attack two pieces at once! 🔱',
      TacticalPattern.pin => 'Pin the opponent\'s piece so it can\'t move! 📌',
      TacticalPattern.materialGain => 'There\'s a piece you can capture! 💰',
      TacticalPattern.kingSafety => 'Castle to protect your king! 🏰',
      TacticalPattern.centerControl =>
        'Control the center with your $pieceName! 🎯',
      TacticalPattern.development =>
        'Develop your $pieceName to a better square! 🚀',
      TacticalPattern.pawnPromotion => 'Push your pawn to become a queen! 👑',
      TacticalPattern.checkmate => 'There\'s a checkmate available! 🏆',
      _ => 'Try moving your $pieceName for a strong position! ♟️',
    };
  }

  String _buildGenericHintExplanation(Move move, ChessEngine engine) {
    final piece = engine.pieceAt(move.from);
    if (piece == null) return 'Try this move!';
    final pieceName = _pieceName(piece.type);
    final toSquare = move.to.toAlgebraic();
    return 'Move your $pieceName to $toSquare for a stronger position ♟️';
  }

  String _pieceName(PieceType type) => switch (type) {
        PieceType.pawn => 'pawn',
        PieceType.knight => 'knight',
        PieceType.bishop => 'bishop',
        PieceType.rook => 'rook',
        PieceType.queen => 'queen',
        PieceType.king => 'king',
      };

  // ═══════════════════════════════════════════
  // POST-GAME ANALYSIS
  // ═══════════════════════════════════════════
  PostGameAnalysis buildPostGameAnalysis({
    required double accuracy,
    required int totalMoves,
    required int brilliantMoves,
    required int bestMoves,
    required int goodMoves,
    required int needsImprovementMoves,
    required int mistakes,
    required int blunders,
    required int missedWins,
    required List<CoachFeedback> moveAnalysis,
  }) {
    String overallMessage;
    String improvementTip;

    if (accuracy >= 90) {
      overallMessage = '🏆 Incredible accuracy! You played like a Grandmaster!';
      improvementTip = 'Try harder opponents to keep growing!';
    } else if (accuracy >= 80) {
      overallMessage = '🚀 Excellent game! Very precise play!';
      improvementTip =
          'Focus on the middlegame tactics to reach the next level.';
    } else if (accuracy >= 60) {
      overallMessage = '🔥 Solid performance! Room for improvement.';
      improvementTip = 'Practice tactical puzzles to sharpen your vision.';
    } else if (accuracy >= 40) {
      overallMessage = '💎 Good effort! Keep practicing!';
      improvementTip =
          'Take more time before each move. Look for captures and checks first.';
    } else {
      overallMessage = '💪 Every game is a learning opportunity!';
      improvementTip =
          'Try playing slower games to build your pattern recognition.';
    }

    return PostGameAnalysis(
      accuracy: accuracy,
      totalMoves: totalMoves,
      brilliantMoves: brilliantMoves,
      bestMoves: bestMoves,
      goodMoves: goodMoves,
      needsImprovementMoves: needsImprovementMoves,
      mistakes: mistakes,
      blunders: blunders,
      missedWins: missedWins,
      moveAnalysis: moveAnalysis,
      overallMessage: overallMessage,
      improvementTip: improvementTip,
    );
  }

  // ═══════════════════════════════════════════
  // CLEANUP
  // ═══════════════════════════════════════════
  void clearCache() {
    _evalCache.clear();
  }

  void dispose() {
    _evalCache.clear();
  }
}
