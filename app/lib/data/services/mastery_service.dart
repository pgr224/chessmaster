import 'dart:convert';

import 'package:shared_preferences/shared_preferences.dart';
import '../../domain/engine/adaptive_ai_profile.dart';
import '../../domain/engine/chess_engine.dart';
import '../../domain/engine/personality_engine.dart';
import '../../data/models/game_config.dart';

class MasteryService {
  static final MasteryService _instance = MasteryService._internal();
  factory MasteryService() => _instance;
  MasteryService._internal();

  static const String _kRatingKey = 'ai_mastery_rating';
  static const String _kStyleKey = 'ai_player_style';
  static const String _kProfileKey = 'ai_adaptive_profile_v1';

  // Hidden mastery rating (starts at 1000)
  double _masteryRating = 1000.0;
  double get masteryRating => _masteryRating;
  String _lastStyle = 'positional';
  AdaptiveAIProfile _profile = AdaptiveAIProfile.initial();
  AdaptiveAIProfile get profile => _profile;
  int _sessionMoveCount = 0;
  int get sessionMoveCount => _sessionMoveCount;

  Future<void> init() async {
    final prefs = await SharedPreferences.getInstance();
    _masteryRating = prefs.getDouble(_kRatingKey) ?? 1000.0;
    _lastStyle = prefs.getString(_kStyleKey) ?? 'positional';
    final storedProfile = prefs.getString(_kProfileKey);
    if (storedProfile != null && storedProfile.isNotEmpty) {
      try {
        final decoded = jsonDecode(storedProfile);
        if (decoded is Map<String, dynamic>) {
          _profile = AdaptiveAIProfile.fromJson(decoded);
          _lastStyle = _profile.style;
          PersonalityEngine().forcePersonality(_profile.counterPersonality);
        }
      } catch (_) {
        _profile = AdaptiveAIProfile.initial();
      }
    } else if (_lastStyle != _profile.style) {
      _profile = AdaptiveAIProfile(
        style: _lastStyle,
        gameType: _profile.gameType,
        precision: _profile.precision,
        pressure: _profile.pressure,
        solidity: _profile.solidity,
        volatility: _profile.volatility,
        sampleSize: _profile.sampleSize,
        recentMoveTypes: _profile.recentMoveTypes,
        signatureMoves: _profile.signatureMoves,
        signatureMoveCounts: _profile.signatureMoveCounts,
      );
    }
  }

  Future<void> _save() async {
    final prefs = await SharedPreferences.getInstance();
    await prefs.setDouble(_kRatingKey, _masteryRating);
    await prefs.setString(_kStyleKey, _lastStyle);
    await prefs.setString(_kProfileKey, jsonEncode(_profile.toJson()));
  }

  void startAdaptiveSession() {
    _sessionMoveCount = 0;
    PersonalityEngine().forcePersonality(_profile.counterPersonality);
  }

  Future<AdaptiveAIProfile> recordPlayerMove({
    required Move move,
    required ChessEngine engineAfterMove,
    required PieceColor playerColor,
    required int moveNumber,
    double? moveAccuracy,
    int? centipawnLoss,
  }) async {
    _sessionMoveCount += 1;
    _profile = _profile.observeMove(
      move: move,
      engineAfterMove: engineAfterMove,
      playerColor: playerColor,
      moveNumber: moveNumber,
      moveAccuracy: moveAccuracy,
      centipawnLoss: centipawnLoss,
    );
    _lastStyle = _profile.style;
    PersonalityEngine().forcePersonality(_profile.counterPersonality);
    await _save();
    return _profile;
  }

  // Track recent accuracy to avoid sudden jumps
  final List<double> _accuracyHistory = [];
  static const int _historyLimit = 5;

  /// Update mastery based on game results
  /// [accuracy] - 0.0 to 100.0
  /// [won] - true if player won
  /// [difficulty] - current AI level
  Map<String, dynamic> updateMastery({
    required double accuracy,
    required bool won,
    required AIDifficulty difficulty,
  }) {
    _accuracyHistory.add(accuracy);
    if (_accuracyHistory.length > _historyLimit) {
      _accuracyHistory.removeAt(0);
    }

    final avgAccuracy =
        _accuracyHistory.reduce((a, b) => a + b) / _accuracyHistory.length;

    double ratingDelta = 0;

    // k-factor for mastery scaling
    const double k = 20.0;

    if (won) {
      // Bonus for high accuracy wins
      if (accuracy > 80) {
        ratingDelta = k * 1.5;
      } else {
        ratingDelta = k;
      }
    } else {
      // Penalty for poor accuracy losses
      if (accuracy < 50) {
        ratingDelta = -k * 1.2;
      } else {
        ratingDelta = -k * 0.5;
      }
    }

    _masteryRating += ratingDelta;
    _masteryRating = _masteryRating.clamp(400.0, 3000.0);
    _save(); // Non-blocking persist

    // Determine if we should recommend a difficulty change
    String? recommendation;
    bool shouldLevelUp = false;

    if (_masteryRating > _difficultyToRating(difficulty) + 300 &&
        avgAccuracy > 85) {
      shouldLevelUp = true;
      recommendation = "You're dominating! Ready for a harder AI?";
    } else if (_masteryRating < _difficultyToRating(difficulty) - 200 &&
        avgAccuracy < 40) {
      recommendation = "This level seems tough. Want to try a more relaxed AI?";
    }

    return {
      'newRating': _masteryRating,
      'delta': ratingDelta,
      'recommendation': recommendation,
      'shouldLevelUp': shouldLevelUp,
      'avgAccuracy': avgAccuracy,
    };
  }

  double _difficultyToRating(AIDifficulty diff) {
    return switch (diff) {
      AIDifficulty.basic => 800.0,
      AIDifficulty.intermediate => 1200.0,
      AIDifficulty.advanced => 1800.0,
      AIDifficulty.impossible => 2400.0,
      AIDifficulty.aiMode => 2800.0,
    };
  }

  /// Suggest a personality based on player style (DYNAMIC COUNTER-PLAY)
  AIPersonality suggestPersonality(String style) {
    _lastStyle = style;
    _profile = AdaptiveAIProfile(
      style: style,
      gameType: _profile.gameType,
      precision: _profile.precision,
      pressure: _profile.pressure,
      solidity: _profile.solidity,
      volatility: _profile.volatility,
      sampleSize: _profile.sampleSize,
      recentMoveTypes: _profile.recentMoveTypes,
      signatureMoves: _profile.signatureMoves,
      signatureMoveCounts: _profile.signatureMoveCounts,
    );
    _save();

    final personality = switch (style.toLowerCase()) {
      'aggressive' || 'pawn_storm' || 'sacrificial' => AIPersonality.defensive,
      'defensive' || 'solid' || 'passive' => AIPersonality.aggressive,
      'positional' || 'strategic' => AIPersonality.tricky,
      'chaotic' || 'random' => AIPersonality.coach,
      _ => AIPersonality.coach,
    };
    PersonalityEngine().forcePersonality(personality);
    return personality;
  }
}
