import 'dart:async';

import 'package:chess_master/domain/engine/native_stockfish.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:stockfish/stockfish.dart';

class _ProcessState extends ValueNotifier<StockfishState> {
  _ProcessState(super.value);
  bool get observed => hasListeners;
}

class _FakeEngine extends Fake implements Stockfish {
  _FakeEngine({
    StockfishState initialState = StockfishState.ready,
    this.answerUci = true,
    this.answerReady = true,
    this.autoDispose = true,
  }) : state = _ProcessState(initialState);

  @override
  final _ProcessState state;
  final output = StreamController<String>.broadcast(sync: true);
  final commands = <String>[];
  bool answerUci, answerReady, autoDispose;

  @override
  Stream<String> get stdout => output.stream;

  @override
  set stdin(String command) {
    if (state.value != StockfishState.ready) {
      throw StateError('Native process is not ready');
    }
    commands.add(command);
    if (command == 'uci' && answerUci) emit('uciok');
    if (command == 'isready' && answerReady) emit('readyok');
  }

  void emit(String line) => output.add(line);

  @override
  void dispose() {
    stdin = 'quit';
    if (autoDispose) scheduleMicrotask(finishDisposal);
  }

  void finishDisposal() {
    state.value = StockfishState.disposed;
  }
}

Future<void> _until(bool Function() condition) async {
  for (var attempt = 0; attempt < 200 && !condition(); attempt++) {
    await Future<void>.delayed(const Duration(milliseconds: 1));
  }
  expect(condition(), isTrue, reason: 'Expected native protocol action');
}

void main() {
  final engines = <_FakeEngine>[];
  final wrappers = <NativeStockfish>[];

  NativeStockfish wrapper(
    Stockfish Function() factory, {
    Duration readinessTimeout = const Duration(milliseconds: 200),
    Duration shutdownTimeout = const Duration(milliseconds: 50),
    Duration responseGrace = const Duration(milliseconds: 20),
  }) {
    final value = NativeStockfish.testing(
      createEngine: factory,
      readinessTimeout: readinessTimeout,
      shutdownTimeout: shutdownTimeout,
      responseGrace: responseGrace,
    );
    wrappers.add(value);
    return value;
  }

  _FakeEngine engine({
    StockfishState initialState = StockfishState.ready,
    bool answerUci = true,
    bool answerReady = true,
    bool autoDispose = true,
  }) {
    final value = _FakeEngine(
      initialState: initialState,
      answerUci: answerUci,
      answerReady: answerReady,
      autoDispose: autoDispose,
    );
    engines.add(value);
    return value;
  }

  tearDown(() async {
    for (final native in wrappers) {
      native.dispose();
    }
    for (final process in engines) {
      process.finishDisposal();
      await process.output.close();
      expect(process.state.observed, isFalse);
      process.state.dispose();
    }
    engines.clear();
    wrappers.clear();
  });

  test(
      'waits for native startup, uciok and readyok before the unchanged search',
      () async {
    final process = engine(initialState: StockfishState.starting);
    final native = wrapper(() => process);
    final result = native.getBestMove('position', depth: 24, movetime: 600);
    expect(process.commands, isEmpty);
    process.state.value = StockfishState.ready;
    await _until(() => process.commands.contains('go movetime 600'));
    expect(process.commands, [
      'uci',
      'ucinewgame',
      'isready',
      'setoption name MultiPV value 1',
      'isready',
      'position fen position',
      'go movetime 600',
    ]);
    process.emit('bestmove e2e4');
    expect(await result, 'e2e4');
  });

  test(
      'readyok cannot bypass the UCI handshake or per-search readiness barrier',
      () async {
    final process = engine(answerUci: false, answerReady: false);
    final native = wrapper(() => process);
    final result = native.getBestMove('position', depth: 23);
    await _until(() => process.commands.contains('uci'));
    process.emit('readyok');
    await Future<void>.delayed(Duration.zero);
    expect(process.commands, ['uci']);
    process.emit('uciok');
    await _until(
        () => process.commands.where((x) => x == 'isready').length == 1);
    expect(process.commands.any((x) => x.startsWith('go ')), isFalse);
    process.emit('readyok');
    await _until(
        () => process.commands.where((x) => x == 'isready').length == 2);
    expect(process.commands.any((x) => x.startsWith('go ')), isFalse);
    process.emit('readyok');
    await _until(() => process.commands.contains('go depth 23'));
    process.emit('bestmove d2d4');
    expect(await result, 'd2d4');
  });

  test('superseded searches finish null and wait for old native shutdown',
      () async {
    final first = engine(autoDispose: false), second = engine();
    var created = 0;
    final native = wrapper(() => created++ == 0 ? first : second);
    final oldResult = native.getBestMove('old', movetime: 1000);
    await _until(() => first.commands.contains('go movetime 1000'));
    final newResult = native.getBestMove('new', movetime: 1000);
    expect(await oldResult, isNull);
    expect(created, 1);
    expect(first.commands.sublist(first.commands.length - 2), ['stop', 'quit']);
    first.emit('bestmove a2a4');
    await Future<void>.delayed(Duration.zero);
    expect(second.commands, isEmpty);
    first.finishDisposal();
    await _until(() => second.commands.contains('go movetime 1000'));
    second.emit('bestmove h2h4');
    expect(await newResult, 'h2h4');
    expect(created, 2);
  });

  test('disposal while starting resolves requests and defers quit until ready',
      () async {
    final process = engine(initialState: StockfishState.starting);
    final native = wrapper(() => process);
    final result = native.getTopMoves('position', 15, 3, movetime: 1000);
    native.dispose();
    expect(await result, isEmpty);
    expect(process.commands, isEmpty);
    process.state.value = StockfishState.ready;
    await _until(() => process.commands.contains('quit'));
    expect(process.commands, ['stop', 'quit']);
  });

  test(
      'cancelled shutdown wait cannot create an unrequested replacement process',
      () async {
    final first = engine(autoDispose: false), second = engine();
    var created = 0;
    final native = wrapper(() => created++ == 0 ? first : second);
    final firstResult = native.getBestMove('first', movetime: 1000);
    await _until(() => first.commands.contains('go movetime 1000'));
    final waitingResult = native.getBestMove('second', movetime: 1000);
    native.dispose();
    expect(await firstResult, isNull);
    expect(await waitingResult, isNull);
    first.finishDisposal();
    await Future<void>.delayed(const Duration(milliseconds: 5));
    expect(created, 1);
    expect(second.commands, isEmpty);
  });

  test('an unresponsive readiness barrier is bounded and never starts a search',
      () async {
    final process = engine(answerReady: false);
    final native = wrapper(
      () => process,
      readinessTimeout: const Duration(milliseconds: 25),
    );
    expect(await native.getBestMove('position', movetime: 1000), isNull);
    expect(process.commands.any((x) => x.startsWith('go ')), isFalse);
    expect(process.commands, contains('quit'));
  });

  test(
      'missing bestmove settles after movetime plus grace and next request recovers',
      () async {
    final first = engine(), second = engine();
    var created = 0;
    final native = wrapper(() => created++ == 0 ? first : second);
    expect(await native.getBestMove('position', movetime: 15), isNull);
    expect(first.commands, contains('go movetime 15'));
    expect(first.commands, contains('quit'));
    final recovered = native.getBestMove('new', movetime: 1000);
    await _until(() => second.commands.contains('go movetime 1000'));
    second.emit('bestmove g1f3');
    expect(await recovered, 'g1f3');
  });

  test(
      'depth-only searches keep the exact depth without an artificial movetime',
      () async {
    final process = engine();
    final native = wrapper(
      () => process,
      readinessTimeout: const Duration(milliseconds: 20),
    );
    var completed = false;
    final result = native.getBestMove('position', depth: 24)
      ..then((_) => completed = true);
    await _until(() => process.commands.contains('go depth 24'));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(completed, isFalse);
    expect(process.commands.any((x) => x.startsWith('go movetime')), isFalse);
    process.emit('bestmove b1c3');
    expect(await result, 'b1c3');
  });

  test(
      'candidate replies are scoped to one search and losing mate scores stay negative',
      () async {
    final process = engine();
    var created = 0;
    final native = wrapper(() {
      created++;
      return process;
    });
    final result = native.getTopMoves('position', 15, 3, movetime: 1000);
    await _until(() => process.commands.contains('go movetime 1000'));
    expect(process.commands, contains('setoption name MultiPV value 3'));
    process.emit('info depth 12 multipv 1 score cp 42 pv e2e4 e7e5');
    process.emit('info depth 12 multipv 2 score cp -20 pv d2d4 d7d5');
    process.emit('info depth 12 multipv 3 score mate -2 pv g1f3');
    process.emit('bestmove e2e4');
    final candidates = await result;
    expect(
        candidates.map((candidate) => candidate.uci), ['e2e4', 'd2d4', 'g1f3']);
    expect(candidates.last.score, -10000);
    final next = native.getTopMoves('next', 19, 2);
    await _until(() => process.commands.contains('go depth 19'));
    process.emit('info depth 19 multipv 1 score cp 10 pv e7e5');
    process.emit('bestmove e7e5');
    expect((await next).map((candidate) => candidate.uci), ['e7e5']);
    expect(created, 1, reason: 'Completed searches reuse the idle process');
    expect(process.commands.where((command) => command == 'uci').length, 1);
  });

  test('process errors settle pending work and allow a new process', () async {
    final first = engine(), second = engine();
    var created = 0;
    final native = wrapper(() => created++ == 0 ? first : second);
    final result = native.getBestMove('old', movetime: 1000);
    await _until(() => first.commands.contains('go movetime 1000'));
    first.state.value = StockfishState.error;
    expect(await result, isNull);
    final next = native.getBestMove('new', movetime: 1000);
    await _until(() => second.commands.contains('go movetime 1000'));
    second.emit('bestmove e2e4');
    expect(await next, 'e2e4');
  });

  test('stream failures and no-legal-move replies do not strand completers',
      () async {
    final first = engine(), second = engine();
    var created = 0;
    final native = wrapper(() => created++ == 0 ? first : second);
    final result = native.getBestMove('old', movetime: 1000);
    await _until(() => first.commands.contains('go movetime 1000'));
    first.output.addError(StateError('Native output failed'));
    expect(await result, isNull);
    final next = native.getBestMove('terminal', movetime: 1000);
    await _until(() => second.commands.contains('go movetime 1000'));
    second.emit('bestmove (none)');
    expect(await next, isNull);
    final noMove = native.getBestMove('terminal', movetime: 1000);
    await _until(
        () => second.commands.where((x) => x.startsWith('go ')).length == 2);
    second.emit('bestmove 0000');
    expect(await noMove, isNull);
  });

  test(
      'stuck native shutdown does not spin up another singleton or hang callers',
      () async {
    final process = engine(autoDispose: false);
    var created = 0;
    final native = wrapper(() {
      created++;
      return process;
    });
    final old = native.getBestMove('old', movetime: 1000);
    await _until(() => process.commands.contains('go movetime 1000'));
    native.dispose();
    expect(await old, isNull);
    expect(await native.getBestMove('new', movetime: 1000), isNull);
    expect(created, 1);
  });
  testWidgets('the readiness allowance is shared across startup and UCI phases',
      (tester) async {
    final process =
        engine(initialState: StockfishState.starting, answerUci: false);
    final native = wrapper(() => process,
        readinessTimeout: const Duration(milliseconds: 100));
    var completed = false;
    final result = native.getBestMove('position', movetime: 1000)
      ..then((_) => completed = true);
    await tester.pump(const Duration(milliseconds: 60));
    process.state.value = StockfishState.ready;
    await tester.pump();
    expect(process.commands, ['uci']);
    await tester.pump(const Duration(milliseconds: 41));
    expect(completed, isTrue);
    expect(await result, isNull);
    expect(process.commands, ['uci', 'stop', 'quit']);
  });

  testWidgets('cold startup never consumes the requested native movetime',
      (tester) async {
    final process = engine(initialState: StockfishState.starting);
    final native = wrapper(() => process,
        readinessTimeout: const Duration(milliseconds: 100));
    var completed = false;
    final result = native.getBestMove('position', movetime: 100)
      ..then((_) => completed = true);
    await tester.pump(const Duration(milliseconds: 60));
    process.state.value = StockfishState.ready;
    await tester.pump();
    expect(process.commands.last, 'go movetime 100');
    await tester.pump(const Duration(milliseconds: 100));
    expect(completed, isFalse, reason: 'The watchdog starts only after go');
    process.emit('bestmove e2e4');
    await tester.pump();
    expect(await result, 'e2e4');
  });
}
