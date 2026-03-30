import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'candidate_model.dart';

@JS('ChessEngineService')
extension type _JSEngineService._(JSObject _) {
  external void initEngine(JSString mode, JSString difficulty);
  external JSPromise<JSAny?> getBestMove(JSString fen, [JSNumber? movetime]);
  external JSBoolean validateMove(
      JSString fen, JSString from, JSString to, JSString? promotion);
  external JSArray<JSString> getLegalMoves(JSString fen, JSString square);
  external JSObject getGameState(JSString fen);
  external JSString getActiveEngine();
  external void dispose();
}

/// Get the ChessEngineService from window
_JSEngineService? _getService() {
  try {
    final svc = (globalContext['ChessEngineService'] as JSObject?);
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

/// Get best move (or move+candidates) from JS
Future<Map<String, dynamic>?> jsEngineGetBestMove(String fen,
    {int? movetime}) async {
  final svc = _getService();
  if (svc == null) return null;

  try {
    final result = await svc.getBestMove(fen.toJS, movetime?.toJS).toDart;
    if (result == null) return null;

    if (result.isA<JSString>()) {
      return {'move': (result as JSString).toDart};
    }

    if (result.isA<JSObject>()) {
      final obj = result as JSObject;
      final move = (obj['move'] as JSString?)?.toDart;
      final candidatesRaw = obj['candidates'] as JSArray<JSObject>?;

      final List<MoveCandidate> candidates = [];
      if (candidatesRaw != null) {
        final dartArray = candidatesRaw.toDart;
        for (var i = 0; i < dartArray.length; i++) {
          final c = dartArray[i];
          final uci = (c['uci'] as JSString?)?.toDart;
          final score = (c['score'] as JSNumber?)?.toDartInt;
          if (uci != null && score != null) {
            candidates.add(MoveCandidate(uci: uci, score: score));
          }
        }
      }
      return {'move': move, 'candidates': candidates};
    }
  } catch (e) {
    print('[JSBridge] getBestMove error: $e');
  }
  return null;
}

/// Get top candidate moves from JS
Future<List<MoveCandidate>> jsEngineGetTopMoves(
    String fen, int depth, int count,
    {int? movetime}) async {
  final res = await jsEngineGetBestMove(fen, movetime: movetime);
  if (res?['candidates'] != null) {
    return List<MoveCandidate>.from(res!['candidates'] as List);
  }
  return [];
}

/// Validate a move using the JS engine (synchronous)
bool jsEngineValidateMove(
    String fen, String from, String to, String? promotion) {
  final svc = _getService();
  if (svc == null) return false;
  return svc.validateMove(fen.toJS, from.toJS, to.toJS, promotion?.toJS).toDart;
}

/// Get legal moves from a square
List<String> jsEngineGetLegalMoves(String fen, String square) {
  final svc = _getService();
  if (svc == null) return [];
  final result = svc.getLegalMoves(fen.toJS, square.toJS);
  return result.toDart.map((e) => (e as JSString).toDart).toList();
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
