/// JS Engine Bridge — Web-only interop with window.ChessEngineService
/// This file uses dart:js_interop to call the JavaScript engine service
/// that runs Sunfish/Stockfish/ChessLogic in Web Workers.

import 'dart:js_interop';
import 'dart:js_interop_unsafe';

/// JS interop bindings for window.ChessEngineService
@JS('ChessEngineService')
extension type _JSEngineService._(JSObject _) {
  external void initEngine(JSString mode, JSString difficulty);
  external JSPromise<JSString?> getBestMove(JSString fen);
  external JSBoolean validateMove(JSString fen, JSString from, JSString to, JSString? promotion);
  external JSArray<JSString> getLegalMoves(JSString fen, JSString square);
  external JSObject getGameState(JSString fen);
  external JSString getActiveEngine();
  external void dispose();
}

/// Get the ChessEngineService from window
_JSEngineService? _getService() {
  try {
    final svc = globalContext['ChessEngineService'];
    if (svc == null || svc.isUndefinedOrNull) return null;
    return svc as _JSEngineService;
  } catch (_) {
    return null;
  }
}

/// Initialize the JS engine for the given mode and difficulty
void jsEngineInit(String mode, String difficulty) {
  final svc = _getService();
  if (svc == null) {
    print('[JSBridge] ChessEngineService not available');
    return;
  }
  svc.initEngine(mode.toJS, difficulty.toJS);
}

/// Get best move from the JS engine (async, runs in Web Worker)
Future<String?> jsEngineGetBestMove(String fen) async {
  final svc = _getService();
  if (svc == null) return null;
  
  try {
    final result = await svc.getBestMove(fen.toJS).toDart;
    return result?.toDart;
  } catch (e) {
    print('[JSBridge] getBestMove error: $e');
    return null;
  }
}

/// Validate a move using the JS engine (synchronous)
bool jsEngineValidateMove(String fen, String from, String to, String? promotion) {
  final svc = _getService();
  if (svc == null) return false;
  return svc.validateMove(fen.toJS, from.toJS, to.toJS, promotion?.toJS).toDart;
}

/// Get legal moves from a square
List<String> jsEngineGetLegalMoves(String fen, String square) {
  final svc = _getService();
  if (svc == null) return [];
  final result = svc.getLegalMoves(fen.toJS, square.toJS);
  return result.toDart.map((e) => e.toDart).toList();
}

/// Get the currently active engine name
String jsEngineGetActiveEngine() {
  final svc = _getService();
  if (svc == null) return 'none';
  return svc.getActiveEngine().toDart;
}

/// Dispose all JS engine resources
void jsEngineDispose() {
  final svc = _getService();
  svc?.dispose();
}
