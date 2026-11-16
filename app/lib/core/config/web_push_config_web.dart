import 'dart:js_interop';

@JS('ChessPush')
external JSObject? get _push;

@JS('ChessPush.configure')
external void _configure(JSString apiUrl);

@JS('ChessPush.sync')
external JSPromise<JSBoolean> _sync();

@JS('ChessPush.enable')
external JSPromise<JSBoolean> _enable();
@JS('ChessPush.disable')
external JSPromise<JSBoolean> _disable();

void _ifAvailable(void Function() action) {
  try {
    final push = _push;
    if (push != null && !push.isUndefinedOrNull) action();
  } catch (_) {
    // Push is optional when the app is embedded or its browser bridge is absent.
  }
}

void configureWebPush(String apiUrl) =>
    _ifAvailable(() => _configure(apiUrl.toJS));

void syncWebPush() => _ifAvailable(() => _sync());

Future<bool> enableWebPush() async {
  try {
    final push = _push;
    if (push == null || push.isUndefinedOrNull) return false;
    return (await _enable().toDart).toDart;
  } catch (_) {
    return false;
  }
}

void disableWebPush() => _ifAvailable(() => _disable());
