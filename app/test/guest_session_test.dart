import 'dart:convert';
import 'dart:async';
import 'package:chess_master/core/router/guest_access_policy.dart';
import 'package:chess_master/data/models/game_model.dart';
import 'package:chess_master/data/repositories/auth_repository.dart';
import 'package:chess_master/data/repositories/game_repository.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  late Dio dio;
  late AuthRepository auth;
  late List<RequestOptions> requests;
  final account = {
    'id': 'registered',
    'username': 'MyAccount',
    'xp': 15000,
    'device_id': 'same-device',
    'stats': {'elo_rating': 1600}
  };
  setUp(() {
    SharedPreferences.setMockInitialValues({
      'device_id': 'same-device',
      'user_data': jsonEncode(account),
      'auth_token': 'previous-token'
    });
    requests = [];
    dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      requests.add(o);
      h.reject(DioException(requestOptions: o));
    }));
    auth = AuthRepository(dio);
  });
  test(
      'guest cannot reuse a registered cache, bearer token or forced automatic login',
      () async {
    final guest = await auth.startGuestSession();
    expect(guest.isGuest, true);
    expect(guest.xp, 0);
    expect((await auth.getCachedUser())!.id, guest.id);
    expect((await auth.getCurrentUser(forceRefresh: true))!.id, guest.id);
    expect(await auth.getToken(), isNull);
    expect(requests, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('device_id'), 'same-device');
    expect(jsonDecode(prefs.getString('user_data')!)['xp'], 15000);
    expect(prefs.getString('auth_token'), isNull);
  });
  test('guest XP is temporary, idempotent and never queued for account sync',
      () async {
    final guest = await auth.startGuestSession();
    for (var i = 0; i < 2; i++)
      expect(
          await auth.updateXPProgress(
              userId: guest.id,
              xpDelta: 100,
              statUpdates: {'wins': 1},
              eventId: 'game:one:result'),
          100);
    expect((await auth.getCurrentUser())!.xp, 100);
    expect((await auth.getCurrentUser())!.stats.wins, 1);
    await auth.syncPendingProgress();
    expect(requests, isEmpty);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getString('pending_xp_${guest.id}'), isNull);
    expect(jsonDecode(prefs.getString('user_data')!)['xp'], 15000);
    final fresh = await auth.resetGuestProgress();
    expect(fresh!.xp, 0);
    expect(fresh.stats.wins, 0);
    expect(fresh.id, isNot(guest.id));
    expect(
        await auth.updateXPProgress(
            userId: guest.id,
            xpDelta: 1000,
            statUpdates: {},
            eventId: 'late-result'),
        0);
    expect((await auth.getCurrentUser())!.xp, 0);
  });
  test(
      'reopening a guest session starts at zero without reauthenticating the device',
      () async {
    final guest = await auth.startGuestSession();
    await auth.updateXPProgress(
        userId: guest.id, xpDelta: 700, statUpdates: {}, eventId: 'test');
    final restarted = AuthRepository(dio);
    final restored = await restarted.getCurrentUser();
    expect(restored!.isGuest, true);
    expect(restored.xp, 0);
    expect(requests, isEmpty);
  });
  test(
      'explicit account login still uses the same device binding and never imports guest XP',
      () async {
    final guest = await auth.startGuestSession();
    await auth.updateXPProgress(
        userId: guest.id, xpDelta: 1000, statUpdates: {}, eventId: 'test');
    dio.interceptors.clear();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      requests.add(o);
      h.resolve(Response(requestOptions: o, statusCode: 200, data: {
        'token': 'new-token',
        'userId': 'registered',
        'user': account
      }));
    }));
    final registered = await auth.login();
    expect(requests.single.path, '/api/auth/login');
    expect(requests.single.data['deviceId'], 'same-device');
    expect(registered.isGuest, false);
    expect(registered.xp, 15000);
    expect(await auth.getToken(), 'new-token');
    expect((await auth.getCurrentUser())!.id, 'registered');
    expect(
        (await SharedPreferences.getInstance())
            .getBool(AuthRepository.guestSessionKey),
        isNull);
  });
  test(
      'guest games stay in memory and cannot sync game records or recent history',
      () async {
    final guest = await auth.startGuestSession();
    final games = GameRepository(dio);
    final game = GameModel(
        id: '',
        fen: 'initial',
        mode: 'singlePlayer',
        status: 'active',
        result: 'ongoing',
        moveCount: 0,
        updatedAt: DateTime.now());
    final id = await games.saveGame(game);
    await games.setLastActiveGameId(id);
    expect(await games.getLastActiveGameId(), id);
    expect((await games.getSavedGame(id))!.id, id);
    await games.completeGame((await games.getSavedGame(id))!);
    expect(await games.getRecentGames(guest.id), isEmpty);
    expect(requests, isEmpty);
    games.clearGuestGames();
    expect(await games.getSavedGames(), isEmpty);
    expect(await games.getLastActiveGameId(), isNull);
  });
  test('a delayed device login cannot replace a newer guest session', () async {
    final arrived = Completer<RequestOptions>(), response = Completer<void>();
    dio.interceptors.clear();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) async {
      arrived.complete(o);
      await response.future;
      h.resolve(Response(requestOptions: o, statusCode: 200, data: {
        'token': 'late-token',
        'userId': 'registered',
        'user': account
      }));
    }));
    final signingIn = auth.login();
    final rejected = expectLater(signingIn, throwsStateError);
    await arrived.future;
    final guest = await auth.startGuestSession();
    response.complete();
    await rejected;
    expect((await auth.getCurrentUser())!.id, guest.id);
    expect(await auth.getToken(), isNull);
  });

  test(
      'signing out of guest clears temporary XP and cached sign-in without changing the device ID',
      () async {
    final guest = await auth.startGuestSession();
    await auth.updateXPProgress(
        userId: guest.id, xpDelta: 200, statUpdates: {}, eventId: 'test');
    await auth.signOut();
    expect(await auth.getCachedUser(), isNull);
    expect(await auth.getCurrentUser(), isNull);
    expect(await auth.getToken(), isNull);
    expect((await SharedPreferences.getInstance()).getString('device_id'),
        'same-device');
    expect(requests, isEmpty);
  });

  test('all online routes and online game extras require an account', () {
    for (final route in [
      '/lobby',
      '/matchmaking',
      '/room/abc',
      '/tournament/invite',
      '/tournament/abc/result',
      '/leaderboard',
      '/chess_world',
      '/settings/donations'
    ]) expect(guestOnlineFeature(route), isNotNull, reason: route);
    expect(guestOnlineFeature('/game', onlineGame: true), isNotNull);
    for (final route in [
      '/home',
      '/game',
      '/game-setup',
      '/tutorial',
      '/learn',
      '/settings'
    ]) expect(guestOnlineFeature(route), isNull, reason: route);
  });
}
