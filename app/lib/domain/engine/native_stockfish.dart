import 'dart:async';
import 'package:stockfish/stockfish.dart';
import 'candidate_model.dart';
import '../../core/services/logging_service.dart';

class NativeStockfish {
  static final NativeStockfish _instance = NativeStockfish._internal();
  factory NativeStockfish() => _instance;
  NativeStockfish._internal();

  Stockfish? _engine;
  StreamSubscription? _stdoutSub;
  Completer<String?>? _moveCompleter;
  Completer<List<MoveCandidate>>? _candidatesCompleter;
  final Map<int, MoveCandidate> _currentCandidates = {};

  void init() {
    if (_engine != null) return;
    _engine = Stockfish();
    _stdoutSub = _engine!.stdout.listen((line) {
      if (line.startsWith('bestmove')) {
        final parts = line.split(' ');
        if (parts.length >= 2) {
          final bestMove = parts[1];
          _moveCompleter?.complete(bestMove);
          _moveCompleter = null;

          if (_candidatesCompleter != null) {
            final candidates = _currentCandidates.values.toList();
            candidates.sort((a, b) => b.score.compareTo(a.score));
            _candidatesCompleter?.complete(candidates);
            _candidatesCompleter = null;
          }
        }
      } else if (line.startsWith('info depth') && line.contains('multipv')) {
        _parseInfoLine(line);
      } else if (line == 'readyok') {
        LoggingService.info('[NativeStockfish] Engine is ready');
      }
    });

    _engine!.stdin = 'uci';
    _engine!.stdin = 'isready';
    _engine!.stdin = 'ucinewgame';
  }

  void _parseInfoLine(String line) {
    try {
      final parts = line.split(' ');
      int? multipv;
      int? score;
      String? move;

      for (int i = 0; i < parts.length; i++) {
        if (parts[i] == 'multipv' && i + 1 < parts.length) {
          multipv = int.tryParse(parts[i + 1]);
        } else if (parts[i] == 'score' && i + 2 < parts.length) {
          if (parts[i + 1] == 'cp') {
            score = int.tryParse(parts[i + 2]);
          } else if (parts[i + 1] == 'mate') {
            score = 10000;
          }
        } else if (parts[i] == 'pv' && i + 1 < parts.length) {
          move = parts[i + 1];
        }
      }

      if (multipv != null && score != null && move != null) {
        _currentCandidates[multipv] = MoveCandidate(uci: move, score: score);
      }
    } catch (_) {}
  }

  Future<String?> getBestMove(String fen, {int? depth, int? movetime}) async {
    if (_engine == null) init();
    stop();
    _moveCompleter = Completer<String?>();
    _engine!.stdin = 'setoption name MultiPV value 1';
    _engine!.stdin = 'isready';
    _engine!.stdin = 'position fen $fen';

    if (movetime != null) {
      _engine!.stdin = 'go movetime $movetime';
    } else {
      _engine!.stdin = 'go depth ${depth ?? 15}';
    }
    return _moveCompleter!.future;
  }

  Future<List<MoveCandidate>> getTopMoves(String fen, int depth, int count,
      {int? movetime}) async {
    if (_engine == null) init();
    stop();
    _candidatesCompleter = Completer<List<MoveCandidate>>();
    _currentCandidates.clear();
    _engine!.stdin = 'setoption name MultiPV value $count';
    _engine!.stdin = 'isready';
    _engine!.stdin = 'position fen $fen';

    if (movetime != null) {
      _engine!.stdin = 'go movetime $movetime';
    } else {
      _engine!.stdin = 'go depth $depth';
    }
    return _candidatesCompleter!.future;
  }

  void stop() {
    _engine?.stdin = 'stop';
    if (_moveCompleter != null && !_moveCompleter!.isCompleted) {
      _moveCompleter!.complete(null);
      _moveCompleter = null;
    }
    if (_candidatesCompleter != null && !_candidatesCompleter!.isCompleted) {
      _candidatesCompleter!.complete([]);
      _candidatesCompleter = null;
    }
  }

  void dispose() {
    _stdoutSub?.cancel();
    _engine?.dispose();
    _engine = null;
    _stdoutSub = null;
    _moveCompleter = null;
    _candidatesCompleter = null;
  }
}
