import 'dart:async';
import 'package:leela_chess_zero/lc0.dart';

class NativeLeela {
  static final NativeLeela _instance = NativeLeela._internal();
  factory NativeLeela() => _instance;
  NativeLeela._internal();

  Lc0? _engine;
  StreamSubscription? _stdoutSub;
  Completer<String?>? _moveCompleter;

  Future<void> init() async {
    if (_engine != null) return;
    try {
      // leela_chess_zero might need weights, but we try without it first
      _engine = await lc0Async();
      _stdoutSub = _engine!.stdout.listen((line) {
        if (line.startsWith('bestmove')) {
          final parts = line.split(' ');
          if (parts.length >= 2) {
            _moveCompleter?.complete(parts[1]);
            _moveCompleter = null;
          }
        }
      });

      _engine!.stdin = 'uci';
      _engine!.stdin = 'isready';
    } catch (e) {
      print('[NativeLeela] Init error: \$e');
    }
  }

  Future<String?> getBestMove(String fen, int nodes) async {
    if (_engine == null) await init();
    if (_engine == null) return null;

    if (_moveCompleter != null && !_moveCompleter!.isCompleted) {
      _engine!.stdin = 'stop';
      _moveCompleter!.complete(null);
    }

    _moveCompleter = Completer<String?>();
    _engine!.stdin = 'position fen \$fen';
    // LC0 uses nodes or time better than depth, but we can pass depth too.
    _engine!.stdin = 'go nodes \$nodes';

    print('[NativeLeela] Searching \$fen for nodes \$nodes');
    return _moveCompleter!.future;
  }

  void stop() {
    _engine?.stdin = 'stop';
    if (_moveCompleter != null && !_moveCompleter!.isCompleted) {
      _moveCompleter!.complete(null);
      _moveCompleter = null;
    }
  }

  void dispose() {
    print('[NativeLeela] Disposing engine...');
    _stdoutSub?.cancel();
    _engine?.dispose();
    _engine = null;
    _stdoutSub = null;
    _moveCompleter = null;
  }
}
