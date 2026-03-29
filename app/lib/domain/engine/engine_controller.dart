/// EngineController — Unified platform-aware chess engine controller
///
/// Routes AI computation to the correct engine based on platform and difficulty:
///   - WEB: delegates to window.ChessEngineService (Sunfish/Stockfish Web Workers)
///   - MOBILE: delegates to Dart AIEngine on isolates
///
/// Provides a single async API for GameBloc regardless of platform.
library;

import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'chess_engine.dart';
import 'ai_engine.dart';
import '../../data/models/game_config.dart';

// Conditional import: web gets the real JS bridge, mobile gets a stub
import 'native_engine_bridge_stub.dart'
    if (dart.library.js_interop) 'js_engine_bridge.dart' as js_bridge;

class EngineController {
  GameMode _mode = GameMode.singlePlayer;
  AIDifficulty _difficulty = AIDifficulty.basic;
  bool _initialized = false;
  
  static final math.Random _rng = math.Random();

  /// Initialize engine for the current game session
  void init(GameMode mode, AIDifficulty? difficulty) {
    _mode = mode;
    _difficulty = difficulty ?? AIDifficulty.basic;
    _initialized = true;

    if (kIsWeb) {
      js_bridge.jsEngineInit(mode.name, _difficulty.name);
    }
  }

  /// Get the best move for the current position, optionally humanized
  Future<String?> getBestMove(String fen, {ChessEngine? engine, bool humanized = true}) async {
    if (!_initialized) return null;

    if (_mode == GameMode.twoPlayer || _mode == GameMode.multiplayer) {
      return null;
    }

    // 1. Simulate Human Thinking Delay (only for Single Player/Multiplayer AI, not Practice)
    if (humanized && _mode != GameMode.practice) {
      final baseDelay = switch (_difficulty) {
        AIDifficulty.basic => 800,
        AIDifficulty.intermediate => 1200,
        AIDifficulty.advanced => 2000,
        AIDifficulty.impossible => 500,
      };
      final randomDelay = (baseDelay * (0.8 + (math.Random().nextDouble() * 0.4))).toInt();
      await Future.delayed(Duration(milliseconds: randomDelay));
    }

    if (kIsWeb) {
      return await js_bridge.jsEngineGetBestMove(fen);
    } else {
      if (engine != null) {
        // 2. Suboptimal Move Selection for Beginners (Adaptive Humanization)
        if (humanized && (_difficulty == AIDifficulty.basic || _difficulty == AIDifficulty.intermediate)) {
          final topMoves = await AIEngine.getTopMoves(engine, _difficulty, count: 3);
          if (topMoves.isNotEmpty) {
            // Logic: Basic difficulty picks best only 40% of time, Intermediate 80%
            final p = math.Random().nextDouble();
            final threshold = _difficulty == AIDifficulty.basic ? 0.4 : 0.8;
            
            if (p > threshold && topMoves.length > 1) {
              // Pick 2nd best move if it's not absolutely terrible
              final diff = topMoves[0].$2 - topMoves[1].$2;
              if (diff < 500) return topMoves[1].$1.toAlgebraic();
            }
            return topMoves[0].$1.toAlgebraic();
          }
        }

        final timeout = (_difficulty == AIDifficulty.advanced ||
                _difficulty == AIDifficulty.impossible)
            ? const Duration(seconds: 10)
            : const Duration(seconds: 5);

        final move = await AIEngine.getBestMove(engine, _difficulty, timeout: timeout);
        return move?.toAlgebraic();
      }
      return null;
    }
  }

  /// Validate a move (used for multiplayer/two-player on web)
  bool validateMove(String fen, String from, String to, {String? promotion}) {
    if (kIsWeb) {
      return js_bridge.jsEngineValidateMove(fen, from, to, promotion);
    }
    return true; // On mobile, validation is handled by ChessEngine directly
  }

  /// Get the currently active engine name (for debugging/UI)
  String get activeEngineName {
    if (!_initialized) return 'none';
    if (kIsWeb) return js_bridge.jsEngineGetActiveEngine();
    if (_mode == GameMode.twoPlayer || _mode == GameMode.multiplayer) return 'validation';
    return switch (_difficulty) {
      AIDifficulty.basic || AIDifficulty.intermediate => 'dart_ai',
      AIDifficulty.advanced || AIDifficulty.impossible => 'dart_deep',
    };
  }

  /// Dispose all engine resources
  void dispose() {
    if (kIsWeb) {
      js_bridge.jsEngineDispose();
    }
    _initialized = false;
  }
}
