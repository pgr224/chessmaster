/// AI Coach Controller
/// Core evaluation logic: classifies moves, detects patterns, generates feedback,
/// and provides hints with contextual explanations.
library;

import 'dart:async';
import '../../domain/engine/chess_engine.dart';
import '../../domain/engine/ai_engine.dart';
import '../../data/models/game_config.dart';
import '../../data/models/coach_model.dart';
import 'package:flutter/foundation.dart';

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
  Future<TacticalPattern> detectTacticalPattern(
      ChessEngine engine, Move move) async {
    final after = ChessEngine.fromFEN(engine.toFEN());
    after.applyMoveInternal(move);
    return _detectPattern(engine, after, move);
  }

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
    final rand = DateTime.now().millisecond;
    
    // VARIETY POOLS BY PERSONALITY
    final brilliantPool = switch(personality) {
      CoachPersonality.friendly => ['WOW! Brilliant move! 💎✨', 'Incredible vision! That is brilliant. 🧠', 'That is a masterpiece! 🎨', 'I am speechless! What a find! 🌟'],
      CoachPersonality.strict => ['Excellent. A highly precise find.', 'Precisely as calculated.', 'The engine confirms your brilliance.', 'Mathematically superior move.'],
      CoachPersonality.motivational => ['INCREDIBLE! Grandmaster level play! 🔥', 'You are on fire today! 🎯', 'What a move! Absolutely stunning! 🚀', 'Believe in yourself! That was pure genius! 💪'],
    };

    final bestPool = switch(personality) {
      CoachPersonality.friendly => ['Nice move! That was the best one! ⭐', 'Spot on! You found the top move.', 'Perfect choice!', 'Exactly what I would have done! 😊'],
      CoachPersonality.strict => ['Correct. That was the strongest move.', 'Optimum move executed.', 'Accurate play.', 'Positional advantage maintained.'],
      CoachPersonality.motivational => ['Perfect! Keep up this amazing play! 🚀', 'Exactly! You are dominating the board!', 'Fantastic! Top tier move! 💪', 'Target locked and neutralized! 🎯'],
    };

    final goodPool = switch(personality) {
      CoachPersonality.friendly => ['Good move! 👍', 'I like that idea!', 'Solid choice.', 'Keep it going!'],
      CoachPersonality.strict => ['Acceptable.', 'A reasonable continuation.', 'Standard development.', 'Consistent play.'],
      CoachPersonality.motivational => ['Nice! You are building pressure! ⚡', 'Stay focused, good move!', 'Yes! Keep pushing forward! 🏃', 'Strong initiative!'],
    };

    final improvementPool = switch(personality) {
      CoachPersonality.friendly => ['Not bad, but maybe there was a sharper way? 🤔', 'I see your idea, but look at this...', 'Keep exploring other options too!'],
      CoachPersonality.strict => ['Suboptimal. A better line was available.', 'Inaccurate. You missed a stronger continuation.', 'Technique could be improved.'],
      CoachPersonality.motivational => ['Good effort, but you can do even better! 🚀', 'Push yourself! There was a hidden gem here.', 'Don\'t settle for "good" when you can find "best"!'],
    };

    final blunderPool = switch(personality) {
      CoachPersonality.friendly => ['Oh no! That was a big mistake! 😱', 'Oops! I think you missed something huge.', 'That move hurts a bit... 💔', 'Be careful! That was risky!'],
      CoachPersonality.strict => ['Critical error. Significant advantage lost.', 'That was a blunder. Re-evaluate your process.', 'Unacceptable oversight.', 'Position collapsing due to that error.'],
      CoachPersonality.motivational => ['Don\'t worry! We learn the most from these! 💝', 'Shake it off! Get back in the fight!', 'A temporary setback. Keep focusing! 🧗', 'Failure is the mother of success! Let\'s go!'],
    };

    final mistakePool = switch(personality) {
      CoachPersonality.friendly => ['Oops! You missed something better ⚠️', 'I think we can do better! Look again. 🤔', 'Not quite there, keep looking!', 'Hmm, I see an even better way!'],
      CoachPersonality.strict => ['Inaccurate. A superior line was neglected.', 'Deficient move choice.', 'Technique error detected.', 'Miscalculation identified.'],
      CoachPersonality.motivational => ['Don\'t settle! You missed a golden one! 🚀', 'Push hard! There was a masterpiece here!', 'Keep aiming higher! Use your vision!', 'Stay sharp! A big win was nearby! ⚡'],
    };

    return switch (classification) {
      MoveClassification.brilliant => brilliantPool[_random.nextInt(brilliantPool.length)],
      MoveClassification.best => bestPool[_random.nextInt(bestPool.length)],
      MoveClassification.good => goodPool[_random.nextInt(goodPool.length)],
      MoveClassification.needsImprovement => improvementPool[_random.nextInt(improvementPool.length)],
      MoveClassification.mistake => mistakePool[_random.nextInt(mistakePool.length)],
      MoveClassification.blunder => blunderPool[_random.nextInt(blunderPool.length)],
    };
  }

  // ═══════════════════════════════════════════
  // EXPLANATION BUILDER — Natural Language Hybrid
  // ═══════════════════════════════════════════
  String? _getExplanation(
    MoveClassification classification,
    CoachingLevel level,
    int cpLoss,
    String? bestMove,
    TacticalPattern pattern,
  ) {
    if (classification == MoveClassification.best || classification == MoveClassification.brilliant) {
      if (pattern == TacticalPattern.none) {
        final generalGood = [
          'You improved your position and controlled the flow.',
          'Your piece activity is increasing beautifully.',
          'You are exerting great pressure on the opponent.',
          'Solid positional understanding displayed here.',
          'You are navigating this position with great care and precision.'
        ];
        return generalGood[_random.nextInt(generalGood.length)];
      }
      
      final connectors = [' because', ' as', ', and furthermore', ' since', ', specifically because'];
      final start = 'You found this move';
      final reason = switch(pattern) {
        TacticalPattern.centerControl => ' it dominates the center of the board',
        TacticalPattern.materialGain => ' it wins material and shifts the balance',
        TacticalPattern.development => ' it activates your pieces for the attack',
        TacticalPattern.checkmate => ' it secures the victory immediately',
        TacticalPattern.kingSafety => ' it fortifies your king against threats',
        TacticalPattern.fork => ' it creates a powerful fork',
        TacticalPattern.discoveredAttack => ' it reveals a dangerous discovered attack',
        TacticalPattern.defensiveMove => ' it stabilizes a critical defensive rank',
        _ => ' it was the most precise option available'
      };
      
      return '$start${connectors[_random.nextInt(connectors.length)]}$reason! ♟️';
    }

    final parts = <String>[];

    // Detection for "Missed Opportunity"
    if (cpLoss > 150 && classification == MoveClassification.mistake) {
      parts.add('You missed a big opportunity here.');
    }

    // Pattern explanation
    if (pattern != TacticalPattern.none) {
      final patternAction = switch(pattern) {
          TacticalPattern.materialLoss => 'You unfortunately lost material here',
          TacticalPattern.hangingPiece => 'This leaves a piece undefended',
          TacticalPattern.trappedPiece => 'Your piece is now trapped with no escape',
          TacticalPattern.backRankWeakness => 'Your back rank is looking vulnerable',
          _ => 'It seems you overlooked the ${pattern.explanation}'
      };
      parts.add(patternAction);
    } else if (classification == MoveClassification.blunder) {
      parts.add('This move allows the opponent to gain a massive advantage.');
    } else {
      final fallbacks = switch(_settings.personality) {
        CoachPersonality.friendly => [
          'There was a much sharper continuation available. Do you see it?',
          'The engine suggests a more direct approach here.',
          'This move slightly loosens your grip on the position.',
          'Maybe consider a more active way to challenge the opponent?',
          'Look for a way to create more pressure next time!'
        ],
        CoachPersonality.strict => [
          'Sub-optimal precision. The engine prefers a direct line.',
          'Inefficient path selection. Advantage diluted.',
          'Lacks the critical edge required here.',
          'Strict performance requires the most direct tactical choice.'
        ],
        CoachPersonality.motivational => [
          'Keep pushing for the sharpest lines! You can do it!',
          'There was a faster way to victory! Reach for it!',
          'Don\'t hold back! Search for the most aggressive move!',
          'Believe in your calculation! A killer move was possible!'
        ],
      };
      parts.add(fallbacks[_random.nextInt(fallbacks.length)]);
    }

    // Best move suggestion (Connective logic)
    if (bestMove != null && classification.index >= MoveClassification.needsImprovement.index) {
      final transition = parts.isNotEmpty ? ' Instead, ' : 'A better idea was ';
      if (level == CoachingLevel.beginner) {
        final toSquare = bestMove.length >= 4 ? bestMove.substring(2, 4) : 'the target square';
        parts.add('${transition}looking at square $toSquare would have been better.');
      } else {
        parts.add('${transition}playing $bestMove was the winning line.');
      }
    }

    return parts.isEmpty ? null : parts.join('\n');
  }

  // ═══════════════════════════════════════════
  // HINT SYSTEM — On Demand
  // ═══════════════════════════════════════════

  /// Returns a hint for the current position with 4 levels of detail.
  /// Level 1: General direction
  /// Level 2: Piece suggestion
  /// Level 3: Square highlight
  /// Level 4: Full move
  Future<HintResult?> getHint(ChessEngine engine) async {
    try {
      final topMoves = await AIEngine.getTopMoves(
        engine,
        _difficulty,
        count: 3,
      );

      if (topMoves.isEmpty) return null;

      final bestMoveScored = topMoves.first;
      final altMoveScored = topMoves.length > 1 ? topMoves[1] : null;

      final bestMove = bestMoveScored.$1;
      final altMove = altMoveScored?.$1;

      final pattern = await detectTacticalPattern(engine, bestMove);
      final piece = engine.pieceAt(bestMove.from);
      final targetSq = bestMove.toAlgebraic().substring(2, 4);

      // Level 1: General Category
      String level1 = switch (pattern) {
        TacticalPattern.checkmate => "There is a way to end the game now!",
        TacticalPattern.materialGain => "Look for a way to win some material.",
        TacticalPattern.fork => "One of your pieces can attack two targets.",
        TacticalPattern.pin => "You can restrict one of their pieces.",
        TacticalPattern.pawnPromotion => "Your pawn is very close to glory.",
        TacticalPattern.discoveredAttack => "Moving one piece reveals a hidden threat.",
        TacticalPattern.centerControl => "Try to exert more control over the center.",
        TacticalPattern.development => "It's time to bring more pieces into the action.",
        TacticalPattern.kingSafety => "Your king needs a bit more protection.",
        _ => "Look for a forced sequence or a positional improvement.",
      };

      // Level 2: Piece Suggestion
      String level2 = piece != null
          ? "Consider moving your ${piece.type.coachName}."
          : "Try to find the best square for one of your pieces.";

      // Level 3: Square Highlight
      String level3 = "Look closely at the square $targetSq.";

      // Level 4: Full Move Reveal
      String level4 = pattern != TacticalPattern.none
          ? "You should play ${bestMove.toAlgebraic()} to execute a ${pattern.label}!"
          : "The engine suggests ${bestMove.toAlgebraic()} as the strongest continuation.";

      return HintResult(
        bestMoveAlgebraic: bestMove.toAlgebraic(),
        level1: level1,
        level2: level2,
        level3: level3,
        level4: level4,
        alternativeMoveAlgebraic: altMove?.toAlgebraic(),
        pattern: pattern,
        xpCost: 10,
        currentLevel: 1,
      );
    } catch (e) {
      debugPrint('[Coach Hint Error] $e');
      return null;
    }
  }


  // ═══════════════════════════════════════════
  // POST-GAME ANALYSIS
  // ═══════════════════════════════════════════
  PostGameAnalysis buildPostGameAnalysis({
    required double accuracy,
    required int totalMoves,
    int brilliantMoves = 0,
    int bestMoves = 0,
    int goodMoves = 0,
    int needsImprovementMoves = 0,
    int mistakes = 0,
    int blunders = 0,
    int missedWins = 0,
    List<CoachFeedback> moveAnalysis = const [],
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

  void dispose() {
    _evalCache.clear();
  }
}

// Utility extension for Move classification
extension MoveClassificationValue on MoveClassification {
  bool get isNegative =>
      this == MoveClassification.mistake || this == MoveClassification.blunder;
}
