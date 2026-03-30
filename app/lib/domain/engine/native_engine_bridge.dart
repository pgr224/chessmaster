import 'dart:async';
import 'native_stockfish.dart';
import 'native_leela.dart';

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

Future<String?> jsEngineGetBestMove(String fen) async {
  if (_currentDifficulty == 'aiMode') {
    // LC0 works best with nodes rather than depth directly in simplistic setups.
    // 50000 nodes is rough equivalent of a decent time. We can just use go depth 15
    // or pass the nodes value. We'll pass nodes = 50000.
    return NativeLeela().getBestMove(fen, 1000); 
  }

  int depth = 10;
  switch (_currentDifficulty) {
    case 'basic': depth = 2; break;
    case 'intermediate': depth = 8; break;
    case 'advanced': depth = 20; break;
    case 'impossible': depth = 32; break;
  }
  return NativeStockfish().getBestMove(fen, depth);
}

String jsEngineGetActiveEngine() => _currentDifficulty == 'aiMode' ? 'lc0_native' : 'stockfish_native';

void jsEngineDispose() {
  if (_currentDifficulty == 'aiMode') {
    NativeLeela().dispose();
  } else {
    NativeStockfish().dispose();
  }
}
