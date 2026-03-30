import 'dart:async';
import 'package:stockfish/stockfish.dart';

class NativeStockfish {
  static final NativeStockfish _instance = NativeStockfish._internal();
  factory NativeStockfish() => _instance;
  NativeStockfish._internal();

  Stockfish? _engine;
  StreamSubscription? _stdoutSub;
  Completer<String?>? _moveCompleter;

  void init() {
    if (_engine != null) return;
    _engine = Stockfish();
    _stdoutSub = _engine!.stdout.listen((line) {
      if (line.startsWith('bestmove')) {
        final parts = line.split(' ');
        if (parts.length >= 2) {
          _moveCompleter?.complete(parts[1]);
          _moveCompleter = null;
        }
      }
    });

    _engine!.stdin.add('uci');
    _engine!.stdin.add('isready');
  }

  Future<String?> getBestMove(String fen, int depth) async {
    if (_engine == null) init();
    
    // Stop any current search
    if (_moveCompleter != null && !_moveCompleter!.isCompleted) {
      _engine!.stdin.add('stop');
      _moveCompleter!.complete(null);
    }
    
    _moveCompleter = Completer<String?>();
    _engine!.stdin.add('position fen $fen');
    _engine!.stdin.add('go depth $depth');
    
    print('[NativeStockfish] Searching $fen at depth $depth');
    return _moveCompleter!.future;
  }

  void stop() {
    _engine?.stdin.add('stop');
    if (_moveCompleter != null && !_moveCompleter!.isCompleted) {
       _moveCompleter!.complete(null);
       _moveCompleter = null;
    }
  }

  void dispose() {
    print('[NativeStockfish] Disposing engine...');
    _stdoutSub?.cancel();
    _engine?.dispose();
    _engine = null;
    _stdoutSub = null;
    _moveCompleter = null;
  }
}
