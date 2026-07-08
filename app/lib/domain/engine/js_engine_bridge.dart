import 'dart:js_interop';
import 'dart:js_interop_unsafe';
import 'candidate_model.dart';
import '../../core/services/logging_service.dart';

@JS('ChessEngineService')
extension type _JSEngineService._(JSObject _) {
  external void initEngine(JSString mode, JSString difficulty);
  external JSPromise<JSAny?> getBestMove(JSString fen, [JSNumber? movetime]);
  external JSBoolean validateMove(
      JSString fen, JSString from, JSString to, JSString? promotion);
  external JSArray<JSString> getLegalMoves(JSString fen, JSString square);
  external JSObject getGameState(JSString fen);
  external JSString getActiveEngine();
  external JSPromise<JSObject> analyzeStyle(JSString fen, JSArray<JSString> recentMoves);
  external void dispose();
}

/// Analyze player style from position and recent moves
Future<Map<String, dynamic>> jsEngineAnalyzeStyle(String fen, List<String> recentMoves) async {
  final svc = _getService();
  if (svc == null) {
    // Fallback heuristic
    bool aggressive = recentMoves.any((m) => m.contains('+') || m.contains('#'));
    return {
      'style': aggressive ? 'aggressive' : 'positional',
      'confidence': 0.5,
      'suggested_personality': aggressive ? 'aggressive' : 'defensive',
    };
  }

  try {
    final movesArray = recentMoves.map((m) => m.toJS).toList().toJS;
    final result = await svc.analyzeStyle(fen.toJS, movesArray).toDart;
    if (result == null) return {'style': 'unknown', 'confidence': 0.0};

    final obj = result as JSObject;
    final style = (obj['style'] as JSString?)?.toDart ?? 'positional';
    final confidence = (obj['confidence'] as JSNumber?)?.toDartDouble ?? 0.5;
    final personality = (obj['suggested_personality'] as JSString?)?.toDart ?? 'defensive';

    return {
      'style': style,
      'confidence': confidence,
      'suggested_personality': personality,
    };
  } catch (e) {
    LoggingService.error('[JSBridge] analyzeStyle error', e);
    return {'style': 'unknown', 'confidence': 0.0};
  }
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
void jsEngineInit(String mode, String difficulty, {int? difficultyLevel}) {
  final svc = _getService();
  if (svc == null) {
    LoggingService.warn('[JSBridge] ChessEngineService not available');
    return;
  }
  // The JS engine might not support difficultyLevel yet, so we just pass the original strings
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
      final candidatesAny = obj['candidates'];

      final List<MoveCandidate> candidates = [];
      if (candidatesAny != null && candidatesAny.isA<JSArray>()) {
        final dartArray =
            (candidatesAny as JSArray<JSAny?>).toDart;
        for (var i = 0; i < dartArray.length; i++) {
          final c = dartArray[i];
          if (c == null || !c.isA<JSObject>()) continue;
          final cObj = c as JSObject;
          final uci = (cObj['uci'] as JSString?)?.toDart;
          final score = (cObj['score'] as JSNumber?)?.toDartInt;
          if (uci != null && score != null) {
            candidates.add(MoveCandidate(uci: uci, score: score));
          }
        }
      }
      return {'move': move, 'candidates': candidates};
    }
  } catch (e) {
    LoggingService.error('[JSBridge] getBestMove error', e);
  }
  return null;
}

/// Get top candidate moves from JS
Future<List<MoveCandidate>> jsEngineGetTopMoves(
    String fen, int depth, int count,
    {int? movetime}) async {
  final res = await jsEngineGetBestMove(fen, movetime: movetime);
  final raw = res?['candidates'];
  if (raw is List<MoveCandidate>) {
    return raw;
  }
  if (raw is List) {
    return raw
        .map<MoveCandidate?>((c) {
          if (c is MoveCandidate) return c;
          if (c is Map) {
            final uciRaw = c['uci'];
            final scoreRaw = c['score'];
            if (uciRaw is String && scoreRaw is num) {
              return MoveCandidate(uci: uciRaw, score: scoreRaw.toInt());
            }
          }
          return null;
        })
        .whereType<MoveCandidate>()
        .toList(growable: false);
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
