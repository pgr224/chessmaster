import 'package:flutter_test/flutter_test.dart';

import 'package:chess_master/data/models/game_config.dart';
import 'package:chess_master/domain/engine/chess_engine.dart';
import 'package:chess_master/domain/engine/engine_controller.dart';
import 'package:chess_master/domain/engine/native_engine_bridge.dart' as native;

void main() {
  final controller = AIEngineController();

  tearDown(() => controller.dispose());

  test(
    'human games never invoke a native AI even with a strong difficulty',
    () async {
      for (final mode in [GameMode.twoPlayer, GameMode.multiplayer]) {
        controller.init(mode, AIDifficulty.impossible);
        expect(controller.activeEngineName, 'validation');
        expect(await controller.getBestMove(ChessEngine().toFEN()), isNull);
        expect(
          await controller.analyzeMoveBackground(ChessEngine().toFEN()),
          isNull,
        );
        expect(await native.jsEngineGetBestMove(ChessEngine().toFEN()), isNull);
        expect(
          await native.jsEngineGetTopMoves(ChessEngine().toFEN(), 10, 3),
          isEmpty,
        );
      }
    },
  );

  test(
      'lower native difficulties stay on the Dart engine without loading Stockfish',
      () async {
    for (final difficulty in [AIDifficulty.basic, AIDifficulty.intermediate]) {
      controller.init(GameMode.practice, difficulty);
      expect(controller.activeEngineName, 'dart-sunfish');
      expect(await native.jsEngineGetBestMove(ChessEngine().toFEN()), isNull);
      expect(
        await native.jsEngineGetTopMoves(ChessEngine().toFEN(), 10, 3),
        isEmpty,
      );
    }
  });

  test('strong native initialization is lazy until a move is requested', () {
    // Linux tests do not provide the native Stockfish library: initialization
    // succeeds because selecting a difficulty no longer loads the binary.
    controller.init(GameMode.singlePlayer, AIDifficulty.advanced);
    expect(controller.activeEngineName, 'stockfish_native');
  });

  test('cleanup from an old game cannot stop the newer game controller',
      () async {
    final old = AIEngineController(), current = AIEngineController();
    old.init(GameMode.practice, AIDifficulty.basic);
    current.init(GameMode.practice, AIDifficulty.intermediate);
    old.dispose();
    expect(current.activeEngineName, 'dart-sunfish');
    final board = ChessEngine();
    final result = await current.getBestMove(board.toFEN(),
        engine: board, humanized: false);
    expect(board.allLegalMoves().map((m) => m.toAlgebraic()), contains(result));
    expect(old.activeEngineName, 'none');
    current.dispose();
  });

  test('Dart fallback returns a legal opening move', () async {
    final engine = ChessEngine();
    controller.init(GameMode.practice, AIDifficulty.basic);
    final result = await controller.getBestMove(engine.toFEN(), engine: engine);
    expect(
      engine.allLegalMoves().map((move) => move.toAlgebraic()),
      contains(result),
    );
    expect(controller.lastMoveSource, 'dart-sunfish');
  });

  test('disposal invalidates a pending thinking delay', () async {
    controller.init(GameMode.singlePlayer, AIDifficulty.basic);
    final result = controller.getBestMove(ChessEngine().toFEN());
    controller.dispose();
    expect(await result, isNull);
    expect(controller.activeEngineName, 'none');
    expect(controller.lastMoveSource, 'none');
  });

  test('starting another game invalidates an awaited fallback', () async {
    final engine = ChessEngine();
    controller.init(GameMode.practice, AIDifficulty.basic);
    final result = controller.fallbackMove(engine.toFEN(), engine: engine);
    controller.init(GameMode.multiplayer, AIDifficulty.impossible);
    expect(await result, isNull);
    expect(controller.lastMoveSource, 'none');
  });

  test(
    'fallback rejects a result if the position changed while searching',
    () async {
      final engine = ChessEngine();
      controller.init(GameMode.practice, AIDifficulty.basic);
      final result = controller.fallbackMove(engine.toFEN(), engine: engine);
      expect(engine.makeMove(Move.fromAlgebraic('d2d4')), isTrue);
      expect(await result, isNull);
    },
  );
}
