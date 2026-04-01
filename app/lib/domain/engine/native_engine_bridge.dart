import 'dart:async';
import 'native_stockfish.dart';
import 'native_leela.dart';
import 'candidate_model.dart';

// These are called by AIEngineController on Native (Mobile/Desktop)
String _currentDifficulty = 'basic';

void jsEngineInit(String mode, String difficulty) {
  _currentDifficulty = difficulty;
  if (difficulty == 'aiMode') {
    NativeLeela().init();
  } else {
    NativeStockfish().init();
  }
}

Future<Map<String, dynamic>?> jsEngineGetBestMove(String fen,
    {int? movetime}) async {
  if (_currentDifficulty == 'aiMode') {
    final best = await NativeLeela().getBestMove(fen, 1000);
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

String jsEngineGetActiveEngine() =>
    _currentDifficulty == 'aiMode' ? 'lc0_native' : 'stockfish_native';

void jsEngineDispose() {
  if (_currentDifficulty == 'aiMode') {
    NativeLeela().dispose();
  } else {
    NativeStockfish().dispose();
  }
}
