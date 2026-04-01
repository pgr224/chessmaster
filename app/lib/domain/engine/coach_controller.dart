/// AI Coach Controller
/// Core evaluation logic: classifies moves, detects patterns, generates feedback,
/// and provides hints with contextual explanations.
library;

import 'dart:async';
import 'dart:math' as math;
import '../../domain/engine/chess_engine.dart';
import '../../domain/engine/ai_engine.dart';
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

// Utility extension for Move classification
extension MoveClassificationValue on MoveClassification {
  bool get isNegative =>
      this == MoveClassification.mistake || this == MoveClassification.blunder;
}
