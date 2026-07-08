import 'dart:async';
import 'native_stockfish.dart';
import 'candidate_model.dart';

// These are called by AIEngineController on Native (Mobile/Desktop)
String _currentDifficulty = 'basic';
int _currentDifficultyLevel = 10;

void jsEngineInit(String mode, String difficulty, {int? difficultyLevel}) {
  _currentDifficulty = difficulty;
  if (difficultyLevel != null) {
    _currentDifficultyLevel = difficultyLevel;
  } else {
    // Map existing text difficulty to a sensible default if not provided
    switch (difficulty) {
      case 'basic': _currentDifficultyLevel = 10; break;
      case 'intermediate': _currentDifficultyLevel = 30; break;
      case 'advanced': _currentDifficultyLevel = 60; break;
      case 'impossible': _currentDifficultyLevel = 100; break;
      case 'aiMode': _currentDifficultyLevel = 100; break;
    }
  }
  NativeStockfish().init();
}

Future<Map<String, dynamic>> jsEngineAnalyzeStyle(
  String fen,
  List<String> recentMoves,
) async {
  final aggressive = recentMoves.any((m) => m.contains('+') || m.contains('#'));
  final defensive = recentMoves.length > 5 && !aggressive;
  return {
    'style': aggressive ? 'aggressive' : defensive ? 'defensive' : 'positional',
    'confidence': 0.6,
    'suggested_personality': aggressive ? 'aggressive' : 'defensive',
  };
}

Future<Map<String, dynamic>?> jsEngineGetBestMove(String fen,
    {int? movetime}) async {
  if (_currentDifficulty == 'basic' || _currentDifficulty == 'intermediate') {
    return null; // AIEngineController will fallback to Dart Sunfish automatically.
  }

  if (_currentDifficulty == 'aiMode') {
    // AI Mode uses a strong depth, but actual humanizing happens in AIEngineController
    final best =
        await NativeStockfish().getBestMove(fen, depth: 24, movetime: movetime);
    return best != null ? {'move': best} : null;
  }

  // Linear scaling of depth from 1 to 24 based on 0-100 difficulty level
  // Easy (0-20) -> depth 1 to 5
  // Medium (21-40) -> depth 5 to 10
  // Hard (41-79) -> depth 10 to 19
  // Impossible (80-100) -> depth 19 to 24
  int depth = 1 + ((_currentDifficultyLevel / 100.0) * 23).round();
  
  final bestMove = await NativeStockfish()
      .getBestMove(fen, depth: depth, movetime: movetime);
  return bestMove != null ? {'move': bestMove} : null;
}

Future<List<MoveCandidate>> jsEngineGetTopMoves(
    String fen, int depth, int count,
    {int? movetime}) async {
  // This is only used for humanoid AI, which uses Stockfish for tactical candidates.
  // We ignore aiMode check here as AIEngineController filters it.
  return NativeStockfish().getTopMoves(fen, depth, count, movetime: movetime);
}

String jsEngineGetActiveEngine() => _currentDifficulty == 'aiMode'
    ? 'stockfish_native_ai_fallback'
    : 'stockfish_native';

void jsEngineDispose() {
  NativeStockfish().dispose();
}
