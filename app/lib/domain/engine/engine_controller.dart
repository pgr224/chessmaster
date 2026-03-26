/// EngineController — Unified platform-aware chess engine controller
///
/// Routes AI computation to the correct engine based on platform and difficulty:
///   - WEB: delegates to window.ChessEngineService (Sunfish/Stockfish Web Workers)
///   - MOBILE: delegates to Dart AIEngine on isolates
///
/// Provides a single async API for GameBloc regardless of platform.

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

  /// Initialize engine for the current game session
  void init(GameMode mode, AIDifficulty? difficulty) {
    _mode = mode;
    _difficulty = difficulty ?? AIDifficulty.basic;
    _initialized = true;

    if (kIsWeb) {
      // On web: initialize the JS engine service which spawns Web Workers
      js_bridge.jsEngineInit(mode.name, _difficulty.name);
    }
    // On mobile: no separate init needed, AIEngine runs stateless on isolates
  }

  /// Get the best move for the current position
  /// [fen] — current board state in FEN notation
  /// [engine] — ChessEngine instance (needed for mobile Dart AI)
  /// Returns move in algebraic format (e.g. "e2e4") or null
  Future<String?> getBestMove(String fen, {ChessEngine? engine}) async {
    if (!_initialized) return null;

    // No AI for two-player or multiplayer
    if (_mode == GameMode.twoPlayer || _mode == GameMode.multiplayer) {
      return null;
    }

    if (kIsWeb) {
      // Web: delegate to JS Web Worker (non-blocking)
      return await js_bridge.jsEngineGetBestMove(fen);
    } else {
      // Mobile: use Dart isolate via AIEngine
      if (engine != null) {
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
