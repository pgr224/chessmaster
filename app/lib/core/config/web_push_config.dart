export 'web_push_config_stub.dart'
    if (dart.library.io) 'web_push_config_native.dart'
    if (dart.library.js_interop) 'web_push_config_web.dart';
export 'notification_routes.dart';
