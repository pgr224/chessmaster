/// AIEngineController — Unified platform-aware chess engine controller
/// Optimized to prevent stalls and handle timeouts with fallbacks.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/foundation.dart' show kIsWeb;
import 'chess_engine.dart';
import '../../data/models/game_config.dart';

// Conditional import: web gets the real JS bridge, mobile gets the real native bridge
import 'native_engine_bridge_stub.dart'
    if (dart.library.io) 'native_engine_bridge.dart'
    if (dart.library.js_interop) 'js_engine_bridge.dart' as js_bridge;

import 'personality_engine.dart';
import 'candidate_model.dart';

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
    AIDifficulty.advanced: 5000,
    AIDifficulty.impossible: 5000, // Reduced from 17000 to keep it engaging
    AIDifficulty.aiMode: 7000, // Reduced from 25000
  };

  static const int _fallbackBufferMs = 2000; // reserved for retry logic

  /// Tracks active request to allow cancellation
  int _activeRequestId = 0;

  /// Remember previous emergency fallback source square to reduce robotic repeats.
  String? _lastFallbackFrom;

  /// Tracks which path produced the latest AI move for debug UI.
  String _lastMoveSource = 'none';

  String get lastMoveSource => _lastMoveSource;

  /// Current AI Personality Message (for UI thinking bubble)
  /// Current AI Personality Message (for UI thinking bubble)
  String get aiMessage => _latestThinkingMessage ?? PersonalityEngine().generateNewMessage();
  String? _latestThinkingMessage;

  void setThinkingMessage(String msg) => _latestThinkingMessage = msg;
  void clearThinkingMessage() => _latestThinkingMessage = null;

  /// Initialize engine for the current game session
  void init(GameMode mode, AIDifficulty? difficulty) {
    _mode = mode;
    _difficulty = difficulty ?? AIDifficulty.basic;
    _initialized = true;

    // Both Web and Native use the unified js_bridge (aliased depending on platform)
    js_bridge.jsEngineInit(mode.name, _difficulty.name);
  }

  /// Get the best move for the current position with robust timeout handling
  Future<String?> getBestMove(String fen,
      {ChessEngine? engine, bool humanized = true, int moveNumber = 0}) async {
    if (!_initialized) return null;
    if (_mode == GameMode.twoPlayer || _mode == GameMode.multiplayer)
      return null;

    _lastMoveSource = 'none';

    final requestId = ++_activeRequestId;

    // ── SMART/HUMANOID AI PIPELINE (Advanced, Impossible, AI Mode) ──
    if (_difficulty == AIDifficulty.aiMode ||
        _difficulty == AIDifficulty.impossible ||
        _difficulty == AIDifficulty.advanced) {
      return _getSmartMove(fen, requestId,
          engine: engine, moveNumber: moveNumber);
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
        _lastMoveSource = _normalizeMoveSource(js_bridge.jsEngineGetActiveEngine());
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
      {ChessEngine? engine, int moveNumber = 0}) async {
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
          final int baseTime = (800 + (complexity * 50)).toInt();
          dynamicMoveTime =
              (baseTime * personalityMult).toInt().clamp(300, cap);

          // SET DYNAMIC THINKING MESSAGE
          if (pieceCount < 10) {
            _latestThinkingMessage = "Endgame time! Let's see... 🔍";
          } else if (complexity > 40) {
            _latestThinkingMessage = "Hmm, this is tricky! 🧠";
          } else if (engine.isInCheck) {
            _latestThinkingMessage = "Check! I need to move! 🛡️";
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
          _lastMoveSource = _normalizeMoveSource(js_bridge.jsEngineGetActiveEngine());
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

      if (_lastMoveSource == 'none') {
        _lastMoveSource = _normalizeMoveSource(js_bridge.jsEngineGetActiveEngine());
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
      if (i < candidates.length - 1 &&
          (candidates[i].score - candidates[i + 1].score) > 80) {
        return m;
      }

      // Otherwise, keep looking for a better "smart" move
    }

    return candidates.first.uci;
  }

  /// Immediate fallback move generation using Sunfish (Dart side)
  Future<String?> fallbackMove(String fen,
      {required ChessEngine engine}) async {
    final moves = engine.allLegalMoves();
    if (moves.isEmpty) return null;

    final ranked = _rankFallbackMoves(engine, moves);
    if (ranked.isEmpty) return moves.first.toAlgebraic();

    // Pick from top 2-3 to keep play natural while staying strong enough.
    final topWindow = ranked.length >= 3 ? 3 : ranked.length;
    final pick = ranked[math.Random().nextInt(topWindow)];
    _lastFallbackFrom = pick.from.toAlgebraic();
    _lastMoveSource = 'dart-fallback';
    return pick.toAlgebraic();
  }

  String _normalizeMoveSource(String raw) {
    final v = raw.toLowerCase();
    if (v.contains('sunfish')) return 'sunfish';
    if (v.contains('stockfish')) return 'stockfish';
    return 'stockfish';
  }

  List<Move> _rankFallbackMoves(ChessEngine engine, List<Move> moves) {
    final scored = <(Move, double)>[];

    for (final m in moves) {
      final piece = engine.pieceAt(m.from);
      if (piece == null) continue;

      double score = 0;

      // Tactical priorities
      if (m.capturedPiece != null) {
        score += 80;
        score += _pieceValue(m.capturedPiece!.type) * 1.5;
      }
      if (_givesCheck(engine, m)) score += 70;

      // Strategic shape: prefer central influence and development.
      score += _centerBonus(m.to) * 4;
      if (_isDevelopingMove(piece, m)) score += 18;

      // Keep the king safer in fallback mode (unless forced).
      if (piece.type == PieceType.king && m.capturedPiece == null) score -= 12;

      // Anti-repeat: avoid moving same source square if alternatives exist.
      if (_lastFallbackFrom != null && m.from.toAlgebraic() == _lastFallbackFrom) {
        score -= 30;
      }

      scored.add((m, score));
    }

    scored.sort((a, b) => b.$2.compareTo(a.$2));

    // If every top option comes from the same square, allow it (forced-like positions).
    if (scored.length > 1 && _lastFallbackFrom != null) {
      final diversified = scored
          .where((s) => s.$1.from.toAlgebraic() != _lastFallbackFrom)
          .map((s) => s.$1)
          .toList();
      if (diversified.isNotEmpty) {
        return [...diversified, ...scored.map((s) => s.$1)];
      }
    }

    return scored.map((s) => s.$1).toList();
  }

  bool _givesCheck(ChessEngine engine, Move move) {
    try {
      final clone = ChessEngine.fromFEN(engine.toFEN());
      final applied = clone.makeMove(Move.fromAlgebraic(move.toAlgebraic()));
      if (!applied) return false;
      return clone.status == GameStatus.check || clone.status == GameStatus.checkmate;
    } catch (_) {
      return false;
    }
  }

  double _centerBonus(Square sq) {
    final center = const [Square(3, 3), Square(4, 3), Square(3, 4), Square(4, 4)];
    if (center.contains(sq)) return 2.0;
    final nearCenter = (sq.file >= 2 && sq.file <= 5 && sq.rank >= 2 && sq.rank <= 5);
    return nearCenter ? 1.0 : 0.0;
  }

  bool _isDevelopingMove(ChessPiece piece, Move move) {
    if (piece.type != PieceType.knight && piece.type != PieceType.bishop) return false;
    final fromRank = move.from.rank;
    final toRank = move.to.rank;
    if (piece.color == PieceColor.white) return fromRank <= 1 && toRank >= 2;
    return fromRank >= 6 && toRank <= 5;
  }

  int _pieceValue(PieceType t) {
    return switch (t) {
      PieceType.pawn => 1,
      PieceType.knight => 3,
      PieceType.bishop => 3,
      PieceType.rook => 5,
      PieceType.queen => 9,
      PieceType.king => 100,
    };
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
