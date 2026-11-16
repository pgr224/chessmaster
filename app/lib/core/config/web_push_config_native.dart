import 'dart:async';
import 'dart:convert';
import 'dart:io';
import 'package:dio/dio.dart';
import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter_local_notifications/flutter_local_notifications.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'notification_routes.dart';

const _project = String.fromEnvironment('FIREBASE_PROJECT_ID');
const _apiKey = String.fromEnvironment('FIREBASE_API_KEY');
const _sender = String.fromEnvironment('FIREBASE_MESSAGING_SENDER_ID');
const _androidApp = String.fromEnvironment('FIREBASE_ANDROID_APP_ID');
const _iosApp = String.fromEnvironment('FIREBASE_IOS_APP_ID');
const _usePlatformConfig =
    bool.fromEnvironment('FIREBASE_NOTIFICATIONS_ENABLED');
bool get _configured =>
    (Platform.isAndroid || Platform.isIOS) &&
    (_usePlatformConfig ||
        (_project.isNotEmpty &&
            _apiKey.isNotEmpty &&
            _sender.isNotEmpty &&
            (Platform.isIOS ? _iosApp : _androidApp).isNotEmpty));
FirebaseOptions get _options => FirebaseOptions(
    apiKey: _apiKey,
    appId: Platform.isIOS ? _iosApp : _androidApp,
    messagingSenderId: _sender,
    projectId: _project,
    iosBundleId: Platform.isIOS
        ? const String.fromEnvironment('FIREBASE_IOS_BUNDLE_ID',
            defaultValue: 'com.example.chessMaster')
        : null);
@pragma('vm:entry-point')
Future<void> _backgroundMessage(RemoteMessage message) async {
  if (_configured && Firebase.apps.isEmpty)
    await Firebase.initializeApp(options: _usePlatformConfig ? null : _options);
  // Background notification payloads are displayed by Android/iOS, once.
}

final _local = FlutterLocalNotificationsPlugin();
Future<void>? _ready;
String _apiBase = '';
int _generation = 0;
Future<void> _initialize() async {
  if (!_configured) return;
  if (Firebase.apps.isEmpty)
    await Firebase.initializeApp(options: _usePlatformConfig ? null : _options);
  FirebaseMessaging.onBackgroundMessage(_backgroundMessage);
  await _local.initialize(
      const InitializationSettings(
          android: AndroidInitializationSettings('ic_stat_chess'),
          iOS: DarwinInitializationSettings(
              requestAlertPermission: false,
              requestBadgePermission: false,
              requestSoundPermission: false)),
      onDidReceiveNotificationResponse: (response) {
    if (response.payload != null)
      handleNotificationData(
          Map<String, dynamic>.from(jsonDecode(response.payload!) as Map));
  });
  for (final category in [
    'challenges',
    'games',
    'community',
    'tournaments',
    'system'
  ]) {
    await _local
        .resolvePlatformSpecificImplementation<
            AndroidFlutterLocalNotificationsPlugin>()
        ?.createNotificationChannel(AndroidNotificationChannel(
            'chess_$category', 'Chess $category',
            importance: Importance.high, playSound: true));
  }
  await FirebaseMessaging.instance.setForegroundNotificationPresentationOptions(
      alert: false, badge: false, sound: false);
  FirebaseMessaging.onMessage.listen((message) async {
    final prefs = await SharedPreferences.getInstance(),
        category = message.data['category']?.toString() ?? 'system';
    if (prefs.getString('auth_token') == null ||
        !(prefs.getBool('notifications') ?? true) ||
        !(prefs.getBool('notif_$category') ?? true)) return;
    final notification = message.notification;
    if (notification == null) return;
    await _local.show(
        message.messageId?.hashCode ??
            DateTime.now().millisecondsSinceEpoch.remainder(1 << 30),
        notification.title,
        notification.body,
        NotificationDetails(
            android: AndroidNotificationDetails(
                'chess_$category', 'Chess $category',
                importance: Importance.high,
                priority: Priority.high,
                icon: 'ic_stat_chess'),
            iOS: const DarwinNotificationDetails(
                presentAlert: true, presentBadge: true, presentSound: true)),
        payload: jsonEncode(message.data));
  });
  FirebaseMessaging.onMessageOpenedApp
      .listen((message) => handleNotificationData(message.data));
  FirebaseMessaging.instance.onTokenRefresh.listen((_) => syncWebPush());
  final initial = await FirebaseMessaging.instance.getInitialMessage();
  if (initial != null) handleNotificationData(initial.data);
  final launch = await _local.getNotificationAppLaunchDetails();
  if (launch?.didNotificationLaunchApp == true &&
      launch?.notificationResponse?.payload != null)
    handleNotificationData(Map<String, dynamic>.from(
        jsonDecode(launch!.notificationResponse!.payload!) as Map));
}

void configureWebPush(String apiUrl) {
  _apiBase = apiUrl.replaceAll(RegExp(r'/+$'), '');
  _ready ??= _initialize().catchError((_) {
    _ready = null;
  });
}

void syncWebPush() => unawaited(_sync().catchError((_) {}));
Future<void> _sync() async {
  final generation = _generation;
  if (!_configured) return;
  await (_ready ??= _initialize());
  if (generation != _generation) return;
  final prefs = await SharedPreferences.getInstance(),
      token = prefs.getString('auth_token');
  if (token == null) return;
  final user = jsonDecode(prefs.getString('user_data') ?? '{}') as Map;
  if (user['is_guest'] == true || user['id'] == null) return;
  final enabled = prefs.getBool('notifications') ?? true;
  final dio = Dio(BaseOptions(
      baseUrl: _apiBase,
      headers: {'Authorization': 'Bearer $token'},
      connectTimeout: const Duration(seconds: 8),
      receiveTimeout: const Duration(seconds: 8)));
  // SettingsBloc syncs explicit offline changes and loads remote preferences.
  // Token refresh must never replace another device's preferences with defaults.
  if (!enabled) {
    await _disable();
    return;
  }
  final permission = await FirebaseMessaging.instance.getNotificationSettings();
  if (generation != _generation) return;
  if (permission.authorizationStatus != AuthorizationStatus.authorized &&
      permission.authorizationStatus != AuthorizationStatus.provisional) return;
  if (Platform.isIOS && await FirebaseMessaging.instance.getAPNSToken() == null)
    return;
  final fcm = await FirebaseMessaging.instance.getToken();
  if (fcm == null ||
      generation != _generation ||
      prefs.getString('auth_token') != token) return;
  await dio.post('/api/push/native-token', data: {
    'token': fcm,
    'platform': Platform.isIOS ? 'ios' : 'android',
    'deviceId': prefs.getString('device_id')
  });
}

Future<bool> enableWebPush() async {
  if (!_configured) return false;
  try {
    await (_ready ??= _initialize());
    final permission = await FirebaseMessaging.instance
        .requestPermission(alert: true, badge: true, sound: true);
    await _sync();
    return permission.authorizationStatus == AuthorizationStatus.authorized ||
        permission.authorizationStatus == AuthorizationStatus.provisional;
  } catch (_) {
    return false;
  }
}

Future<void> _disable() async {
  _generation++;
  if (!_configured) return;
  await (_ready ??= _initialize());
  await _local.cancelAll();
  await FirebaseMessaging.instance.deleteToken();
}

void disableWebPush() => unawaited(_disable().catchError((_) {}));
