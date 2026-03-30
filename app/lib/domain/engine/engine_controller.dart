/// AIEngineController — Unified platform-aware chess engine controller
/// Optimized to prevent stalls and handle timeouts with fallbacks.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'chess_engine.dart';
import 'ai_engine.dart';
import '../../data/models/game_config.dart';

// Conditional import: web gets the real JS bridge, mobile gets the real native bridge
import 'native_engine_bridge.dart'
    if (dart.library.js_interop) 'js_engine_bridge.dart' as js_bridge;

import 'personality_engine.dart';
import 'move_selector.dart';
import 'native_stockfish.dart'; // For MoveCandidate

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
    AIDifficulty.aiMode: 25000, // Leela can use a bit more time if needed
  };

  static const int _fallbackBufferMs = 2000;

  /// Tracks active request to allow cancellation
  int _activeRequestId = 0;

  /// Current AI Personality Message (for UI thinking bubble)
  String? get aiMessage => PersonalityEngine().currentPersonality.message;

  /// Initialize engine for the current game session
  void init(GameMode mode, AIDifficulty? difficulty) {
    _mode = mode;
    _difficulty = difficulty ?? AIDifficulty.basic;
    _initialized = true;

    // Both Web and Native use the unified js_bridge (aliased depending on platform)
    js_bridge.jsEngineInit(mode.name, _difficulty.name);
  }

  /// Get the best move for the current position with robust timeout handling
  Future<String?> getBestMove(String fen, {ChessEngine? engine, bool humanized = true, int moveNumber = 0}) async {
    if (!_initialized) return null;
    if (_mode == GameMode.twoPlayer || _mode == GameMode.multiplayer) return null;

    final requestId = ++_activeRequestId;

    // ── SMART/HUMANOID AI PIPELINE (Advanced, Impossible, AI Mode) ──
    if (_difficulty == AIDifficulty.aiMode || _difficulty == AIDifficulty.impossible || _difficulty == AIDifficulty.advanced) {
      return _getSmartMove(fen, requestId, engine: engine, moveNumber: moveNumber);
    }

    final maxTime = _maxTimeMs[_difficulty] ?? 2000;

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

      // Simple call for lower difficulties
      final Map<String, dynamic>? res = (await js_bridge.jsEngineGetBestMove(fen).timeout(
        Duration(milliseconds: maxTime),
        onTimeout: () => null,
      )) as Map<String, dynamic>?;
      resultMove = res?['move'] as String?;

      if (resultMove == null && engine != null) {
        if (requestId != _activeRequestId) return null;
        resultMove = await fallbackMove(fen, engine: engine);
      }

      return resultMove;
    } catch (e) {
      if (engine != null) return await fallbackMove(fen, engine: engine);
      return null;
    }
  }

  /// SMART AI System: MultiPV candidates -> Opening randomness -> Quality filtering
  Future<String?> _getSmartMove(String fen, int requestId, {ChessEngine? engine, int moveNumber = 0}) async {
    try {
      List<MoveCandidate> candidates = [];
      String? bestFound;

      if (!kIsWeb) {
        candidates = await js_bridge.jsEngineGetTopMoves(fen, 15, 3, movetime: 1000);
        if (candidates.isNotEmpty) {
          bestFound = candidates.first.uci;
        }
      } else {
        final res = await js_bridge.jsEngineGetBestMove(fen);
        bestFound = res?['move'] as String?;
        if (res?['candidates'] != null) {
          candidates = List<MoveCandidate>.from(res!['candidates'] as List);
        } else if (bestFound != null) {
          candidates = [MoveCandidate(uci: bestFound, score: 0)];
        }
      }

      if (requestId != _activeRequestId) return null;
      if (candidates.isEmpty) return bestFound;

      // ── 1. OPENING RANDOMIZATION (First 10 moves) ──
      if (moveNumber < 10 && candidates.length > 1) {
        final rand = math.Random().nextDouble();
        if (rand > 0.6) {
           return candidates[math.Random().nextInt(candidates.length)].uci;
        }
      }

      // ── 2. QUALITY FILTER (Reject repetitive edge pawn spam e.g., a6, h6) ──
      String move = _pickSmartMove(candidates);

      // ── 3. Thinking Delay for Realism ──
      if (_difficulty == AIDifficulty.aiMode) {
        int baseDelay = candidates.length > 2 && (candidates[0].score - candidates[1].score).abs() < 40 ? 1500 : 500;
        final delay = (baseDelay * (0.8 + (math.Random().nextDouble() * 0.5))).clamp(300, 2000).toInt();
        await Future.delayed(Duration(milliseconds: delay));
      }

      return move;
    } catch (e) {
      print('[SmartAI] Error: $e');
      return engine != null ? await fallbackMove(fen, engine: engine) : null;
    }
  }

  /// Selects the best move while avoiding "bad" repetitive patterns
  String _pickSmartMove(List<MoveCandidate> candidates) {
    if (candidates.isEmpty) return 'none';
    
    // Heuristic: Avoid moves that look like edge pawn spam (a, h pawns moving 1 square repetitively)
    // if best move is a bad/useless pawn push, try the second best if it's within a reasonable CP margin
    for (var i = 0; i < candidates.length; i++) {
      final m = candidates[i].uci;
      final isEdgePawn = m.startsWith('a') || m.startsWith('h');
      
      if (!isEdgePawn) return m; // Prefer non-edge moves
      
      // If it is edge pawn, but it's much better than the next move (> 80cp), we might have to take it
      if (i < candidates.length - 1 && (candidates[i].score - candidates[i+1].score) > 80) {
        return m;
      }
      
      // Otherwise, keep looking for a better "smart" move
    }

    return candidates.first.uci;
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
    return js_bridge.jsEngineGetActiveEngine();
  }

  /// Dispose all engine resources
  void dispose() {
    js_bridge.jsEngineDispose();
    _initialized = false;
  }
}
