import 'package:flutter_test/flutter_test.dart';
import 'package:chess_master/domain/engine/ai_engine.dart';
import 'package:chess_master/domain/engine/chess_engine.dart';
import 'package:chess_master/domain/engine/engine_controller.dart';
import 'package:chess_master/data/models/game_config.dart';

void main() {
  test('Dart coaching/fallback runs without unsupported browser isolates',
      () async {
    final board = ChessEngine();
    for (var ply = 0; ply < 8; ply++) {
      final move = await AIEngine.getBestMove(board, AIDifficulty.intermediate,
          timeout: const Duration(milliseconds: 40));
      expect(move, isNotNull);
      expect(board.makeMove(move!), true);
    }
    expect(await AIEngine.evaluatePosition(board), isA<int>());
    final top = await AIEngine.getTopMoves(board, AIDifficulty.advanced,
        count: 3, timeout: const Duration(milliseconds: 40));
    expect(top, isNotEmpty);
    for (final entry in top)
      expect(board.allLegalMoves().map((m) => m.toAlgebraic()),
          contains(entry.$1.toAlgebraic()));
  });
  test(
      'missing web engine service still yields a legal selected-difficulty fallback',
      () async {
    final controller = AIEngineController();
    addTearDown(controller.dispose);
    controller.init(GameMode.practice, AIDifficulty.basic);
    final board = ChessEngine();
    final result = await controller.getBestMove(board.toFEN(),
        engine: board, humanized: false);
    expect(board.allLegalMoves().map((m) => m.toAlgebraic()), contains(result));
  });
}
