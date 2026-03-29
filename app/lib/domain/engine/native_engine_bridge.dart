/// Native Engine Bridge — Mobile-only fallback
/// On mobile platforms (Android/iOS), uses the existing Dart AI engine
/// running on isolates. No JS interop needed.
library;

import 'chess_engine.dart';
import 'ai_engine.dart';
import '../../data/models/game_config.dart';

/// Native engine wrapper for mobile platforms
class NativeEngineBridge {
  ChessEngine? _engine;
  AIDifficulty _difficulty = AIDifficulty.basic;

  /// Initialize the native engine
  void init(GameMode mode, AIDifficulty? difficulty) {
    _difficulty = difficulty ?? AIDifficulty.basic;
    // Engine instance is managed externally by GameBloc
    // This bridge just tracks config for getBestMove calls
  }

  /// Get best move using the Dart AI engine on an isolate
  /// @param engine - The current ChessEngine instance from GameBloc
  Future<String?> getBestMove(ChessEngine engine) async {
    final depthOverride = _getDepthForDifficulty();
    final effectiveDifficulty = _difficulty;

    final move = await AIEngine.getBestMove(
      engine,
      effectiveDifficulty,
      timeout: Duration(seconds: depthOverride > 6 ? 10 : 5),
    );
    return move?.toAlgebraic();
  }

  /// For Advanced/Impossible on mobile, use deeper search depths
  /// as a practical alternative to Stockfish WASM
  int _getDepthForDifficulty() {
    switch (_difficulty) {
      case AIDifficulty.basic:
        return 1;
      case AIDifficulty.intermediate:
        return 4;
      case AIDifficulty.advanced:
        return 7; // Deeper than default for stronger play
      case AIDifficulty.impossible:
        return 9; // Maximum feasible on mobile isolate
    }
  }

  /// Dispose native engine resources
  void dispose() {
    _engine = null;
  }
}
