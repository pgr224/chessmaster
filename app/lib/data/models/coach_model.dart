/// AI Coach Data Models
/// Defines move classifications, feedback templates, personalities, and coaching levels.
library;

import '../models/game_config.dart';

// ═══════════════════════════════════════════
// MOVE CLASSIFICATION
// ═══════════════════════════════════════════
enum MoveClassification {
  brilliant,
  best,
  good,
  needsImprovement,
  mistake,
  blunder,
}

extension MoveClassificationEmoji on MoveClassification {
  String get emoji => switch (this) {
    MoveClassification.brilliant => '💎',
    MoveClassification.best => '⭐',
    MoveClassification.good => '👍',
    MoveClassification.needsImprovement => '🤔',
    MoveClassification.mistake => '⚠️',
    MoveClassification.blunder => '❌',
  };

  String get label => switch (this) {
    MoveClassification.brilliant => 'Brilliant',
    MoveClassification.best => 'Best Move',
    MoveClassification.good => 'Good Move',
    MoveClassification.needsImprovement => 'Needs Improvement',
    MoveClassification.mistake => 'Mistake',
    MoveClassification.blunder => 'Blunder',
  };

  double get colorHue => switch (this) {
    MoveClassification.brilliant => 280.0,  // purple
    MoveClassification.best => 120.0,       // green
    MoveClassification.good => 160.0,       // teal
    MoveClassification.needsImprovement => 45.0,  // orange
    MoveClassification.mistake => 30.0,     // warm orange
    MoveClassification.blunder => 0.0,      // red
  };
}

// ═══════════════════════════════════════════
// TACTICAL PATTERNS
// ═══════════════════════════════════════════
enum TacticalPattern {
  fork,
  pin,
  skewer,
  discoveredAttack,
  doubleCheck,
  checkmate,
  materialGain,
  materialLoss,
  centerControl,
  development,
  kingSafety,
  pawnPromotion,
  trappedPiece,
  hangingPiece,
  backRankWeakness,
  none,
}

extension TacticalPatternInfo on TacticalPattern {
  String get explanation => switch (this) {
    TacticalPattern.fork => 'attacks two pieces at once',
    TacticalPattern.pin => 'piece cannot move without exposing a more valuable piece',
    TacticalPattern.skewer => 'attacks through a piece to one behind it',
    TacticalPattern.discoveredAttack => 'moving one piece reveals an attack by another',
    TacticalPattern.doubleCheck => 'two pieces give check simultaneously',
    TacticalPattern.checkmate => 'the King has no escape!',
    TacticalPattern.materialGain => 'wins material advantage',
    TacticalPattern.materialLoss => 'loses material',
    TacticalPattern.centerControl => 'controls the center of the board',
    TacticalPattern.development => 'develops a piece to an active square',
    TacticalPattern.kingSafety => 'improves king safety',
    TacticalPattern.pawnPromotion => 'a pawn is close to becoming a queen!',
    TacticalPattern.trappedPiece => 'a piece has no safe squares',
    TacticalPattern.hangingPiece => 'a piece is left undefended',
    TacticalPattern.backRankWeakness => 'the back rank is weak',
    TacticalPattern.none => '',
  };

  String get emoji => switch (this) {
    TacticalPattern.fork => '🔱',
    TacticalPattern.pin => '📌',
    TacticalPattern.skewer => '🗡️',
    TacticalPattern.discoveredAttack => '💥',
    TacticalPattern.doubleCheck => '⚡',
    TacticalPattern.checkmate => '🏆',
    TacticalPattern.materialGain => '💰',
    TacticalPattern.materialLoss => '💸',
    TacticalPattern.centerControl => '🎯',
    TacticalPattern.development => '🚀',
    TacticalPattern.kingSafety => '🏰',
    TacticalPattern.pawnPromotion => '👑',
    TacticalPattern.trappedPiece => '🪤',
    TacticalPattern.hangingPiece => '⚠️',
    TacticalPattern.backRankWeakness => '🚪',
    TacticalPattern.none => '',
  };
}

// ═══════════════════════════════════════════
// COACH PERSONALITY
// ═══════════════════════════════════════════
enum CoachPersonality {
  friendly,
  strict,
  motivational,
}

extension CoachPersonalityInfo on CoachPersonality {
  String get name => switch (this) {
    CoachPersonality.friendly => 'Friendly Coach',
    CoachPersonality.strict => 'Strict Coach',
    CoachPersonality.motivational => 'Motivational Coach',
  };

  String get emoji => switch (this) {
    CoachPersonality.friendly => '😊',
    CoachPersonality.strict => '🧐',
    CoachPersonality.motivational => '🔥',
  };

  String get avatar => switch (this) {
    CoachPersonality.friendly => '🐱',
    CoachPersonality.strict => '🦁',
    CoachPersonality.motivational => '🦊',
  };
}

// ═══════════════════════════════════════════
// COACHING SKILL LEVEL
// ═══════════════════════════════════════════
enum CoachingLevel {
  beginner,
  intermediate,
  advanced,
}

extension CoachingLevelInfo on CoachingLevel {
  bool get showDetailedExplanations => this == CoachingLevel.beginner;
  bool get showHintsByDefault => this == CoachingLevel.beginner;
  bool get showPatternNames => this != CoachingLevel.beginner;
  int get maxAutoHints => switch (this) {
    CoachingLevel.beginner => 5,
    CoachingLevel.intermediate => 3,
    CoachingLevel.advanced => 1,
  };
}

// ═══════════════════════════════════════════
// COACH FEEDBACK
// ═══════════════════════════════════════════
class CoachFeedback {
  final MoveClassification classification;
  final String message;
  final String? explanation;
  final TacticalPattern pattern;
  final int centipawnLoss;
  final String? bestMoveAlgebraic;
  final String? bestMoveExplanation;
  final String? alternativeMoveAlgebraic;
  final bool showUndo;
  final DateTime timestamp;

  const CoachFeedback({
    required this.classification,
    required this.message,
    this.explanation,
    this.pattern = TacticalPattern.none,
    this.centipawnLoss = 0,
    this.bestMoveAlgebraic,
    this.bestMoveExplanation,
    this.alternativeMoveAlgebraic,
    this.showUndo = false,
    required this.timestamp,
  });

  bool get isPositive =>
      classification == MoveClassification.brilliant ||
      classification == MoveClassification.best ||
      classification == MoveClassification.good;

  bool get isNegative =>
      classification == MoveClassification.mistake ||
      classification == MoveClassification.blunder;
}

// ═══════════════════════════════════════════
// HINT RESULT
// ═══════════════════════════════════════════
class HintResult {
  final String bestMoveAlgebraic;
  final String shortExplanation;
  final String? alternativeMoveAlgebraic;
  final TacticalPattern pattern;
  final int xpCost;

  const HintResult({
    required this.bestMoveAlgebraic,
    required this.shortExplanation,
    this.alternativeMoveAlgebraic,
    this.pattern = TacticalPattern.none,
    this.xpCost = 10,
  });
}

// ═══════════════════════════════════════════
// POST-GAME ANALYSIS
// ═══════════════════════════════════════════
class PostGameAnalysis {
  final double accuracy;
  final int totalMoves;
  final int brilliantMoves;
  final int bestMoves;
  final int goodMoves;
  final int needsImprovementMoves;
  final int mistakes;
  final int blunders;
  final int missedWins;
  final List<CoachFeedback> moveAnalysis;
  final String overallMessage;
  final String improvementTip;

  const PostGameAnalysis({
    required this.accuracy,
    required this.totalMoves,
    this.brilliantMoves = 0,
    this.bestMoves = 0,
    this.goodMoves = 0,
    this.needsImprovementMoves = 0,
    this.mistakes = 0,
    this.blunders = 0,
    this.missedWins = 0,
    this.moveAnalysis = const [],
    required this.overallMessage,
    this.improvementTip = '',
  });
}

// ═══════════════════════════════════════════
// COACH SETTINGS (persisted)
// ═══════════════════════════════════════════
class CoachSettings {
  final CoachPersonality personality;
  final CoachingLevel level;
  final bool enableRealTimeCoaching;
  final bool enablePostGameAnalysis;
  final bool showEvalBar;

  const CoachSettings({
    this.personality = CoachPersonality.friendly,
    this.level = CoachingLevel.beginner,
    this.enableRealTimeCoaching = true,
    this.enablePostGameAnalysis = true,
    this.showEvalBar = false,
  });

  CoachSettings copyWith({
    CoachPersonality? personality,
    CoachingLevel? level,
    bool? enableRealTimeCoaching,
    bool? enablePostGameAnalysis,
    bool? showEvalBar,
  }) => CoachSettings(
    personality: personality ?? this.personality,
    level: level ?? this.level,
    enableRealTimeCoaching: enableRealTimeCoaching ?? this.enableRealTimeCoaching,
    enablePostGameAnalysis: enablePostGameAnalysis ?? this.enablePostGameAnalysis,
    showEvalBar: showEvalBar ?? this.showEvalBar,
  );

  /// Derive coaching level from AI difficulty
  static CoachingLevel levelFromDifficulty(AIDifficulty? difficulty) {
    return switch (difficulty) {
      AIDifficulty.basic => CoachingLevel.beginner,
      AIDifficulty.intermediate => CoachingLevel.intermediate,
      AIDifficulty.advanced => CoachingLevel.advanced,
      AIDifficulty.impossible => CoachingLevel.advanced,
      null => CoachingLevel.beginner,
    };
  }
}
