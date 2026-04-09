/// AI Coach Controller
/// Core evaluation logic: classifies moves, detects patterns, generates feedback,
/// and provides hints with contextual explanations.
library;

import 'dart:async';
import 'dart:math' as math;
import '../../domain/engine/chess_engine.dart';
import '../../domain/engine/ai_engine.dart';
import '../../domain/engine/candidate_model.dart';
import '../../data/models/game_config.dart';
import '../../data/models/coach_model.dart';
import 'package:flutter/foundation.dart';

class CoachController {
  final math.Random _random = math.Random();
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
          'There was a much sharper continuation available. Do you see it? 🤔',
          'The engine suggests a more direct approach here.',
          'This move slightly loosens your grip on the position.',
          'Maybe consider a more active way to challenge the opponent?',
          'Look for a way to create more pressure next time! ✨'
        ],
        CoachPersonality.strict => [
          'Sub-optimal precision. The engine prefers a direct line.',
          'Inefficient path selection. Advantage diluted.',
          'Lacks the critical edge required here.',
          'Strict performance requires the most direct tactical choice.'
        ],
        CoachPersonality.motivational => [
          'Keep pushing for the sharpest lines! You can do it! 💪',
          'There was a faster way to victory! Reach for it!',
          'Don\'t hold back! Search for the most aggressive move! 🔥',
          'Believe in your calculation! A killer move was possible! 🚀'
        ],
      };
      parts.add(fallbacks[_random.nextInt(fallbacks.length)]);
    }

    // Best move suggestion (Connective logic)
    if (bestMove != null && classification.index >= MoveClassification.needsImprovement.index) {
      final transition = parts.isNotEmpty ? ' Instead, ' : 'A better idea was ';
      if (level == CoachingLevel.beginner) {
        final toSquare = bestMove.length >= 4 ? bestMove.substring(2, 4) : 'the target square';
        parts.add('Looking at square $toSquare would have been better.');
      } else {
        parts.add('Playing $bestMove was the winning line.');
      }
    }

    return parts.isEmpty ? null : parts.join('\n');
  }

  // ═══════════════════════════════════════════
  // HINT SYSTEM — On Demand
  // ═══════════════════════════════════════════

  /// Returns a 3-tier progressive hint for the current position.
  ///
  /// Level costs: L1=5 XP, L2=10 XP, L3=20 XP
  ///
  /// L1 — Concept:   What tactical theme applies? (cheapest, lowest spoiler)
  /// L2 — Direction: Which piece + general destination area
  /// L3 — Full Move: Exact move with rich tactical rationale ("Best Move")
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
      final bestScore = bestMoveScored.$2;
      final altMove = altMoveScored?.$1;
      final altScore = altMoveScored?.$2 ?? 0;

      final pattern = await detectTacticalPattern(engine, bestMove);
      final piece = engine.pieceAt(bestMove.from);
      final pieceName = piece?.type.coachName ?? 'piece';

      // Parse board squares to human-readable form
      final fromFile = _fileLabel(bestMove.from.file);
      final fromRank = bestMove.from.rank + 1;
      final toFile = _fileLabel(bestMove.to.file);
      final toRank = bestMove.to.rank + 1;
      final toSq = '$toFile$toRank';      // e.g. "d5"
      final fromSq = '$fromFile$fromRank'; // e.g. "c3"

      // Destination area description (e.g., "center", "kingside", etc.)
      final areaDesc = _describeArea(bestMove.to.file, bestMove.to.rank);

      // Gap between best and 2nd best — indicates if this is forced/critical
      final scoreDiff = (bestScore - altScore).abs();
      final isCritical = scoreDiff > 150;

      // Capture context
      final capturedPiece = bestMove.capturedPiece;
      final captureDesc = capturedPiece != null
          ? 'capturing their ${capturedPiece.type.coachName}'
          : null;

      // ─── LEVEL 1: CONCEPT / THEME ──────────────────────────────────────────
      // Pure strategic/tactical concept — NO piece or square revealed
      final String level1 = _buildConceptHint(pattern, isCritical, engine, bestMove);

      // ─── LEVEL 2: DIRECTION ────────────────────────────────────────────────
      // Reveals: which piece type, and general destination area
      final String level2 = _buildDirectionHint(
        pieceName: pieceName,
        areaDesc: areaDesc,
        pattern: pattern,
        captureDesc: captureDesc,
        fromSq: fromSq,
        toSq: toSq,
        scoreDiff: scoreDiff,
      );

      // ─── LEVEL 3: BEST MOVE ─────────────────────────────────────────────────
      // Full move reveal with detailed tactical justification
      final String level3 = _buildFullMoveHint(
        bestMove: bestMove,
        pieceName: pieceName,
        fromSq: fromSq,
        toSq: toSq,
        pattern: pattern,
        captureDesc: captureDesc,
        bestScore: bestScore,
        altMove: altMove,
        scoreDiff: scoreDiff,
        isCritical: isCritical,
      );

      return HintResult(
        bestMoveAlgebraic: bestMove.toAlgebraic(),
        level1: level1,
        level2: level2,
        level3: level3,
        alternativeMoveAlgebraic: altMove?.toAlgebraic(),
        pattern: pattern,
        xpCostLevel1: 5,
        xpCostLevel2: 10,
        xpCostLevel3: 20,
        currentLevel: 1,
      );
    } catch (e) {
      debugPrint('[Coach Hint Error] $e');
      return null;
    }
  }

  // ── HINT BUILDERS ────────────────────────────────────────────────────────

  String _buildConceptHint(
    TacticalPattern pattern,
    bool isCritical,
    ChessEngine engine,
    Move bestMove,
  ) {
    final prefix = isCritical ? "⚡ This position is critical! " : "";
    return switch (pattern) {
      TacticalPattern.checkmate =>
        "${prefix}There is a forced checkmate available in this position. Find the move that ends the game!",
      TacticalPattern.materialGain =>
        "${prefix}You have an opportunity to win material. Look for a capture that gains you something for free or in trade.",
      TacticalPattern.fork =>
        "${prefix}One of your pieces can attack two of their pieces at the same time — a fork! Look for a move that puts two targets under fire.",
      TacticalPattern.pin =>
        "${prefix}You can pin one of their pieces to a more valuable piece behind it, restricting its movement.",
      TacticalPattern.skewer =>
        "${prefix}A skewer tactic is available — attack a valuable piece that must move, exposing a weaker piece behind it.",
      TacticalPattern.discoveredAttack =>
        "${prefix}Moving one piece will reveal a powerful attack from another. Think about which piece is blocking your battery.",
      TacticalPattern.doubleCheck =>
        "${prefix}A double check is possible — two pieces giving check simultaneously, impossible to block!",
      TacticalPattern.pawnPromotion =>
        "${prefix}One of your pawns is very close to promoting to a queen. Push it forward!",
      TacticalPattern.kingSafety =>
        "${prefix}Your king's safety should be your priority right now. Defend or castle.",
      TacticalPattern.centerControl =>
        "${prefix}Controlling the center gives you a strategic advantage. Look for a move that dominates the d4-d5-e4-e5 area.",
      TacticalPattern.development =>
        "${prefix}Get your pieces into the game! An undeveloped piece is a wasted piece.",
      _ =>
        "${prefix}Look for the most forcing move — checks, captures, and threats, in that order.",
    };
  }

  String _buildDirectionHint({
    required String pieceName,
    required String areaDesc,
    required TacticalPattern pattern,
    required String? captureDesc,
    required String fromSq,
    required String toSq,
    required int scoreDiff,
  }) {
    final captureHint = captureDesc != null ? ", $captureDesc" : "";
    return switch (pattern) {
      TacticalPattern.checkmate =>
        "🎯 Your $pieceName delivers the decisive blow. Move it to the $areaDesc to administer checkmate$captureHint.",
      TacticalPattern.materialGain =>
        "🎯 Your $pieceName can win material. Look at moving it toward $toSq$captureHint.",
      TacticalPattern.fork =>
        "🎯 Your $pieceName is the forking piece. Move it to the $areaDesc — from there it attacks two of their pieces at once$captureHint.",
      TacticalPattern.pin =>
        "🎯 Your $pieceName can create a pin. Align it with their pieces in the $areaDesc.",
      TacticalPattern.discoveredAttack =>
        "🎯 Move your $pieceName away from its current square — doing so unleashes an attack from a piece behind it.",
      TacticalPattern.pawnPromotion =>
        "🎯 Your $pieceName is almost a queen! Push it toward $toSq.",
      TacticalPattern.kingSafety =>
        "🎯 You need to defend. Move your $pieceName toward the $areaDesc to protect your king.",
      TacticalPattern.centerControl =>
        "🎯 Your $pieceName should go to the center. Target the $areaDesc to increase your control.",
      TacticalPattern.development =>
        "🎯 Activate your $pieceName! Bring it from $fromSq into the game, aiming for the $areaDesc.",
      _ =>
        "🎯 Your $pieceName is the key piece. Think about moving it toward $toSq in the $areaDesc$captureHint.",
    };
  }

  String _buildFullMoveHint({
    required Move bestMove,
    required String pieceName,
    required String fromSq,
    required String toSq,
    required TacticalPattern pattern,
    required String? captureDesc,
    required int bestScore,
    required Move? altMove,
    required int scoreDiff,
    required bool isCritical,
  }) {
    final moveUci = bestMove.toAlgebraic();
    final captureStr = captureDesc != null ? ", $captureDesc" : "";
    final urgency = isCritical
        ? "This is the only good move — don't delay!"
        : "The engine rates this as the strongest continuation.";

    final patternExplain = switch (pattern) {
      TacticalPattern.checkmate => "This move delivers checkmate! ♚",
      TacticalPattern.materialGain =>
        "This wins material. $urgency",
      TacticalPattern.fork =>
        "The $pieceName lands on $toSq, forking two of their pieces simultaneously. They can only save one!",
      TacticalPattern.pin =>
        "The $pieceName pins their piece to their king or a higher-value piece.",
      TacticalPattern.skewer =>
        "A skewer — your $pieceName attacks a valuable piece that must retreat, exposing a weaker target behind it.",
      TacticalPattern.discoveredAttack =>
        "Moving the $pieceName from $fromSq reveals a hidden attack by a piece behind it.",
      TacticalPattern.doubleCheck =>
        "This delivers a double check — both the $pieceName and a second piece give check simultaneously. It cannot be blocked!",
      TacticalPattern.pawnPromotion =>
        "Advancing to $toSq promotes this pawn, likely gaining a queen!",
      TacticalPattern.kingSafety =>
        "This defensive move protects critical squares around your king.",
      TacticalPattern.centerControl =>
        "Occupying $toSq gives you a powerful central outpost for the $pieceName.",
      TacticalPattern.development =>
        "Developing the $pieceName to $toSq activates it and improves your position.",
      _ => "Playing $moveUci improves your position and keeps the initiative.",
    };

    final altNote = altMove != null
        ? "\n\nAlternative: ${altMove.toAlgebraic()} is also reasonable but less precise (scored ${scoreDiff > 0 ? '-$scoreDiff' : '+$scoreDiff'} cp gap)."
        : "";

    return "♟️ Play $moveUci ($fromSq → $toSq)$captureStr\n\n$patternExplain$altNote";
  }

  // ── UTILITY ─────────────────────────────────────────────────────────────

  String _fileLabel(int file) => String.fromCharCode('a'.codeUnitAt(0) + file);

  String _describeArea(int file, int rank) {
    final isKingside = file >= 4;
    final isQueenside = file <= 3;
    final isCenter = file >= 3 && file <= 4 && rank >= 3 && rank <= 4;
    if (isCenter) return "center";
    if (file <= 1) return "queenside flank";
    if (file >= 6) return "kingside flank";
    if (isKingside) return "kingside";
    if (isQueenside) return "queenside";
    if (rank >= 5) return "deep enemy territory";
    return "active square";
  }



  // ═══════════════════════════════════════════
  // POST-GAME ANALYSIS — Reward & Feedback Summary
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

  /// Performs a full post-game analysis of a move history.
  /// Returns a summary containing accuracies and move classifications for both colors.
  Future<Map<String, dynamic>> analyzeFullGame({
    required List<Move> moveHistory,
    String initialFEN = 'rnbqkbnr/pppppppp/8/8/8/8/PPPPPPPP/RNBQKBNR w KQkq - 0 1',
  }) async {
    final analysisEngine = ChessEngine.fromFEN(initialFEN);
    
    int whiteTotalCpLoss = 0;
    int whiteMoves = 0;
    int whiteMistakes = 0;
    int whiteBlunders = 0;
    
    int blackTotalCpLoss = 0;
    int blackMoves = 0;
    int blackMistakes = 0;
    int blackBlunders = 0;

    for (final move in moveHistory) {
      final color = analysisEngine.currentTurn;
      final fenBefore = analysisEngine.toFEN();
      final engineBefore = ChessEngine.fromFEN(fenBefore);
      
      // Get best move score
      final topMoves = await AIEngine.getTopMoves(engineBefore, AIDifficulty.advanced, count: 1);
      final bestScore = topMoves.isNotEmpty ? topMoves[0].$2 : 0;
      
      analysisEngine.makeMove(move);
      final fenAfter = analysisEngine.toFEN();
      final scoreAfter = -(await AIEngine.evaluatePosition(ChessEngine.fromFEN(fenAfter)));
      
      final cpLoss = math.max(0, bestScore - scoreAfter);
      
      if (color == PieceColor.white) {
        whiteTotalCpLoss += cpLoss;
        whiteMoves++;
        if (cpLoss >= 300) whiteBlunders++;
        else if (cpLoss >= 100) whiteMistakes++;
      } else {
        blackTotalCpLoss += cpLoss;
        blackMoves++;
        if (cpLoss >= 300) blackBlunders++;
        else if (cpLoss >= 100) blackMistakes++;
      }
    }

    double calculateAccuracy(int totalLoss, int count) {
      if (count == 0) return 100.0;
      final avgLoss = totalLoss / count;
      // Formula: accuracy = 100 * exp(-0.004 * avg_loss)
      return (100.0 * math.exp(-0.003 * avgLoss)).clamp(0.0, 100.0);
    }

    return {
      'whiteAccuracy': calculateAccuracy(whiteTotalCpLoss, whiteMoves),
      'blackAccuracy': calculateAccuracy(blackTotalCpLoss, blackMoves),
      'whiteMistakes': whiteMistakes,
      'whiteBlunders': whiteBlunders,
      'blackMistakes': blackMistakes,
      'blackBlunders': blackBlunders,
    };
  }

  // ═══════════════════════════════════════════
  // PRACTICE MODE — Deep Engine-Based Analysis
  // ═══════════════════════════════════════════

  /// Evaluates a player's move in Practice Mode using the active external
  /// engine (Stockfish / Sunfish worker — whichever is running) at maximum
  /// depth for the most accurate best-move reference, then generates rich,
  /// coaching-focused feedback.
  ///
  /// Falls back to the internal AIEngine if the external engine is unavailable.
  Future<CoachFeedback> evaluateMoveForPractice({
    required ChessEngine engineBeforeMove,
    required Move playedMove,
    required ChessEngine engineAfterMove,
    required Future<Map<String, dynamic>?> Function(String fen) externalAnalyze,
  }) async {
    try {
      final fen = engineBeforeMove.toFEN();
      final playedUci = playedMove.toAlgebraic();
      final totalLegalMoves = engineBeforeMove.allLegalMoves().length;

      // 1. Ask the active external engine for the best move
      String? bestMoveUci;
      int bestScore = 0;
      int? playedScore;
      int moveRank = totalLegalMoves; // worst-case default
      int candidateCount = 0;

      final res = await externalAnalyze(fen);
      if (res != null) {
        bestMoveUci = res['move'] as String?;
        final rawCandidates = res['candidates'];
        final List<MoveCandidate> candidates;
        if (rawCandidates is List<MoveCandidate>) {
          candidates = rawCandidates;
        } else if (rawCandidates is List) {
          candidates = rawCandidates
              .map<MoveCandidate?>((c) {
                if (c is MoveCandidate) return c;
                if (c is Map) {
                  final uciRaw = c['uci'];
                  final scoreRaw = c['score'];
                  if (uciRaw is String && scoreRaw is num) {
                    return MoveCandidate(uci: uciRaw, score: scoreRaw.toInt());
                  }
                }
                return null;
              })
              .whereType<MoveCandidate>()
              .toList(growable: false);
        } else {
          candidates = const [];
        }

        candidateCount = candidates.length;
        if (candidates.isNotEmpty) {
          bestScore = candidates.first.score;
          // Find score AND rank for the played move in candidates
          for (int i = 0; i < candidates.length; i++) {
            final c = candidates[i];
            if (c.uci == playedUci) {
              playedScore = c.score;
              moveRank = i + 1; // 1-indexed rank
              break;
            }
          }
        }
      }

      // 2. Fallback: use internal AIEngine if external didn't return
      if (bestMoveUci == null) {
        return evaluateMove(
          engineBeforeMove: engineBeforeMove,
          playedMove: playedMove,
          engineAfterMove: engineAfterMove,
        );
      }

      // 3. Calculate centipawn loss
      if (playedScore == null) {
        // Move not in candidates — evaluate via internal engine
        playedScore = -(await AIEngine.evaluatePosition(engineAfterMove));
      }

      final centipawnLoss = (bestScore - playedScore).clamp(0, 99999);

      // 4. Classify
      final isExactBest = playedUci == bestMoveUci;
      MoveClassification classification;
      if (isExactBest) {
        classification = centipawnLoss <= 0
            ? MoveClassification.best
            : MoveClassification.good;
      } else {
        classification = _classifyMove(centipawnLoss);
      }

      // 5. Pattern detection
      final pattern = _detectPattern(engineBeforeMove, engineAfterMove, playedMove);

      // 6. Compute dynamic coaching stats
      final piece = engineBeforeMove.pieceAt(playedMove.from);
      final pieceName = piece?.type.coachName ?? 'piece';
      final accuracy = (100.0 - (centipawnLoss / 10.0)).clamp(0.0, 100.0);
      final rankPercentile = totalLegalMoves > 0
          ? ((1.0 - (moveRank - 1) / totalLegalMoves) * 100).round().clamp(1, 100)
          : 50;

      final moveCtx = _PracticeMoveContext(
        playedUci: playedUci,
        bestMoveUci: bestMoveUci,
        pieceName: pieceName,
        accuracy: accuracy,
        rankPercentile: rankPercentile,
        centipawnLoss: centipawnLoss,
        moveRank: moveRank,
        totalMoves: totalLegalMoves,
        candidateCount: candidateCount,
        pattern: pattern,
        personality: _settings.personality,
      );

      // 7. Build Practice-specific coaching message
      final message = _getPracticeMessage(classification, moveCtx);
      final explanation = _getPracticeExplanation(classification, moveCtx);

      return CoachFeedback(
        classification: classification,
        message: message,
        explanation: explanation,
        pattern: pattern,
        centipawnLoss: centipawnLoss,
        bestMoveAlgebraic: isExactBest ? null : bestMoveUci,
        showUndo: classification == MoveClassification.blunder ||
                  classification == MoveClassification.mistake,
        timestamp: DateTime.now(),
      );
    } catch (e) {
      debugPrint('[Practice Coach Error] $e');
      // Fallback to standard evaluation
      return evaluateMove(
        engineBeforeMove: engineBeforeMove,
        playedMove: playedMove,
        engineAfterMove: engineAfterMove,
      );
    }
  }

  // ── PRACTICE MODE CONTEXT ───────────────────────────────────────────────

  // ── PRACTICE MODE MESSAGE POOLS ─────────────────────────────────────────

  String _getPracticeMessage(
    MoveClassification classification,
    _PracticeMoveContext ctx,
  ) {
    final r = _random;
    final f = ctx.playedUci.substring(0, 2);
    final t = ctx.playedUci.substring(2, 4);
    final a = ctx.accuracy.toStringAsFixed(0);
    final rk = ctx.rankPercentile.toString();
    final p = ctx.pieceName;
    final cp = ctx.centipawnLoss ~/ 10;
    final bot = 100 - ctx.rankPercentile;
    final pers = ctx.personality;

    // ── BEST / BRILLIANT — by personality ──
    final bestPool = switch (pers) {
      CoachPersonality.friendly => [
        "Your move $f→$t is considered $a% accurate! You're on the correct path — keep it up, champion! 🎯✨",
        "Incredible! Your $p to $t is exactly what the engine recommends. You are among the top $a% of moves here! Now you play like a real chess master! 👑🔥",
        "This move makes me admire you! $a% accuracy — you found the strongest continuation with your $p. The engine is impressed! 🌟🏆",
        "Wow! Your $p move to $t is top-tier! $a% accuracy puts you among the best players for this position. Beautiful vision! I'm so proud of you! 💪⚡",
        "Perfect choice, friend! $f→$t ranked in the top $a% of all possible moves. You're seeing the board like a pro! Keep having fun! 🎓✨",
        "Flawless! Your $p to $t is calculated at $a% accuracy. You maintained the initiative perfectly — let's keep this energy going! 🏅🔥",
      ],
      CoachPersonality.strict => [
        "Correct. Your $p to $t measures $a% accuracy — the optimal move. Precision maintained. ✓",
        "Exact. $f→$t is the engine's top recommendation. You are in the top $a% here. No wasted calculation. ⚙️",
        "Analysis confirms: $a% accuracy. Your $p placement at $t is mathematically superior. Continue at this standard. 📐",
        "Precisely executed. $f→$t shows $a% accuracy — top $a% of ${ctx.totalMoves} legal moves. This is the expected level. ✓✓",
        "Your $p move to $t is calculated at $a% accuracy. The engine confirms this was the only correct continuation. Maintain this discipline. 🎯",
      ],
      CoachPersonality.motivational => [
        "LET'S GO!! Your move $f→$t is $a% accurate! You are among the top $a% — you're UNSTOPPABLE! Keep crushing it! 🔥🔥🔥",
        "INCREDIBLE!! Your $p to $t is exactly what the engine picks! $a% accuracy — you're playing like a GRANDMASTER! Believe in yourself! 💪👑",
        "YES YES YES! This $p move to $t makes me admire you! $a% accuracy — you're on FIRE! Nothing can stop you now! 🚀✨",
        "CHAMPION MOVE! $f→$t ranked top $a% — that's $a% accuracy! You're dominating this board! Keep pushing forward! 🏆⚡",
        "FLAWLESS EXECUTION! Your $p to $t is pure greatness — $a% accurate! You've got the heart of a champion! NEVER give up! 🦅🔥",
      ],
    };

    // ── GOOD — by personality ──
    final goodPool = switch (pers) {
      CoachPersonality.friendly => [
        "Solid move! Your $p to $t is rated $a% accurate — you're building a strong position. There was a slightly sharper option, but your instincts are good! 👍📈",
        "Good thinking with $f→$t! At $a% accuracy, you're heading in the right direction. You are among the top $a% for that move — keep developing! 🔥♟️",
        "Nice continuation! Your analysis strength shows $a% accuracy. The engine sees a marginal improvement, but your plan is coming together beautifully! 🧩🚀",
        "Well played! $f→$t puts you in the top $a% of moves. That's a sensible choice — with a small tweak you'd be at 100%! 📊✨",
      ],
      CoachPersonality.strict => [
        "Acceptable. Your $p to $t scores $a% accuracy — top $a% of ${ctx.totalMoves} moves. A more precise option existed, but the position remains stable. ✓",
        "Standard play. $f→$t at $a% accuracy is reasonable, though sub-optimal by $cp centipawns. Aim for the engine's first line next time. ⚙️",
        "Functional. Your $p to $t holds at $a% accuracy. The deviation from optimal is $cp points — within acceptable tolerance for now. 📐",
      ],
      CoachPersonality.motivational => [
        "Good move, warrior! Your $p to $t hits $a% accuracy — you're building momentum! You are among the top $a% — keep pushing for perfection! 💪📈",
        "Nice work with $f→$t! $a% accuracy shows real progress! There's an even sharper move out there — I KNOW you can find it next time! 🔥🚀",
        "You're growing stronger! $f→$t puts you in the top $a% — that $a% accuracy is solid! Every game makes you better! Keep believing! 🌟💪",
      ],
    };

    // ── MEDIUM (Inaccuracy) — by personality ──
    final mediumPool = switch (pers) {
      CoachPersonality.friendly => [
        "Hmm, your $p to $t is rated $a% accurate. I think there might be something stronger — you can think of an alternative move here! Would you like to change your mind? 🤔💡",
        "Your move $f→$t is in the top $a% of choices, but I see a sharper continuation. I may suggest you explore other options, if you like! The engine spotted a hidden gem 💎🔍",
        "Not bad, but your analysis strength is at $a%. A small tweak would take you to the top! If you undo this move, I can give you a better suggestion. What do you think? 🛤️🔧",
        "Your instinct with $p to $t is reasonable, but at $a% accuracy the execution could be sharper. There was a move scoring about $cp points higher — want to try again? 🎯📚",
        "I see what you're going for with $f→$t! But the engine rates this at $a% accuracy. Consider taking it back — I'd love to show you an even better move! Would you like to change your mind? 🧐✨",
      ],
      CoachPersonality.strict => [
        "Suboptimal. Your $p to $t scores only $a% accuracy — that's a $cp point deviation from the engine's best line. You should undo and recalculate. ⚠️",
        "Inaccurate. $f→$t ranks in the top $a% but misses the critical line by $cp centipawns. Undo recommended. Reconsider the position. 📊",
        "Below standard. Your analysis at $a% accuracy shows a $cp point gap. The engine's preferred continuation is significantly stronger. If you undo, I will show you the correct path. ⚙️",
        "Imprecise. Your $p to $t at $a% accuracy falls short of the required standard. The optimal line scores $cp points higher. Recalculate and try again. 📐",
      ],
      CoachPersonality.motivational => [
        "Hey, don't settle! Your $p to $t scores $a% — you've got ${100 - ctx.accuracy.toInt()}% more potential to unlock! Would you like to change your mind? I KNOW you can find the best move! 💪🔍",
        "Close, but you can do BETTER! $f→$t is at $a% accuracy — there's a move $cp points stronger waiting for you! If you undo, I'll help you find it! Let's GO! 🔥💡",
        "Good effort, but I believe in you MORE! Your $p to $t is in the top $a%, but there's a hidden gem here. Undo and try again — you've got the skills to nail it! 🚀🎯",
        "Don't stop reaching higher! $a% accuracy is decent, but you're capable of 100%! If you undo this move, I can give you a better suggestion. Let's find it TOGETHER! 💪✨",
      ],
    };

    // ── MISTAKE — by personality ──
    final mistakePool = switch (pers) {
      CoachPersonality.friendly => [
        "Oops! Your $p to $t is only $a% accurate — that's below where you want to be. You gave up about $cp points of advantage. If you undo this move, I can give you a better suggestion! 🤝⚠️",
        "Watch out! $f→$t ranks in the bottom $a% of moves here. I think this position called for something different. Would you like to change your mind? Try undoing and I'll guide you! 🧠💡",
        "Your move scores $a% accuracy — that weakens your position noticeably. The engine sees a much stronger option. If you undo, I can show you the top move that scores ~$cp points better! 📖🔄",
        "Not quite! Your $p to $t missed a stronger continuation. At $a% accuracy, there's room to grow. But don't worry — mistakes are how we become better players! Want to try again? 🌱🔑",
      ],
      CoachPersonality.strict => [
        "Error. Your $p to $t scores only $a% accuracy — bottom $a% of ${ctx.totalMoves} legal moves. That's a $cp point loss. Undo immediately and recalculate. ❌",
        "Deficient. $f→$t is a significant deviation from correct play. $a% accuracy is unacceptable at this stage. The engine's line is $cp points superior. Undo and correct. ⚠️",
        "Tactical miscalculation detected. Your $p to $t drops $a% accuracy — ranked #${ctx.moveRank} of ${ctx.totalMoves}. Undo this move and apply the checks-captures-threats framework. 📊",
      ],
      CoachPersonality.motivational => [
        "Hey, that's okay! Your $p to $t scores $a%, but EVERY mistake is a lesson! You gave up $cp points — but if you undo, I'll help you find the STRONGEST move! You've got this! 💪🌱",
        "Don't let this get you down! $f→$t is in the bottom $a%, but champions learn from setbacks! Would you like to change your mind? Undo and show the board who's boss! 🔥🔄",
        "Shake it off! $a% accuracy means there's a $cp point opportunity waiting! If you undo this move, I can give you a better suggestion! Every grandmaster has made mistakes — it's how you BOUNCE BACK! 🚀💡",
      ],
    };

    // ── BLUNDER — by personality ──
    final blunderPool = switch (pers) {
      CoachPersonality.friendly => [
        "Oh no! Your $p to $t is a serious mistake — only $a% accurate! That's a ~$cp point swing against you. I strongly recommend undoing this move — let me show you why and suggest a better path! ❌🔥",
        "Wait! $f→$t loses a massive amount of advantage! At $a% accuracy, this ranks in the bottom $a% of all moves. If you undo this move, I can give you a much better suggestion! Think again! 🚨💡",
        "Alert! Your $p to $t is a critical error — the engine rates it at only $a%. Please consider undoing! Remember: always check for checks, captures, and threats before committing. I'm here to help you find the best path! 📚❌🧠",
        "Big trouble! That move changes everything — and not in a good way. $a% accuracy means there's a ~$cp point gap from the best move. Would you like to change your mind? If you undo, I'll guide you to the strongest continuation! 🛑🎓",
      ],
      CoachPersonality.strict => [
        "Critical failure. Your $p to $t scores $a% — bottom $a% of ${ctx.totalMoves} moves. A $cp point catastrophe. Undo immediately. This is exactly the kind of oversight that loses games. ❌",
        "Unacceptable. $f→$t at $a% accuracy constitutes a blunder — $cp points lost. Ranked #${ctx.moveRank} of ${ctx.totalMoves}. Undo now and apply rigorous calculation before committing. 🚨",
        "Severe error. Your $p to $t is a $cp point blunder at $a% accuracy. The position demands ${ctx.bestMoveUci}. Undo, recalculate from scratch, and do not move until you have verified all opponent replies. ⚠️📊",
      ],
      CoachPersonality.motivational => [
        "HEY! Don't panic! Your $p to $t is only $a% accurate — a $cp point swing — but this is WHERE CHAMPIONS ARE MADE! Undo this move and I'll help you find the BEST path! You can do this! 💪🔥",
        "WHOA! $f→$t is in the bottom $a% — but listen: EVERY grandmaster has blundered! $a% accuracy NOW, but 100% NEXT TIME! If you undo, I can give you a much better suggestion! BELIEVE in yourself! 🚀❌",
        "Big moment! This $cp point mistake is your biggest learning opportunity TODAY! Undo your $p to $t and let's find the STRONGEST move together! Failures are just stepping stones to GREATNESS! 🏆🌟",
      ],
    };

    final pool = switch (classification) {
      MoveClassification.brilliant => bestPool,
      MoveClassification.best => bestPool,
      MoveClassification.good => goodPool,
      MoveClassification.needsImprovement => mediumPool,
      MoveClassification.mistake => mistakePool,
      MoveClassification.blunder => blunderPool,
    };
    return pool[r.nextInt(pool.length)];
  }

  String? _getPracticeExplanation(
    MoveClassification classification,
    _PracticeMoveContext ctx,
  ) {
    final r = _random;
    final bTo = ctx.bestMoveUci.length >= 4 ? ctx.bestMoveUci.substring(2, 4) : '??';
    final a = ctx.accuracy.toStringAsFixed(0);
    final pTo = ctx.playedUci.substring(2, 4);
    final p = ctx.pieceName;
    final cp = ctx.centipawnLoss ~/ 10;
    final bot = 100 - ctx.rankPercentile;
    final bm = ctx.bestMoveUci;
    final pers = ctx.personality;
    final stats = '📊 Analysis: $a% accuracy · Top ${ctx.rankPercentile}% · Rank #${ctx.moveRank} of ${ctx.totalMoves}';
    final statsBot = '📊 Analysis: $a% accuracy · Bottom $a% · Rank #${ctx.moveRank} of ${ctx.totalMoves}';

    // ── BEST / BRILLIANT ──
    if (classification == MoveClassification.best ||
        classification == MoveClassification.brilliant) {
      if (ctx.pattern != TacticalPattern.none) {
        final patNote = switch (pers) {
          CoachPersonality.friendly => 'You spotted the ${ctx.pattern.label}! ${ctx.pattern.explanation}. Out of ${ctx.totalMoves} legal moves, yours was ranked #${ctx.moveRank} — that\'s exceptional! Keep this pattern in your toolkit and watch for similar opportunities! 🧰🏆',
          CoachPersonality.strict => '${ctx.pattern.label} identified and executed correctly. Ranked #${ctx.moveRank} of ${ctx.totalMoves}. This pattern — ${ctx.pattern.explanation} — was the only precise option. Maintain this standard. ✓',
          CoachPersonality.motivational => 'You SMASHED it! You found the ${ctx.pattern.label}! ${ctx.pattern.explanation}! Ranked #${ctx.moveRank} of ${ctx.totalMoves} — that\'s ELITE! This pattern will win you SO many games! 🔥🧰',
        };
        return '$stats\n\n$patNote';
      }
      final pool = switch (pers) {
        CoachPersonality.friendly => [
          '$stats\n\nYour positional understanding is developing beautifully! This move improves your $p activity and board control. The engine confirms this was the optimal choice among all ${ctx.totalMoves} legal moves. You\'re building the kind of intuition that separates good players from great ones! ♟️🌟',
          '$stats\n\nYou calculated accurately and found the best continuation! The engine\'s deepest analysis agrees with your choice. Your $p is perfectly placed to influence the next phase of the game. This is exactly how champions think! 🎯💪',
          '$stats\n\nOutstanding! You maintained the initiative perfectly with this move. Your analysis strength here matches engine-level play. Keep trusting your instincts — they\'re leading you to the strongest moves consistently! 📈🔥',
        ],
        CoachPersonality.strict => [
          '$stats\n\nEngine-verified: Your $p placement is the strongest among ${ctx.totalMoves} candidates. Centipawn advantage maintained at 100%. Zero deviation from optimal. Continue this level of precision and your rating trajectory will reflect it. ⚙️✓',
          '$stats\n\nPositionally and tactically correct. Your $p to $pTo demonstrates proper calculation methodology. The engine\'s main line aligns exactly with your choice. Consistency at this accuracy will produce results. 📐',
        ],
        CoachPersonality.motivational => [
          '$stats\n\nYou are UNSTOPPABLE! Your $p move is EXACTLY what the engine picks! This is the kind of play that turns beginners into MASTERS! ${ctx.totalMoves} options and you chose THE BEST ONE! Keep this fire burning! 🔥💪',
          '$stats\n\nBELIEVE in yourself because THIS MOVE PROVES why you should! Engine-perfect play! Your $p is perfectly positioned and your vision is INCREDIBLE! You were born for this game! 🚀🏆',
        ],
      };
      return pool[r.nextInt(pool.length)];
    }

    // ── GOOD ──
    if (classification == MoveClassification.good) {
      final pool = switch (pers) {
        CoachPersonality.friendly => [
          '$stats\n\nA solid move! The very best was $bm (targeting $bTo), which scores about $cp points higher. Your $p to $pTo is still a good choice and keeps your position healthy. For next time, consider whether $bTo offers more central control or tactical pressure! 📈✨',
          '$stats\n\nGood move! The engine slightly prefers $bm by about $cp points, but you\'re on the right track. Also consider the $bTo square next time for a slightly sharper game — small edges like these add up over the course of a match! 🧠♟️',
        ],
        CoachPersonality.strict => [
          '$stats\n\nAdequate but not optimal. The engine\'s first line $bm (to $bTo) scores $cp centipawns higher. Your $p to $pTo is a reasonable continuation but shows a calculation gap. Study the difference between $pTo and $bTo to understand why the engine prefers the latter. 📐',
          '$stats\n\nWithin acceptable range but below top standard. The $cp point gap to $bm indicates you missed a subtle positional nuance at $bTo. Systematically compare candidates before committing. ⚙️',
        ],
        CoachPersonality.motivational => [
          '$stats\n\nGreat foundation! Your $p to $pTo is SOLID — but I know you can find the ABSOLUTE BEST! The engine sees $bm (to $bTo) scoring $cp points sharper. You\'re SO close to perfection — next time, scan one more candidate and you\'ll nail it! 💪✨',
          '$stats\n\nNice work! $a% accuracy proves you\'re on the right path! The ultimate move was $bm — just $cp points sharper. You\'re building the skills to find it next time — NEVER stop reaching higher! 🚀📈',
        ],
      };
      return pool[r.nextInt(pool.length)];
    }

    // ── MEDIUM ──
    if (classification == MoveClassification.needsImprovement) {
      final parts = <String>[stats, ''];

      if (ctx.pattern != TacticalPattern.none) {
        parts.add('💡 Missed opportunity: There was a ${ctx.pattern.label} available here! ${ctx.pattern.emoji} ${ctx.pattern.explanation}.');
        parts.add('');
      }

      final pool = switch (pers) {
        CoachPersonality.friendly => [
          'The engine suggests $bm ($p to $bTo) — it gives you about $cp more points of advantage and a stronger grip on the position. Your move to $pTo isn\'t bad, but playing to $bTo creates more threats and keeps the initiative firmly yours.',
          'A move like $bm would rank higher because it controls more key squares and keeps the pressure on. Your current move is at $a% accuracy — with a small adjustment you could be at near-100%! Tip: Before committing, always ask "Does this move improve my worst-placed piece?"',
          'The engine\'s preferred move $bm scores about $cp points better. Small edges like these compound over a game. Look at $bTo — it creates more threats and restricts your opponent\'s options.',
        ],
        CoachPersonality.strict => [
          'The correct move was $bm (to $bTo), scoring $cp centipawns higher. Your $p to $pTo at $a% accuracy fails to address the critical tactical requirement. Undo, recalculate using the checks-captures-threats hierarchy, and execute the strongest line.',
          'Deviation of $cp centipawns from optimal. The engine demands $bm — your $p to $pTo does not sufficiently contest the key squares. Reconsider the position from scratch and verify all candidate moves before committing.',
        ],
        CoachPersonality.motivational => [
          'You\'re SO close to greatness! The engine sees $bm (to $bTo) — $cp points stronger — and I KNOW you can find moves like that! Your $p to $pTo shows good instinct, it just needs a small push to perfection! You\'ve got the talent — trust it! 💪',
          'Don\'t settle! The engine\'s best move $bm scores about $cp points sharper than your $p to $pTo. But here\'s the thing — the fact that you\'re at $a% accuracy means you\'re ALREADY thinking correctly! One more level of calculation and you\'ll be UNSTOPPABLE! 🔥',
        ],
      };
      parts.add(pool[r.nextInt(pool.length)]);
      parts.add('');
      final undoMsg = switch (pers) {
        CoachPersonality.friendly => '🔄 Would you like to undo and try again? In practice mode, undos are unlimited!',
        CoachPersonality.strict => '🔄 Undo recommended. Recalculate and execute the optimal line.',
        CoachPersonality.motivational => '🔄 Undo and try again! Practice makes PERFECT — and you\'re getting closer every move!',
      };
      parts.add(undoMsg);
      return parts.join('\n');
    }

    // ── MISTAKE ──
    if (classification == MoveClassification.mistake) {
      final pool = switch (pers) {
        CoachPersonality.friendly => [
          '$statsBot\n\nThe stronger move was $bm (to $bTo), scoring ~$cp points higher than your $p to $pTo. Before moving, always ask yourself: "Does this create or block threats? Is my piece safe after moving? What does my opponent want to do next?"\n\n🔄 If you undo this move, I can give you a better suggestion! Practice mode gives you unlimited take-backs — use them to learn! 💡',
          '$statsBot\n\nPlaying $bm would have been significantly stronger. Your $p to $pTo misses the tactical point of the position. The golden rule is: scan for checks → captures → threats, in that order. The best move always addresses these priorities first!\n\n🔄 Would you like to change your mind? Undo is free and unlimited — try finding $bm yourself! 🎯',
        ],
        CoachPersonality.strict => [
          '$statsBot\n\nError analysis: Your $p to $pTo deviates by $cp centipawns from the required $bm (to $bTo). This constitutes a tactical oversight. Before any move, systematically verify: (1) Opponent threats, (2) Capture sequences, (3) Check availability. Your current process failed at step ${cp > 300 ? 1 : 2}.\n\n🔄 Undo immediately and execute $bm.  Mistakes in practice should be corrected, not reinforced.',
          '$statsBot\n\nSignificant miscalculation. $bm to $bTo was $cp centipawns superior. Your $p to $pTo ranks #${ctx.moveRank} of ${ctx.totalMoves} — that is below the acceptable threshold. Undo, apply rigorous candidate analysis, and find the correct continuation. No shortcuts.\n\n🔄 Undo and recalculate. The position demands precision.',
        ],
        CoachPersonality.motivational => [
          '$statsBot\n\nHey, EVERY champion stumbles! Your $p to $pTo missed the stronger $bm (to $bTo) by $cp points — but this is exactly HOW you get stronger! The best players learn from EVERY mistake!\n\n🔄 Undo this move and let\'s find $bm together! If you undo, I can give you a better suggestion! You\'ve got this! 💪🔥',
          '$statsBot\n\nDon\'t let this slow you down! Your $p to $pTo ranged a bit low, but the LEARNING is what matters! The engine sees $bm as $cp points stronger — and the more you practice finding these, the SHARPER you become!\n\n🔄 Would you like to change your mind? Every undo is a chance to LEVEL UP! 🚀🎓',
        ],
      };
      return pool[r.nextInt(pool.length)];
    }

    // ── BLUNDER ──
    final pool = switch (pers) {
      CoachPersonality.friendly => [
        '$statsBot\n\n🚨 Critical: The best move was $bm. Your $p to $pTo swings the position by ~$cp points against you! In practice, always check: "Is my piece safe? Can my opponent take something? Can they give check?" These three questions prevent most blunders.\n\n⏪ I strongly recommend undoing this move. If you undo, I\'ll help you find the strongest continuation — that\'s what practice mode is for! Let\'s learn from this together! 🧠📚',
        '$statsBot\n\n🚨 This is a major turning point. $bm was needed here to maintain your advantage. After your $p to $pTo, your opponent gains a ~$cp point advantage — that\'s like losing a whole piece in positional terms!\n\n⏪ Would you like to change your mind? If you undo this move, I can give you a much better suggestion. Remember: blunders teach us to slow down and calculate. Every grandmaster has made them — the difference is learning from each one! 💪🎓',
      ],
      CoachPersonality.strict => [
        '$statsBot\n\n🚨 Critical failure requiring immediate correction. Your $p to $pTo constitutes a $cp point blunder. The position demanded $bm. This error stems from insufficient threat assessment — specifically, you failed to check opponent responses BEFORE committing.\n\n⏪ Undo immediately. Execute $bm. In future positions, verify EVERY opponent reply before touching a piece. This is non-negotiable.',
        '$statsBot\n\n🚨 Catastrophic miscalculation. $bm was the only defensible continuation — your $p to $pTo ranks #${ctx.moveRank} of ${ctx.totalMoves}, losing $cp centipawns. This kind of error must be eliminated through disciplined calculation.\n\n⏪ Undo and recalculate. Apply the full candidate-move verification process. No excuses.',
      ],
      CoachPersonality.motivational => [
        '$statsBot\n\n🚨 WHOA! Big moment! Your $p to $pTo swings $cp points — BUT THIS IS YOUR BIGGEST LEARNING OPPORTUNITY! Every grandmaster — Carlsen, Kasparov, Fischer — has blundered! The difference? They got BACK UP and played STRONGER!\n\n⏪ Undo this move! I\'ll help you find $bm — and next time, you\'ll spot it YOURSELF! This is what practice mode is MADE for! You\'ve GOT this! 🔥💪🏆',
        '$statsBot\n\n🚨 Don\'t spiral — LEARN! Your $p to $pTo is a $cp point blunder, but CHAMPIONS are forged in moments like these! $bm was the move — and now you KNOW it!\n\n⏪ If you undo this move, I can give you the STRONGEST continuation! Every undo in practice mode makes you a BETTER player! Rise up and DOMINATE! 🚀🦅',
      ],
    };
    return pool[r.nextInt(pool.length)];
  }

  void dispose() {
    _evalCache.clear();
  }

  /// Deep tactical explanation for a specific move.
  /// Used by the "Brain Explainer" feature.
  Future<String> explainMove({
    required String fen,
    required Move move,
  }) async {
    try {
      final engine = ChessEngine.fromFEN(fen);
      final playedMoveStr = move.toAlgebraic();

      // Analyze current position deeply
      final eval = await AIEngine.evaluatePosition(engine);
      final topMoves = await AIEngine.getTopMoves(engine, AIDifficulty.impossible, count: 5);

      final pattern = await detectTacticalPattern(engine, move);
      final piece = engine.pieceAt(move.from);

      // Check if it was the best move
      bool isBest = topMoves.isNotEmpty && topMoves.first.$1.toAlgebraic() == playedMoveStr;

      final parts = <String>[];

      if (isBest) {
        parts.add("🌟 This was the best move in the position!");
      } else if (topMoves.isNotEmpty && topMoves.any((m) => m.$1.toAlgebraic() == playedMoveStr)) {
        parts.add("✅ This was a strong tactical choice.");
      } else {
        parts.add("💡 I see your idea, but I have some thoughts on why this might be a gamble.");
      }

      if (pattern != TacticalPattern.none) {
        parts.add("The ${pattern.label} pattern is the key here. ${pattern.explanation}.");
      }

      if (piece != null) {
        parts.add("Moving your ${piece.type.coachName} to ${move.toAlgebraic().substring(2, 4)} helps you control more space.");
      }

      // Add a deep engine insight
      if (eval.abs() > 200) {
        final leader = eval > 0 ? "White" : "Black";
        parts.add("Positionally, $leader is leading by a solid margin. This move aims to press that advantage further.");
      }

      return parts.join(" ");
    } catch (e) {
      return "I analyzed this move and it looks solid! It focuses on board control and piece activity. 🧠";
    }
  }
}

/// Context data for Practice Mode coaching messages.
/// Carries all computed stats for dynamic message generation.
class _PracticeMoveContext {
  final String playedUci;
  final String bestMoveUci;
  final String pieceName;
  final double accuracy;             // 0-100%
  final int rankPercentile;          // 1-100 (higher = better)
  final int centipawnLoss;
  final int moveRank;                // 1-indexed rank among candidates
  final int totalMoves;              // total legal moves in position
  final int candidateCount;          // how many candidates engine returned
  final TacticalPattern pattern;
  final CoachPersonality personality; // current coach persona

  const _PracticeMoveContext({
    required this.playedUci,
    required this.bestMoveUci,
    required this.pieceName,
    required this.accuracy,
    required this.rankPercentile,
    required this.centipawnLoss,
    required this.moveRank,
    required this.totalMoves,
    required this.candidateCount,
    required this.pattern,
    required this.personality,
  });
}

// Utility extension for Move classification
extension MoveClassificationValue on MoveClassification {
  bool get isNegative =>
      this == MoveClassification.mistake || this == MoveClassification.blunder;
}
