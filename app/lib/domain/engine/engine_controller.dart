/// AIEngineController — Unified platform-aware chess engine controller
/// Optimized to prevent stalls and handle timeouts with fallbacks.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'chess_engine.dart';
import 'ai_engine.dart';
import '../../data/models/game_config.dart';

// Conditional import: web gets the real JS bridge, mobile gets a stub
import 'native_engine_bridge_stub.dart'
    if (dart.library.js_interop) 'js_engine_bridge.dart' as js_bridge;

class AIEngineController {
  GameMode _mode = GameMode.singlePlayer;
  AIDifficulty _difficulty = AIDifficulty.basic;
  bool _initialized = false;
  
  static final AIEngineController _instance = AIEngineController._internal();
  factory AIEngineController() => _instance;
  AIEngineController._internal();

  /// Constants for time management
  static const Map<AIDifficulty, int> _maxTimeMs = {
    AIDifficulty.basic: 2250,
    AIDifficulty.intermediate: 4000,
    AIDifficulty.advanced: 7250,
    AIDifficulty.impossible: 17000,
  };

  static const int _fallbackBufferMs = 2000;

  /// Tracks active request to allow cancellation
  int _activeRequestId = 0;

  /// Initialize engine for the current game session
  void init(GameMode mode, AIDifficulty? difficulty) {
    _mode = mode;
    _difficulty = difficulty ?? AIDifficulty.basic;
    _initialized = true;

    if (kIsWeb) {
      js_bridge.jsEngineInit(mode.name, _difficulty.name);
    }
  }

  /// Get the best move for the current position with robust timeout handling
  Future<String?> getBestMove(String fen, {ChessEngine? engine, bool humanized = true}) async {
    if (!_initialized) return null;
    if (_mode == GameMode.twoPlayer || _mode == GameMode.multiplayer) return null;

    final requestId = ++_activeRequestId;
    final maxTime = _maxTimeMs[_difficulty] ?? 2000;
    final fallbackTrigger = maxTime - _fallbackBufferMs;

    // 1. Simulate Human Thinking Delay (only for Single Player, not Practice)
    if (humanized && _mode != GameMode.practice) {
      final baseDelay = switch (_difficulty) {
        AIDifficulty.basic => 600,
        AIDifficulty.intermediate => 1000,
        _ => 400,
      };
      final randomDelay = (baseDelay * (0.8 + (math.Random().nextDouble() * 0.4))).toInt();
      await Future.delayed(Duration(milliseconds: randomDelay));
      if (requestId != _activeRequestId) return null; // Cancelled
    }

    try {
      String? resultMove;

      if (kIsWeb) {
        // Web context: Uses JS Engine Service (Stockfish WASM / Sunfish)
        // engine_service.js already has internal timeout/fallback, 
        // but we wrap it here for extra safety.
        resultMove = await js_bridge.jsEngineGetBestMove(fen).timeout(
          Duration(milliseconds: maxTime),
          onTimeout: () {
            print('[AIEngineController] JS Engine timed out, using local fallback');
            return null;
          },
        );
      } else if (engine != null) {
        // Native/Mobile context: Uses Dart AIEngine on Isolates
        resultMove = await AIEngine.getBestMove(
          engine, 
          _difficulty, 
          timeout: Duration(milliseconds: fallbackTrigger)
        ).then((m) => m?.toAlgebraic()).timeout(
          Duration(milliseconds: maxTime),
          onTimeout: () => null,
        );
      }

      // 2. FALLBACK SYSTEM: If engine failed or timed out, use quick fallback
      if (resultMove == null && engine != null) {
        if (requestId != _activeRequestId) return null;
        print('[AIEngineController] Using fallbackMove for $fen');
        resultMove = await fallbackMove(fen, engine: engine);
      }

      return resultMove;
    } catch (e) {
      print('[AIEngineController] Error in getBestMove: $e');
      if (engine != null) return await fallbackMove(fen, engine: engine);
      return null;
    }
  }

  /// Immediate fallback move generation using Sunfish (Dart side)
  Future<String?> fallbackMove(String fen, {required ChessEngine engine}) async {
    // Generate a quick move: Prefer captures or checks, otherwise first legal
    final moves = engine.allLegalMoves();
    if (moves.isEmpty) return null;

    // Fast heuristic sort: Captures > Checks > Random
    moves.sort((a, b) {
      if (b.capturedPiece != null && a.capturedPiece == null) return 1;
      if (a.capturedPiece != null && b.capturedPiece == null) return -1;
      return 0;
    });

    return moves.first.toAlgebraic();
  }

  /// Stop current engine calculation
  void cancelEngine() {
    _activeRequestId++; // Invalidate pending requests
    if (kIsWeb) {
      // In JS, we might need a specific 'stop' command to the worker
      // For now, we rely on the bridge's dispose or requestId tracking.
    }
  }

  /// Get the currently active engine name (for debugging/UI)
  String get activeEngineName {
    if (!_initialized) return 'none';
    if (kIsWeb) return js_bridge.jsEngineGetActiveEngine();
    return 'dart_ai';
  }

  /// Dispose all engine resources
  void dispose() {
    if (kIsWeb) {
      js_bridge.jsEngineDispose();
    }
    _initialized = false;
  }
}
