import 'package:chess_master/domain/engine/chess_engine.dart';
import 'package:chess_master/presentation/widgets/chess_board_widget.dart';
import 'package:chess_master/presentation/widgets/game_over_reveal.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  testWidgets('a real mating move is shown on the board before the result',
      (tester) async {
    final engine = ChessEngine();
    for (final move in ['f2f3', 'e7e5', 'g2g4', 'd8h4']) {
      expect(engine.makeMove(Move.fromAlgebraic(move)), isTrue);
    }
    expect(engine.status, GameStatus.checkmate);

    await tester.pumpWidget(MaterialApp(
      home: SizedBox(
        width: 400,
        height: 400,
        child: Stack(children: [
          ChessBoardWidget(
            board: engine.board,
            perspective: PieceColor.white,
            lastMove: engine.moveHistory.last,
            status: engine.status,
            showCoordinates: false,
            moveAnimationSpeed: 'off',
          ),
          const GameOverReveal(
            showFinalPosition: true,
            child: Text('checkmate result'),
          ),
        ]),
      ),
    ));

    expect(find.byKey(const ValueKey('blackqueen73')), findsOneWidget);
    expect(find.text('checkmate result'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1200));
    expect(find.text('checkmate result'), findsOneWidget);
  });

  testWidgets('the final board remains visible before the result appears',
      (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: Stack(children: [
        Text('final move'),
        GameOverReveal(
          showFinalPosition: true,
          child: Text('result'),
        ),
      ]),
    ));

    expect(find.text('final move'), findsOneWidget);
    expect(find.text('result'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1199));
    expect(find.text('result'), findsNothing);
    await tester.pump(const Duration(milliseconds: 1));
    expect(find.text('final move'), findsOneWidget);
    expect(find.text('result'), findsOneWidget);
  });

  testWidgets('non-checkmate results are immediate', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: GameOverReveal(
        showFinalPosition: false,
        child: Text('result'),
      ),
    ));
    expect(find.text('result'), findsOneWidget);
  });

  testWidgets('a new game cancels the previous reveal', (tester) async {
    await tester.pumpWidget(const MaterialApp(
      home: GameOverReveal(
        showFinalPosition: true,
        child: Text('old result'),
      ),
    ));
    await tester.pumpWidget(const MaterialApp(home: Text('new game')));
    await tester.pump(const Duration(seconds: 2));
    expect(find.text('old result'), findsNothing);
    expect(find.text('new game'), findsOneWidget);
    expect(tester.takeException(), isNull);
  });
}
