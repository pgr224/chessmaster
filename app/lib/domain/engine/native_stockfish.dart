import 'dart:async';

import 'package:flutter/foundation.dart';
import 'package:stockfish/stockfish.dart';

import '../../core/services/logging_service.dart';
import 'candidate_model.dart';

/// Owns one native process, including its asynchronous startup and shutdown.
class NativeStockfish {
  static final NativeStockfish _instance = NativeStockfish._internal();
  factory NativeStockfish() => _instance;
  NativeStockfish._internal()
      : _createEngine = Stockfish.new,
        _readinessTimeout = const Duration(seconds: 5),
        _shutdownTimeout = const Duration(seconds: 2),
        _responseGrace = const Duration(milliseconds: 250);

  @visibleForTesting
  NativeStockfish.testing({
    required Stockfish Function() createEngine,
    Duration readinessTimeout = const Duration(seconds: 5),
    Duration shutdownTimeout = const Duration(seconds: 2),
    Duration responseGrace = const Duration(milliseconds: 250),
  })  : _createEngine = createEngine,
        _readinessTimeout = readinessTimeout,
        _shutdownTimeout = shutdownTimeout,
        _responseGrace = responseGrace;

  final Stockfish Function() _createEngine;
  final Duration _readinessTimeout;
  final Duration _shutdownTimeout;
  final Duration _responseGrace;
  _NativeSession? _session;
  _NativeRequest? _pending;
  int _epoch = 0;

  Future<void> init() async {
    final epoch = _epoch;
    await _readySession(() => epoch == _epoch).timeout(
      _readinessTimeout,
      onTimeout: () {
        if (epoch == _epoch && _session != null) _retire(_session!);
        return null;
      },
    );
  }

  Future<_NativeSession?> _readySession(bool Function() isCurrent) async {
    if (!isCurrent()) return null;
    var session = _session;
    if (session != null && session.closing) {
      // Stockfish.dispose only writes quit; its singleton is released later.
      final closed = await session.closed.future.timeout(
        _shutdownTimeout,
        onTimeout: () => false,
      );
      if (!closed) return null;
      session = _session;
    }
    if (!isCurrent()) return null;
    if (session == null) {
      try {
        session = _NativeSession(_createEngine());
        _session = session;
        final current = session;
        current.stateListener = () => _onStateChanged(current);
        current.engine.state.addListener(current.stateListener);
        current.output = current.engine.stdout.listen(
          (line) => _onLine(current, line),
          onError: (Object error) => _failSession(current),
          onDone: () => _failSession(current),
        );
        _onStateChanged(current);
        current.prepared = _prepare(current);
      } catch (error) {
        LoggingService.error('[NativeStockfish] Startup failed', error);
        return null;
      }
    }
    final ready = await session.prepared;
    return ready && !session.closing && identical(_session, session)
        ? session
        : null;
  }

  Future<bool> _prepare(_NativeSession session) async {
    try {
      final ready = await session.processReady.future.timeout(
        _readinessTimeout,
        onTimeout: () => false,
      );
      if (!ready || session.closing) return false;
      session.uciAck = Completer<bool>();
      session.engine.stdin = 'uci';
      if (!await session.uciAck!.future.timeout(
        _readinessTimeout,
        onTimeout: () => false,
      )) {
        return false;
      }
      if (session.closing) return false;
      session.engine.stdin = 'ucinewgame';
      return await _waitForReady(session);
    } catch (error) {
      LoggingService.error('[NativeStockfish] Initialization failed', error);
      return false;
    } finally {
      if (!session.protocolReady) _retire(session);
    }
  }

  Future<bool> _waitForReady(_NativeSession session) async {
    if (session.closing) return false;
    session.readyAck = Completer<bool>();
    session.engine.stdin = 'isready';
    final ready = await session.readyAck!.future.timeout(
      _readinessTimeout,
      onTimeout: () => false,
    );
    session.protocolReady = ready && !session.closing;
    return session.protocolReady;
  }

  void _onStateChanged(_NativeSession session) {
    switch (session.engine.state.value) {
      case StockfishState.starting:
        break;
      case StockfishState.ready:
        _complete(session.processReady, true);
        if (session.closing) _quit(session);
        break;
      case StockfishState.disposed:
      case StockfishState.error:
        _complete(session.processReady, false);
        _complete(session.uciAck, false);
        _complete(session.readyAck, false);
        _complete(session.closed, true);
        session.engine.state.removeListener(session.stateListener);
        unawaited(session.output?.cancel());
        if (identical(_session, session)) _session = null;
        if (identical(_pending?.session, session)) _finish(_pending!, null);
        break;
    }
  }

  void _onLine(_NativeSession session, String output) {
    if (session.closing || !identical(_session, session)) return;
    final line = output.trim();
    if (line == 'uciok') {
      _complete(session.uciAck, true);
      return;
    }
    if (line == 'readyok') {
      _complete(session.readyAck, true);
      return;
    }
    final request = _pending;
    if (request == null ||
        !request.started ||
        !identical(request.session, session)) {
      return;
    }
    if (line.startsWith('bestmove ')) {
      final move = line.split(RegExp(r'\s+'))[1];
      final candidates = request.candidates.values.toList()
        ..sort((a, b) => b.score.compareTo(a.score));
      _finish(
          request,
          _NativeResult(
            move == '(none)' || move == '0000' ? null : move,
            candidates,
          ));
    } else if (line.startsWith('info ') && line.contains(' multipv ')) {
      _parseCandidate(request, line);
    }
  }

  void _parseCandidate(_NativeRequest request, String line) {
    final parts = line.split(RegExp(r'\s+'));
    int? multipv, score;
    String? move;
    for (var i = 0; i < parts.length; i++) {
      if (parts[i] == 'multipv' && i + 1 < parts.length) {
        multipv = int.tryParse(parts[i + 1]);
      } else if (parts[i] == 'score' && i + 2 < parts.length) {
        final value = int.tryParse(parts[i + 2]);
        if (value != null) {
          score = parts[i + 1] == 'mate' ? value.sign * 10000 : value;
        }
      } else if (parts[i] == 'pv' && i + 1 < parts.length) {
        move = parts[i + 1];
      }
    }
    if (multipv != null && score != null && move != null) {
      request.candidates[multipv] = MoveCandidate(uci: move, score: score);
    }
  }

  Future<String?> getBestMove(String fen, {int? depth, int? movetime}) async {
    final result = await _search(fen, depth ?? 15, 1, movetime);
    return result?.move;
  }

  Future<List<MoveCandidate>> getTopMoves(String fen, int depth, int count,
      {int? movetime}) async {
    final result = await _search(fen, depth, count, movetime);
    return result?.candidates ?? [];
  }

  Future<_NativeResult?> _search(
    String fen,
    int depth,
    int count,
    int? movetime,
  ) {
    if (_pending != null) stop();
    final request = _NativeRequest(fen, depth, count, movetime);
    _pending = request;
    unawaited(_run(request));
    return request.result.future;
  }

  Future<void> _run(_NativeRequest request) async {
    _NativeSession? session;
    try {
      // One shared readiness allowance covers shutdown, process startup, UCI
      // initialization and the search barrier; it is not added per stage.
      session = await _prepareSearch(request).timeout(
        _readinessTimeout,
        onTimeout: () => null,
      );
      if (!identical(_pending, request)) return;
      if (session == null) {
        _finish(request, null);
        if (_session != null) _retire(_session!);
        return;
      }
      session.engine.stdin = 'position fen ${request.fen}';
      request.started = true;
      // This detects a missing reply after the requested movetime; it does not
      // shorten the search or replace a depth-only search with a time limit.
      if (request.movetime != null) {
        request.watchdog = Timer(
          Duration(milliseconds: request.movetime!) + _responseGrace,
          () {
            if (!identical(_pending, request)) return;
            _finish(request, null);
            _retire(session!);
          },
        );
      }
      session.engine.stdin = request.movetime != null
          ? 'go movetime ${request.movetime}'
          : 'go depth ${request.depth}';
    } catch (error) {
      if (identical(_pending, request)) {
        LoggingService.error('[NativeStockfish] Search failed', error);
        _finish(request, null);
      }
      if (session != null) _retire(session);
    }
  }

  Future<_NativeSession?> _prepareSearch(_NativeRequest request) async {
    final session = await _readySession(() => identical(_pending, request));
    if (!identical(_pending, request) || session == null) return null;
    request.session = session;
    session.engine.stdin = 'setoption name MultiPV value ${request.count}';
    final ready = await _waitForReady(session);
    return ready && identical(_pending, request) && !session.closing
        ? session
        : null;
  }

  void _finish(_NativeRequest request, _NativeResult? result) {
    request.watchdog?.cancel();
    if (identical(_pending, request)) _pending = null;
    if (!request.result.isCompleted) request.result.complete(result);
  }

  void _failSession(_NativeSession session) {
    if (identical(_pending?.session, session)) _finish(_pending!, null);
    _complete(session.processReady, false);
    _complete(session.uciAck, false);
    _complete(session.readyAck, false);
    _retire(session);
  }

  void _retire(_NativeSession session) {
    if (session.closing) return;
    session.closing = true;
    _complete(session.processReady, false);
    _complete(session.uciAck, false);
    _complete(session.readyAck, false);
    if (session.engine.state.value == StockfishState.ready) _quit(session);
    // Starting engines cannot accept quit. The state listener sends it as
    // soon as native startup completes, and retains ownership until shutdown.
  }

  void _quit(_NativeSession session) {
    if (session.quitSent) return;
    session.quitSent = true;
    try {
      session.engine.stdin = 'stop';
      session.engine.dispose();
    } catch (error) {
      LoggingService.error('[NativeStockfish] Shutdown failed', error);
    }
  }

  void stop() {
    _epoch++;
    if (_pending != null) _finish(_pending!, null);
    if (_session != null) _retire(_session!);
  }

  void dispose() => stop();
}

void _complete(Completer<bool>? completer, bool value) {
  if (completer != null && !completer.isCompleted) completer.complete(value);
}

class _NativeSession {
  _NativeSession(this.engine);
  final Stockfish engine;
  final processReady = Completer<bool>();
  final closed = Completer<bool>();
  Completer<bool>? uciAck, readyAck;
  StreamSubscription<String>? output;
  late VoidCallback stateListener;
  late Future<bool> prepared;
  bool closing = false, quitSent = false, protocolReady = false;
}

class _NativeRequest {
  _NativeRequest(this.fen, this.depth, this.count, this.movetime);
  final String fen;
  final int depth, count;
  final int? movetime;
  final result = Completer<_NativeResult?>();
  final candidates = <int, MoveCandidate>{};
  _NativeSession? session;
  Timer? watchdog;
  bool started = false;
}

class _NativeResult {
  _NativeResult(this.move, this.candidates);
  final String? move;
  final List<MoveCandidate> candidates;
}
