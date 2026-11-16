import 'dart:async';

import 'package:chess_master/data/services/mission_service.dart';
import 'package:chess_master/data/services/multiplayer_service.dart';
import 'package:chess_master/domain/engine/chess_engine.dart';
import 'package:chess_master/presentation/blocs/auth/auth_bloc.dart';
import 'package:chess_master/presentation/blocs/multiplayer/multiplayer_bloc.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';

class _Service extends Mock implements MultiplayerService {}

class _Auth extends Mock implements AuthBloc {}

class _Missions extends Mock implements MissionService {}

void main() {
  setUpAll(() => registerFallbackValue(AuthCheckStatusEvent()));

  late _Service service;
  late _Auth auth;
  late _Missions missions;
  late StreamController<Map<String, dynamic>> messages;
  late MultiplayerBloc bloc;
  Future<void> settle() =>
      Future<void>.delayed(const Duration(milliseconds: 15));

  setUp(() {
    service = _Service();
    auth = _Auth();
    missions = _Missions();
    messages = StreamController<Map<String, dynamic>>.broadcast();
    when(() => auth.state).thenReturn(AuthUnauthenticatedState());
    when(() => service.userId).thenReturn('me');
    when(() => service.gameUpdates).thenAnswer((_) => messages.stream);
    when(() => service.joinRoom(any(), any(),
        timeControl: any(named: 'timeControl'),
        variantId: any(named: 'variantId'))).thenAnswer((_) async {});
    when(() => missions.recordGameResult(any(),
        isWin: any(named: 'isWin'),
        isOnline: any(named: 'isOnline'),
        currentStreak: any(named: 'currentStreak'))).thenAnswer((_) async {});
    bloc = MultiplayerBloc(service, auth,
        missions: missions, loadWinStreak: () async => 3);
  });
  tearDown(() async {
    await bloc.close();
    await messages.close();
  });

  Future<void> game() async {
    bloc.add(const MpGameFoundEvent('first', PieceColor.white, 'Opponent'));
    await settle();
  }

  test(
      'transport loss preserves server snapshot and reconnect clears only connection flags',
      () async {
    await game();
    final snapshot = {
      'fen': 'server-position',
      'whiteId': 'me',
      'blackId': 'them',
      'whiteTime': 30,
      'blackTime': 40
    };
    messages.add({'type': 'ROOM_STATE', 'data': snapshot});
    await settle();
    messages.add({
      'type': 'CONNECTION_STATUS',
      'data': {'connected': false, 'retrying': true}
    });
    await settle();
    expect(bloc.state.serverPosition, snapshot);
    expect(bloc.state.status, MultiplayerStatus.inGame);
    expect(bloc.state.gameReconnecting, true);
    messages.add({
      'type': 'CONNECTION_STATUS',
      'data': {'connected': true, 'retrying': false}
    });
    await settle();
    expect(bloc.state.serverPosition, snapshot);
    expect(bloc.state.gameReconnecting, false);
    expect(bloc.state.connectionError, isNull);
  });

  test(
      'rematch request and accept use room protocol and a new game clears old result',
      () async {
    await game();
    bloc.add(const MpGameOverEvent('white', 'checkmate', xpDelta: 100));
    await settle();
    bloc.add(MpRematchRequestEvent());
    bloc.add(MpRematchRequestEvent());
    await settle();
    verify(() => service.sendRematchRequest()).called(1);
    messages.add({
      'type': 'REMATCH_REQUEST',
      'data': {'from': 'them'}
    });
    await settle();
    expect(bloc.state.rematchReceived, true);
    bloc.add(MpRematchAcceptEvent());
    await settle();
    verify(() => service.sendRematchAccept()).called(1);
    messages.add({
      'type': 'REMATCH_READY',
      'data': {'gameId': 'second', 'color': 'black', 'timeControl': '5+0'}
    });
    await settle();
    expect(bloc.state.gameId, 'second');
    expect(bloc.state.playerColor, PieceColor.black);
    expect(bloc.state.gameResult, isNull);
    expect(bloc.state.gameReason, isNull);
    expect(bloc.state.rematchRequested, false);
    expect(bloc.state.rematchReceived, false);
    verify(() => service.joinRoom('second', 'black',
        timeControl: '5+0', variantId: 'standard')).called(1);
  });

  test('online missions wait for settlement and record a game only once',
      () async {
    await game();
    bloc.add(
        const MpGameOverEvent('white', 'checkmate', settlementPending: true));
    await settle();
    verifyNever(() => missions.recordGameResult(any(),
        isWin: any(named: 'isWin'),
        isOnline: any(named: 'isOnline'),
        currentStreak: any(named: 'currentStreak')));
    bloc.add(const MpGameOverEvent('white', 'checkmate', xpDelta: 0));
    bloc.add(const MpGameOverEvent('white', 'checkmate', xpDelta: 0));
    await settle();
    verify(() => missions.recordGameResult('first',
        isWin: true, isOnline: true, currentStreak: 3)).called(1);
    expect(bloc.state.xpGained, 0);
  });

  test('cancelled waiting games do not progress missions', () async {
    await game();
    bloc.add(const MpGameOverEvent('draw', 'opponent_no_show', xpDelta: 0));
    await settle();
    verifyNever(() => missions.recordGameResult(any(),
        isWin: any(named: 'isWin'),
        isOnline: any(named: 'isOnline'),
        currentStreak: any(named: 'currentStreak')));
  });
}
