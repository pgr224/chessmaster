import 'dart:async';
import 'native_stockfish.dart';
import 'candidate_model.dart';

// These are called by AIEngineController on Native (Mobile/Desktop)
String _currentDifficulty = 'basic';

void jsEngineInit(String mode, String difficulty) {
  _currentDifficulty = difficulty;
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
  if (_currentDifficulty == 'aiMode') {
    // Temporary fallback: route aiMode to a stronger Stockfish search on Android.
    final best =
        await NativeStockfish().getBestMove(fen, depth: 20, movetime: movetime);
    return best != null ? {'move': best} : null;
  }

  int depth = 10;
  switch (_currentDifficulty) {
    case 'basic':
      depth = 2;
      break;
    case 'intermediate':
      depth = 8;
      break;
    case 'advanced':
      depth = 20;
      break;
    case 'impossible':
      depth = 32;
      break;
  }
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
