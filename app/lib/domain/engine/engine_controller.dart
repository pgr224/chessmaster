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
import 'native_engine_bridge_stub.dart'
    if (dart.library.io) 'native_engine_bridge.dart'
    if (dart.library.js_interop) 'js_engine_bridge.dart' as js_bridge;

import '../../core/services/logging_service.dart';
import 'adaptive_ai_profile.dart';
import 'personality_engine.dart';
import 'candidate_model.dart';
import 'move_selector.dart';

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
    AIDifficulty.advanced: 7000,
    AIDifficulty.impossible: 12000, // Near-master level search time
    AIDifficulty.aiMode: 18000, // GM-level deep analysis
  };

  /// Tracks active request to allow cancellation
  int _activeRequestId = 0;

  /// Remember previous emergency fallback source square to reduce robotic repeats.
  String? _lastFallbackFrom;

  /// Tracks which path produced the latest AI move for debug UI.
  String _lastMoveSource = 'none';

  String get lastMoveSource => _lastMoveSource;

  /// Current AI Personality Message (for UI thinking bubble)
  /// Current AI Personality Message (for UI thinking bubble)
  String get aiMessage =>
      _latestThinkingMessage ?? PersonalityEngine().generateNewMessage();
  String? _latestThinkingMessage;

  void setThinkingMessage(String msg) => _latestThinkingMessage = msg;
  void clearThinkingMessage() => _latestThinkingMessage = null;

  /// Analyze player style for adaptive AI
  Future<Map<String, dynamic>> analyzePlayerStyle(
      String fen, List<String> recentMoves) async {
    // Use Leela if available, otherwise heuristic analysis
    try {
      return await js_bridge.jsEngineAnalyzeStyle(fen, recentMoves);
    } catch (_) {
      // Fallback heuristic
      bool aggressive =
          recentMoves.any((m) => m.contains('+') || m.contains('#'));
      bool defensive = recentMoves.length > 5 && !aggressive;

      return {
        'style': aggressive
            ? 'aggressive'
            : defensive
                ? 'defensive'
                : 'positional',
        'confidence': 0.7,
        'suggested_personality': aggressive ? 'aggressive' : 'defensive',
      };
    }
  }

  void init(GameMode mode, AIDifficulty? difficulty, {int? difficultyLevel}) {
    _mode = mode;
    _difficulty = difficulty ?? AIDifficulty.basic;
    _initialized = true;

    // Both Web and Native use the unified js_bridge (aliased depending on platform)
    js_bridge.jsEngineInit(mode.name, _difficulty.name, difficultyLevel: difficultyLevel);
  }

  /// Get the best move for the current position with robust timeout handling
  Future<String?> getBestMove(String fen,
      {ChessEngine? engine,
      bool humanized = true,
      int moveNumber = 0,
      double? playerAccuracy,
      AdaptiveAIProfile? adaptiveProfile}) async {
    if (!_initialized) return null;
    if (_mode == GameMode.twoPlayer || _mode == GameMode.multiplayer) {
      return null;
    }

    _lastMoveSource = 'none';

    final requestId = ++_activeRequestId;

    // ── SMART/HUMANOID AI PIPELINE (Advanced, Impossible, AI Mode) ──
    if (_difficulty == AIDifficulty.aiMode) {
      return _getSmartMove(fen, requestId,
          engine: engine,
          moveNumber: moveNumber,
          playerAccuracy: playerAccuracy,
          adaptiveProfile: adaptiveProfile);
    }

    final maxTime = _maxTimeMs[_difficulty] ?? 2000;

    // 1. Simulate Human Thinking Delay (only for Single Player, not Practice)
    if (humanized && _mode != GameMode.practice) {
      final baseDelay = switch (_difficulty) {
        AIDifficulty.basic => 600,
        AIDifficulty.intermediate => 1000,
        _ => 400,
      };
      final randomDelay =
          (baseDelay * (0.8 + (math.Random().nextDouble() * 0.4))).toInt();
      await Future.delayed(Duration(milliseconds: randomDelay));
      if (requestId != _activeRequestId) return null; // Cancelled
    }

    try {
      String? resultMove;

      // Simple call for lower difficulties
      final Map<String, dynamic>? res =
          await js_bridge.jsEngineGetBestMove(fen).timeout(
                Duration(milliseconds: maxTime),
                onTimeout: () => null,
              );
      resultMove = res?['move'] as String?;
      if (resultMove != null) {
        _lastMoveSource =
            _normalizeMoveSource(js_bridge.jsEngineGetActiveEngine());
      }

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
  Future<String?> _getSmartMove(String fen, int requestId,
      {ChessEngine? engine,
      int moveNumber = 0,
      double? playerAccuracy,
      AdaptiveAIProfile? adaptiveProfile}) async {
    try {
      List<MoveCandidate> candidates = [];
      String? bestFound;

      int dynamicMoveTime = _maxTimeMs[_difficulty] ?? 3000;
      if (engine != null) {
        final legalMoves = engine.allLegalMoves();
        final cap = _maxTimeMs[_difficulty] ?? 3000;

        if (legalMoves.length <= 1) {
          dynamicMoveTime = 300; // Forced move
        } else if (engine.isInCheck && legalMoves.length <= 3) {
          dynamicMoveTime = 500; // Simple check evasion
        } else {
          int pieceCount = 0;
          for (int r = 0; r < 8; r++) {
            for (int f = 0; f < 8; f++) {
              if (engine.pieceAt(Square(f, r)) != null) pieceCount++;
            }
          }
          final double complexity =
              (legalMoves.length * 0.4) + (pieceCount * 1.5);
          final double personalityMult =
              PersonalityEngine().currentPersonality.timeMultiplier;

          // ADAPTIVE ACCURACY MULTIPLIER: Only for AI Mode
          double accuracyMult = 1.0;
          final bool isAIMode = _difficulty == AIDifficulty.aiMode;

          if (isAIMode && playerAccuracy != null) {
            final normalizedAccuracy = playerAccuracy.clamp(0.0, 100.0);
            if (normalizedAccuracy >= 95.0) {
              accuracyMult = 2.0; // More time for very strong players
            } else if (normalizedAccuracy >= 90.0) {
              accuracyMult = 1.7;
            } else if (normalizedAccuracy >= 80.0) {
              accuracyMult = 1.4;
            } else if (normalizedAccuracy >= 70.0) {
              accuracyMult = 1.2;
            } else {
              accuracyMult = 1.1;
            }
          } else if (isAIMode) {
            accuracyMult = 1.5;
          }

          if (isAIMode && adaptiveProfile != null) {
            accuracyMult *= adaptiveProfile.timeMultiplier;
          }

          final int baseTime = (800 + (complexity * 60)).toInt();
          dynamicMoveTime = (baseTime * personalityMult * accuracyMult)
              .toInt()
              .clamp(1000, cap)
              .toInt();

          // For AI Mode, we ensure it takes at least 1.5s for non-forced moves
          // to maintain a "thinking" presence, but no longer 8s hardcoded.
          if (isAIMode) {
            dynamicMoveTime = dynamicMoveTime.clamp(1500, cap).toInt();
          }

          // SET DYNAMIC THINKING MESSAGE
          if (isAIMode && adaptiveProfile != null) {
            _latestThinkingMessage = adaptiveProfile.adaptationMessage;
          } else if (pieceCount < 10) {
            _latestThinkingMessage = "Endgame time! Let's see... 🔍";
          } else if (complexity > 45) {
            _latestThinkingMessage = "Hmm, this is extremely complex! 🧠💻";
          } else if (complexity > 30) {
            _latestThinkingMessage = "Analyzing all variations... ⚙️";
          } else if (engine.isInCheck) {
            _latestThinkingMessage = "Check! Evaluating escapes... 🛡️";
          } else {
            _latestThinkingMessage = "Calculating... ⚙️";
          }
        }
      }

      if (!kIsWeb) {
        final rawCandidates = await js_bridge.jsEngineGetTopMoves(fen, 15, 3,
            movetime: dynamicMoveTime);
        candidates = List<MoveCandidate>.from(rawCandidates);
        if (candidates.isNotEmpty) {
          bestFound = candidates.first.uci;
          _lastMoveSource =
              _normalizeMoveSource(js_bridge.jsEngineGetActiveEngine());
        }
      } else {
        final res =
            await js_bridge.jsEngineGetBestMove(fen, movetime: dynamicMoveTime);
        bestFound = res?['move'] as String?;
        if (bestFound != null) {
          _lastMoveSource =
              _normalizeMoveSource(js_bridge.jsEngineGetActiveEngine());
        }
        if (res?['candidates'] != null) {
          final rawCandidates = res!['candidates'];
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
                      return MoveCandidate(
                          uci: uciRaw, score: scoreRaw.toInt());
                    }
                  }
                  return null;
                })
                .whereType<MoveCandidate>()
                .toList(growable: false);
          }
        } else if (bestFound != null) {
          candidates = [MoveCandidate(uci: bestFound, score: 0)];
        }
      }

      if (requestId != _activeRequestId) return null;
      if (candidates.isEmpty) return bestFound;

      // ── 1. OPENING RANDOMIZATION (First 10 moves) ──
      if (moveNumber < 10 && candidates.length > 1) {
        // AI Mode prefers safe remembered player patterns before engine purity.
        if (_difficulty == AIDifficulty.aiMode) {
          final remembered = adaptiveProfile?.chooseSignatureCandidate(
            candidates,
            moveNumber: moveNumber,
          );
          if (remembered != null) {
            _latestThinkingMessage =
                "I remember this shape from your games. Borrowing the idea.";
            return remembered.uci;
          }
        }

        if (_difficulty == AIDifficulty.impossible) {
          return candidates.first.uci;
        }
        // Advanced: 20% chance to pick from top-2 (slight variety, not weakness)
        if (_difficulty == AIDifficulty.advanced) {
          final rand = math.Random().nextDouble();
          if (rand > 0.8) {
            final count = math.min(2, candidates.length);
            return candidates[math.Random().nextInt(count)].uci;
          }
        }
      }

      // ── 2. QUALITY FILTER (Reject repetitive edge pawn spam e.g., a6, h6) ──
      String move;
      final remembered = adaptiveProfile?.chooseSignatureCandidate(
        candidates,
        moveNumber: moveNumber,
      );
      if (remembered != null) {
        _latestThinkingMessage =
            "That is one of your signature ideas. Let's see how you answer it.";
        move = remembered.uci;
      } else {
        var personality = adaptiveProfile?.counterPersonality ??
            PersonalityEngine().currentPersonality;
        int maxLoss = adaptiveProfile?.maxCentipawnLoss ?? 45;
        double errorChance = adaptiveProfile?.errorChance ?? 0.02;

        // RUBBER-BANDING (Live Difficulty Adjustment)
        if (_difficulty == AIDifficulty.aiMode && candidates.isNotEmpty) {
          final eval = candidates.first.score; // AI's perspective
          if (eval > 300) {
            // AI is winning heavily -> ease up to keep player engaged
            errorChance = (errorChance * 3.0).clamp(0.0, 0.15);
            maxLoss += 50; 
          } else if (eval < -150) {
            // AI is losing -> try hard to defend/win
            errorChance = 0.0;
            maxLoss = 10; 
          }

          // Memory Chunk logic
          if (adaptiveProfile != null && adaptiveProfile.recentMoveTypes.length >= 3) {
            final recents = adaptiveProfile.recentMoveTypes;
            // If player played defensively 3 times in a row, force aggression
            if (recents.reversed.take(3).every((t) => t == 'defensive')) {
              personality = AIPersonality.aggressive;
            } else if (recents.reversed.take(3).every((t) => t == 'aggressive')) {
              personality = AIPersonality.defensive;
            }
          }
        }

        move = MoveSelector()
            .select(
              candidates,
              personality,
              errorChance: errorChance,
              maxCentipawnLoss: maxLoss,
            )
            .uci;
      }

      if (_lastMoveSource == 'none') {
        _lastMoveSource =
            _normalizeMoveSource(js_bridge.jsEngineGetActiveEngine());
      }

      return move;
    } catch (e) {
      LoggingService.error('[SmartAI] Error', e);
      return engine != null ? await fallbackMove(fen, engine: engine) : null;
    }
  }



  /// Fallback move generation using Sunfish (Dart side)
  Future<String?> fallbackMove(String fen,
      {required ChessEngine engine}) async {
    final moves = engine.allLegalMoves();
    if (moves.isEmpty) return null;

    Duration timeout = const Duration(seconds: 2);
    if (_difficulty == AIDifficulty.impossible || _difficulty == AIDifficulty.aiMode) {
      timeout = const Duration(milliseconds: 2400); // 20% increase over standard 2s
    } else if (_difficulty == AIDifficulty.advanced) {
      timeout = const Duration(seconds: 2);
    } else if (_difficulty == AIDifficulty.intermediate) {
      timeout = const Duration(seconds: 1);
    } else {
      timeout = const Duration(milliseconds: 500);
    }

    final bestMove = await AIEngine.getBestMove(
      engine,
      _difficulty,
      timeout: timeout,
      personality: PersonalityEngine().currentPersonality,
    );

    if (bestMove != null) {
      _lastMoveSource = 'dart-sunfish';
      return bestMove.toAlgebraic();
    }

    return moves.first.toAlgebraic();
  }

  String _normalizeMoveSource(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('sunfish')) return 'sunfish';
    if (v.contains('stockfish')) return 'stockfish';
    return 'stockfish';
  }

  /// Background analysis of user move (AI Mode)
  Future<Map<String, dynamic>?> analyzeMoveBackground(String fen,
      {int nodes = 1000}) async {
    if (!_initialized) return null;
    return js_bridge.jsEngineGetBestMove(fen);
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
    _lastFallbackFrom = null;
    _lastMoveSource = 'none';
  }
}
