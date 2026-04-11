import 'dart:async';

import 'package:bloc_test/bloc_test.dart';
import 'package:chess_master/data/models/game_config.dart';
import 'package:chess_master/domain/engine/chess_engine.dart';
import 'package:chess_master/presentation/blocs/game/game_bloc.dart';
import 'package:chess_master/presentation/blocs/multiplayer/multiplayer_bloc.dart';
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class MockGameBloc extends MockBloc<GameEvent, GameState> implements GameBloc {}

class MockMultiplayerBloc extends MockBloc<MultiplayerEvent, MultiplayerState>
    implements MultiplayerBloc {}

class FakeGameEvent extends Fake implements GameEvent {}

class FakeMultiplayerEvent extends Fake implements MultiplayerEvent {}

class UndoSyncHarness extends StatelessWidget {
  const UndoSyncHarness({super.key});

  @override
  Widget build(BuildContext context) {
    return MultiBlocListener(
      listeners: [
        BlocListener<MultiplayerBloc, MultiplayerState>(
          listenWhen: (prev, current) =>
              current.opponentUndoCount > prev.opponentUndoCount,
          listener: (context, state) {
            context
                .read<GameBloc>()
                .add(const GameUndoEvent(fromOpponent: true));
          },
        ),
        BlocListener<GameBloc, GameState>(
          listenWhen: (prev, current) =>
              prev.moveHistory.length > current.moveHistory.length &&
              current.mode == GameMode.multiplayer &&
              current.isPlayerTurn,
          listener: (context, state) {
            context.read<MultiplayerBloc>().add(MpUndoEvent());
          },
        ),
        BlocListener<MultiplayerBloc, MultiplayerState>(
          listenWhen: (prev, current) =>
              (prev.lastMoveFrom != current.lastMoveFrom ||
                  prev.lastMoveTo != current.lastMoveTo) &&
              current.lastMoveFrom != null,
          listener: (context, state) {
            context.read<GameBloc>().add(GameMakeMoveEvent(
                  Square.fromString(state.lastMoveFrom!),
                  Square.fromString(state.lastMoveTo!),
                  promotion: state.lastMovePromotion != null
                      ? PieceType.values.byName(state.lastMovePromotion!)
                      : null,
                ));
          },
        ),
        BlocListener<GameBloc, GameState>(
          listenWhen: (prev, current) =>
              prev.moveHistory.length < current.moveHistory.length &&
              current.currentTurn != current.playerColor,
          listener: (context, state) {
            if (state.moveHistory.isNotEmpty &&
                state.mode == GameMode.multiplayer) {
              final lastMove = state.moveHistory.last;
              context.read<MultiplayerBloc>().add(MpMakeMoveEvent(
                    lastMove.from.toString(),
                    lastMove.to.toString(),
                    promotion: lastMove.promotion?.name,
                  ));
            }
          },
        ),
      ],
      child: const SizedBox.shrink(),
    );
  }
}

GameState _state({
  required List<Move> moves,
  required PieceColor turn,
  required int xp,
  GameMode mode = GameMode.multiplayer,
  PieceColor playerColor = PieceColor.white,
}) {
  return GameState(
    board: List.generate(8, (_) => List<ChessPiece?>.filled(8, null)),
    currentTurn: turn,
    moveHistory: moves,
    mode: mode,
    playerColor: playerColor,
    xpGained: xp,
  );
}

MultiplayerState _mpState({
  int undoCount = 0,
  String? lastMoveFrom,
  String? lastMoveTo,
  String? lastMovePromotion,
}) {
  return MultiplayerState(
    status: MultiplayerStatus.inGame,
    opponentUndoCount: undoCount,
    lastMoveFrom: lastMoveFrom,
    lastMoveTo: lastMoveTo,
    lastMovePromotion: lastMovePromotion,
  );
}

void main() {
  setUpAll(() {
    registerFallbackValue(FakeGameEvent());
    registerFallbackValue(FakeMultiplayerEvent());
  });

  testWidgets('local undo path: penalty state and single undo send',
      (tester) async {
    final gameBloc = MockGameBloc();
    final multiplayerBloc = MockMultiplayerBloc();

    final before = _state(
      moves: [Move.fromAlgebraic('e2e4')],
      turn: PieceColor.black,
      xp: 0,
    );
    final afterLocalUndo = _state(
      moves: const [],
      turn: PieceColor.white,
      xp: -25,
    );

    when(() => gameBloc.state).thenReturn(afterLocalUndo);
    when(() => multiplayerBloc.state).thenReturn(_mpState());
    whenListen<GameState>(
      gameBloc,
      Stream<GameState>.fromIterable([afterLocalUndo]),
      initialState: before,
    );
    whenListen<MultiplayerState>(
      multiplayerBloc,
      const Stream<MultiplayerState>.empty(),
      initialState: _mpState(),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<GameBloc>.value(value: gameBloc),
            BlocProvider<MultiplayerBloc>.value(value: multiplayerBloc),
          ],
          child: const UndoSyncHarness(),
        ),
      ),
    );
    await tester.pump();

    expect(afterLocalUndo.xpGained, -25);
    verify(() => multiplayerBloc.add(any(that: isA<MpUndoEvent>()))).called(1);
    verifyNever(
      () => gameBloc.add(any(that: isA<GameUndoEvent>())),
    );
  });

  testWidgets('opponent undo path: no penalty signal and no re-send',
      (tester) async {
    final gameBloc = MockGameBloc();
    final multiplayerBloc = MockMultiplayerBloc();

    final before = _state(
      moves: [Move.fromAlgebraic('e2e4')],
      turn: PieceColor.black,
      xp: 0,
    );
    final afterOpponentUndo = _state(
      moves: const [],
      turn: PieceColor.black,
      xp: 0,
    );

    when(() => gameBloc.state).thenReturn(afterOpponentUndo);
    when(() => multiplayerBloc.state).thenReturn(_mpState(undoCount: 1));
    whenListen<GameState>(
      gameBloc,
      Stream<GameState>.fromIterable([afterOpponentUndo]),
      initialState: before,
    );
    whenListen<MultiplayerState>(
      multiplayerBloc,
      Stream<MultiplayerState>.fromIterable([_mpState(undoCount: 1)]),
      initialState: _mpState(undoCount: 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<GameBloc>.value(value: gameBloc),
            BlocProvider<MultiplayerBloc>.value(value: multiplayerBloc),
          ],
          child: const UndoSyncHarness(),
        ),
      ),
    );
    await tester.pump();

    expect(afterOpponentUndo.xpGained, 0);
    verify(
      () => gameBloc.add(
        any(
          that: isA<GameUndoEvent>().having(
            (e) => e.fromOpponent,
            'fromOpponent',
            true,
          ),
        ),
      ),
    ).called(1);
    verifyNever(() => multiplayerBloc.add(any(that: isA<MpUndoEvent>())));
  });

  testWidgets(
      'after undo, next opponent and player moves are still propagated',
      (tester) async {
    final gameBloc = MockGameBloc();
    final multiplayerBloc = MockMultiplayerBloc();

    final before = _state(
      moves: [Move.fromAlgebraic('e2e4')],
      turn: PieceColor.black,
      xp: 0,
    );
    final afterOpponentUndo = _state(
      moves: const [],
      turn: PieceColor.black,
      xp: 0,
    );
    final afterPlayerMove = _state(
      moves: [Move.fromAlgebraic('d2d4')],
      turn: PieceColor.black,
      xp: 0,
    );

    when(() => gameBloc.state).thenReturn(afterPlayerMove);
    when(() => multiplayerBloc.state).thenReturn(
      _mpState(undoCount: 1, lastMoveFrom: 'e7', lastMoveTo: 'e5'),
    );
    whenListen<GameState>(
      gameBloc,
      Stream<GameState>.fromIterable([afterOpponentUndo, afterPlayerMove]),
      initialState: before,
    );
    whenListen<MultiplayerState>(
      multiplayerBloc,
      Stream<MultiplayerState>.fromIterable([
        _mpState(undoCount: 1),
        _mpState(undoCount: 1, lastMoveFrom: 'e7', lastMoveTo: 'e5'),
      ]),
      initialState: _mpState(undoCount: 0),
    );

    await tester.pumpWidget(
      MaterialApp(
        home: MultiBlocProvider(
          providers: [
            BlocProvider<GameBloc>.value(value: gameBloc),
            BlocProvider<MultiplayerBloc>.value(value: multiplayerBloc),
          ],
          child: const UndoSyncHarness(),
        ),
      ),
    );
    await tester.pump();

    verify(
      () => gameBloc.add(
        any(
          that: isA<GameMakeMoveEvent>()
              .having((e) => e.from.toString(), 'from', 'e7')
              .having((e) => e.to.toString(), 'to', 'e5'),
        ),
      ),
    ).called(1);

    verify(
      () => multiplayerBloc.add(
        any(
          that: isA<MpMakeMoveEvent>()
              .having((e) => e.from, 'from', 'd2')
              .having((e) => e.to, 'to', 'd4'),
        ),
      ),
    ).called(1);

    verifyNever(() => multiplayerBloc.add(any(that: isA<MpUndoEvent>())));
  });
}
