import 'dart:async';

class NativeLeela {
  static final NativeLeela _instance = NativeLeela._internal();
  factory NativeLeela() => _instance;
  NativeLeela._internal();

  Completer<String?>? _moveCompleter;

  Future<void> init() async {
    // No-op fallback while native LC0 dependency is unavailable on Android.
  }

  Future<String?> getBestMove(String fen, int nodes) async {
    return null;
  }

  void stop() {
    if (_moveCompleter != null && !_moveCompleter!.isCompleted) {
      _moveCompleter!.complete(null);
      _moveCompleter = null;
    }
  }

  void dispose() {
    _moveCompleter = null;
  }
}
