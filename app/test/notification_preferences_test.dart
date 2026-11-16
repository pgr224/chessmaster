import 'dart:async';
import 'dart:convert';

import 'package:chess_master/presentation/blocs/settings/settings_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Dio extends Mock implements Dio {}

Response<dynamic> _response(Map<String, dynamic> data) => Response(
      data: data,
      statusCode: 200,
      requestOptions: RequestOptions(path: '/api/push/settings'),
    );

Future<void> _until(bool Function() condition) async {
  for (var i = 0; i < 100 && !condition(); i++) {
    await Future<void>.delayed(Duration.zero);
  }
  expect(condition(), isTrue,
      reason: 'asynchronous preference operation completed');
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late _Dio dio;
  late SharedPreferences prefs;
  late SettingsBloc bloc;

  setUp(() async {
    SharedPreferences.setMockInitialValues({
      'user_data': jsonEncode({'id': 'alice', 'is_guest': false}),
    });
    prefs = await SharedPreferences.getInstance();
    dio = _Dio();
    when(() => dio.put<dynamic>(any(), data: any(named: 'data')))
        .thenAnswer((_) async => _response({'success': true}));
    when(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async =>
            _response({'enabled': true, 'categories': <String, bool>{}}));
    bloc = SettingsBloc(dio: dio);
  });
  tearDown(() => bloc.close());

  test(
      'successful preference sync clears dirty state and later loads respect the server',
      () async {
    bloc.add(const SettingsNotificationsEvent(false));
    await _until(() => prefs.getBool('notification_settings_dirty') == false);
    expect(bloc.state.notificationsEnabled, isFalse);
    expect(prefs.getBool('notifications'), isFalse);

    // Another device enabled the account after this device's successful change.
    bloc.add(SettingsLoadEvent());
    await _until(() => bloc.state.isLoaded && bloc.state.notificationsEnabled);
    verify(() =>
            dio.put<dynamic>('/api/push/settings', data: any(named: 'data')))
        .called(1);
  });

  test(
      'offline choice remains dirty and retries before remote settings are loaded',
      () async {
    var attempts = 0;
    when(() => dio.put<dynamic>(any(), data: any(named: 'data')))
        .thenAnswer((_) async {
      attempts++;
      if (attempts == 1)
        throw DioException(
            requestOptions: RequestOptions(path: '/api/push/settings'));
      return _response({'success': true});
    });
    when(() => dio.get<dynamic>(any(),
            queryParameters: any(named: 'queryParameters')))
        .thenAnswer((_) async =>
            _response({'enabled': false, 'categories': <String, bool>{}}));
    bloc.add(const SettingsNotificationsEvent(false));
    await _until(() => attempts == 1 && !bloc.state.notificationsEnabled);
    expect(prefs.getBool('notification_settings_dirty'), isTrue);
    bloc.add(SettingsLoadEvent());
    await _until(() =>
        attempts == 2 && prefs.getBool('notification_settings_dirty') == false);
    expect(bloc.state.notificationsEnabled, isFalse);
  });

  test('a delayed settings read cannot overwrite a new user opt-out', () async {
    final response = Completer<Response<dynamic>>();
    var reading = false;
    when(() => dio.get<dynamic>(any(),
        queryParameters: any(named: 'queryParameters'))).thenAnswer((_) {
      reading = true;
      return response.future;
    });
    bloc.add(SettingsLoadEvent());
    await _until(() => reading);
    bloc.add(const SettingsNotificationCategoryEvent('games', false));
    await _until(() => prefs.getBool('notification_settings_dirty') == false);
    response.complete(_response({
      'enabled': true,
      'categories': {'games': true}
    }));
    await Future<void>.delayed(Duration.zero);
    expect(bloc.state.notificationGames, isFalse);
    expect(prefs.getBool('notif_games'), isFalse);
  });

  test(
      'concurrent master and category choices preserve both values and ordered writes',
      () async {
    final firstWrite = Completer<Response<dynamic>>();
    final payloads = <Map<String, dynamic>>[];
    when(() => dio.put<dynamic>(any(), data: any(named: 'data')))
        .thenAnswer((invocation) async {
      payloads.add(
          Map<String, dynamic>.from(invocation.namedArguments[#data] as Map));
      if (payloads.length == 1) return firstWrite.future;
      return _response({'success': true});
    });
    bloc.add(const SettingsNotificationsEvent(false));
    await _until(() => payloads.length == 1);
    bloc.add(const SettingsNotificationCategoryEvent('games', false));
    await Future<void>.delayed(Duration.zero);
    expect(payloads.length, 1,
        reason: 'the next change waits for the previous write');
    firstWrite.complete(_response({'success': true}));
    await _until(() =>
        payloads.length == 2 &&
        prefs.getBool('notification_settings_dirty') == false);
    expect(payloads.last['enabled'], isFalse);
    expect((payloads.last['categories'] as Map)['games'], isFalse);
    expect(bloc.state.notificationsEnabled, isFalse);
    expect(bloc.state.notificationGames, isFalse);
  });
}
