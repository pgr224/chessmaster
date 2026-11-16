import 'dart:convert';
import 'package:chess_master/data/models/coach_model.dart';
import 'package:chess_master/data/models/game_config.dart';
import 'package:chess_master/data/models/user_model.dart';
import 'package:chess_master/data/repositories/auth_repository.dart';
import 'package:chess_master/data/repositories/game_repository.dart';
import 'package:chess_master/data/repositories/puzzle_repository.dart';
import 'package:chess_master/data/services/achievement_service.dart';
import 'package:chess_master/data/services/mission_service.dart';
import 'package:chess_master/domain/engine/chess_engine.dart';
import 'package:chess_master/presentation/blocs/game/game_bloc.dart';
import 'package:chess_master/presentation/blocs/theme/theme_bloc.dart';
import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _Auth extends Mock implements AuthRepository {}

class _Games extends Mock implements GameRepository {}

class _Puzzles extends Mock implements PuzzleRepository {}

class _Theme extends Mock implements ThemeBloc {}

class _Achievements extends Mock implements AchievementService {}

class _Missions extends Mock implements MissionService {}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() => registerFallbackValue(ThemeShuffleEvent()));
  setUp(() => SharedPreferences.setMockInitialValues({}));

  test('post-move hints follow the human mover for either chosen color', () {
    for (final player in PieceColor.values) {
      final opponent =
          player == PieceColor.white ? PieceColor.black : PieceColor.white;
      final initial = GameState(
          board: ChessEngine().board,
          currentTurn: opponent,
          playerColor: player,
          mode: GameMode.singlePlayer,
          moveHistory: [Move.fromAlgebraic('e2e4')],
          coachFeedback: CoachFeedback(
              classification: MoveClassification.good,
              message: 'Good move',
              timestamp: DateTime(2026)));
      expect(initial.showMoveFeedback, true);
      expect(initial.copyWith(currentTurn: player).showMoveFeedback, false);
      for (final mode in [
        GameMode.twoPlayer,
        GameMode.multiplayer,
        GameMode.tournament
      ]) {
        for (final turn in PieceColor.values) {
          final human = initial.copyWith(
              mode: mode, currentTurn: turn, isAIThinking: true);
          expect(human.showMoveFeedback, true);
          expect(human.showComputerThinking, false);
        }
      }
    }
  });

  test(
      'computer thinking requires a computer game, its turn, and an active search',
      () {
    for (final player in PieceColor.values) {
      final opponent =
          player == PieceColor.white ? PieceColor.black : PieceColor.white;
      final computer = GameState(
          board: ChessEngine().board,
          currentTurn: opponent,
          playerColor: player,
          mode: GameMode.singlePlayer,
          isAIThinking: true);
      expect(computer.showComputerThinking, true);
      expect(
          computer.copyWith(currentTurn: player).showComputerThinking, false);
      expect(
          computer.copyWith(isAIThinking: false).showComputerThinking, false);
      expect(
          computer
              .copyWith(status: GameStatus.draw, result: GameResult.draw)
              .showComputerThinking,
          false);
      for (final mode in [
        GameMode.twoPlayer,
        GameMode.multiplayer,
        GameMode.tournament,
        GameMode.puzzle,
        GameMode.tutorial
      ]) {
        expect(computer.copyWith(mode: mode).showComputerThinking, false);
      }
    }
  });

  test(
      'server moves coach both multiplayer colors without showing human thinking',
      () async {
    final auth = _Auth();
    when(() => auth.getCurrentUser()).thenAnswer((_) async => null);
    final bloc = GameBloc(
        _Games(), auth, _Puzzles(), _Theme(), _Achievements(), _Missions());
    addTearDown(bloc.close);
    final started =
        bloc.stream.firstWhere((s) => s.mode == GameMode.multiplayer);
    bloc.add(const GameStartEvent(GameConfig(
        mode: GameMode.multiplayer, playerColor: 'white', activeGameId: 'g')));
    await started;
    expect(bloc.state.coachSettings.enableMultiplayerCoaching, true);
    final moves = <Map<String, String>>[];
    for (final move in [
      {'from': 'e2', 'to': 'e4'},
      {'from': 'e7', 'to': 'e5'}
    ]) {
      moves.add(move);
      final coached = bloc.stream
          .firstWhere((s) => s.gameCoachHistory.length == moves.length);
      bloc.add(GameServerSyncEvent({
        'status': 'active',
        'moves': [...moves],
        'whiteTime': 600,
        'blackTime': 600
      }));
      final state = await coached.timeout(const Duration(seconds: 10));
      expect(state.showMoveFeedback, true);
      expect(state.isAIThinking, false);
      expect(state.showComputerThinking, false);
    }
    final oldCount = bloc.state.gameCoachHistory.length;
    bloc.add(GameServerSyncEvent({
      'status': 'active',
      'moves': [...moves],
      'whiteTime': 599,
      'blackTime': 600
    }));
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.gameCoachHistory.length, oldCount);
  });

  test(
      'level 10 requires 10000 XP with continuous progress and a starter floor',
      () {
    UserModel user(int xp) =>
        UserModel.fromJson({'id': 'u', 'username': 'u', 'xp': xp});
    expect(user(0).level, 1);
    expect(user(-10).level, 1);
    expect(user(399).level, 1);
    expect(user(400).level, 2);
    expect(user(9999).level, 9);
    expect(user(10000).level, 10);
    expect(user(10000).levelProgress, 0);
  });

  test(
      'timeout material distinguishes a bare king from possible mating positions',
      () {
    expect(
        ChessEngine.fromFEN('7k/8/8/8/8/8/8/KQ6 w - - 0 1')
            .canPossiblyMate(PieceColor.black),
        false);
    expect(
        ChessEngine.fromFEN('7k/8/8/8/8/8/8/KB6 w - - 0 1')
            .canPossiblyMate(PieceColor.white),
        false);
    expect(
        ChessEngine.fromFEN('7k/7p/8/8/8/8/8/KB6 w - - 0 1')
            .canPossiblyMate(PieceColor.white),
        true);
    expect(
        ChessEngine.fromFEN('7k/8/8/8/8/8/8/KNN5 w - - 0 1')
            .canPossiblyMate(PieceColor.white),
        true);
  });

  test(
      'online snapshot restores moves and clocks, then takeback without local XP writes',
      () async {
    final auth = _Auth(), games = _Games();
    when(() => auth.getCurrentUser()).thenAnswer((_) async => null);
    final bloc = GameBloc(
        games, auth, _Puzzles(), _Theme(), _Achievements(), _Missions());
    addTearDown(bloc.close);
    final snapshot = {
      'status': 'active',
      'moves': [
        {'from': 'e2', 'to': 'e4'},
        {'from': 'e7', 'to': 'e5'}
      ],
      'whiteTime': 123.5,
      'blackTime': 119.0
    };
    bloc.add(GameServerSyncEvent(
        snapshot)); // May arrive before the deferred board starts.
    final restored = bloc.stream.firstWhere((s) => s.moveHistory.length == 2);
    bloc.add(const GameStartEvent(GameConfig(
        mode: GameMode.tournament,
        playerColor: 'white',
        activeGameId: 'g',
        tournamentId: 't')));
    final state = await restored;
    expect(state.isOnline, true);
    expect(state.whiteTimeMs, 123500);
    expect(state.blackTimeMs, 119000);
    expect(bloc.engine.pieceAt(Square.fromString('e4'))?.type, PieceType.pawn);
    final takenBack = bloc.stream.firstWhere((s) => s.moveHistory.length == 1);
    bloc.add(GameServerSyncEvent({
      ...snapshot,
      'moves': [
        {'from': 'e2', 'to': 'e4'}
      ]
    }));
    await takenBack;
    expect(bloc.engine.pieceAt(Square.fromString('e7'))?.type, PieceType.pawn);
    expect(bloc.engine.pieceAt(Square.fromString('e5')), isNull);
    verifyNever(() => games.setLastActiveGameId(any()));
    verifyNever(() => auth.updateXPProgress(
        userId: any(named: 'userId'),
        xpDelta: any(named: 'xpDelta'),
        statUpdates: any(named: 'statUpdates')));
  });

  test(
      'local progress serializes penalties, floors at zero and preserves absolute ratings',
      () async {
    SharedPreferences.setMockInitialValues({
      'user_data': jsonEncode({
        'id': 'u',
        'xp': 5,
        'stats': {'puzzle_rating': 1200}
      })
    });
    var serverXP = 5, requests = 0;
    final dio = Dio();
    dio.interceptors.add(InterceptorsWrapper(onRequest: (options, handler) {
      requests++;
      final delta = options.data['xpDelta'] as int, before = serverXP;
      serverXP = (serverXP + delta).clamp(0, 100000);
      handler.resolve(Response(
          requestOptions: options,
          statusCode: 200,
          data: {'xp': serverXP, 'xpDelta': serverXP - before}));
    }));
    final auth = AuthRepository(dio);
    final first = auth.updateXPProgress(
        userId: 'u',
        xpDelta: -25,
        statUpdates: {'puzzle_rating': 1250},
        eventId: 'undo:1');
    final second = auth.updateXPProgress(
        userId: 'u', xpDelta: -10, statUpdates: {}, eventId: 'hint:2');
    expect(await first, -5);
    expect(await second, 0);
    expect(
        await auth.updateXPProgress(
            userId: 'u', xpDelta: -25, statUpdates: {}, eventId: 'undo:1'),
        -5);
    expect(requests, 2);
    final cached = jsonDecode(
        (await SharedPreferences.getInstance()).getString('user_data')!);
    expect(cached['xp'], 0);
    expect(cached['stats']['puzzle_rating'], 1250);
  });

  test(
      'offline XP retries retain the original event ID without a second local award',
      () async {
    SharedPreferences.setMockInitialValues({
      'auth_token': 'token',
      'user_data': jsonEncode({'id': 'u', 'xp': 0, 'stats': {}})
    });
    final dio = Dio();
    var online = false;
    final sent = <String>[];
    dio.interceptors.add(InterceptorsWrapper(onRequest: (o, h) {
      sent.add(o.data['eventId'] as String);
      if (!online) {
        h.reject(DioException(requestOptions: o));
        return;
      }
      h.resolve(Response(
          requestOptions: o,
          statusCode: 200,
          data: {'xp': 100, 'xpDelta': 100}));
    }));
    final auth = AuthRepository(dio);
    expect(
        await auth.updateXPProgress(
            userId: 'u',
            xpDelta: 100,
            statUpdates: {'ai_games': 1},
            eventId: 'game:g:result'),
        100);
    online = true;
    await auth.syncPendingProgress();
    expect(sent, ['game:g:result', 'game:g:result']);
    final prefs = await SharedPreferences.getInstance();
    expect(jsonDecode(prefs.getString('user_data')!)['xp'], 100);
    expect(jsonDecode(prefs.getString('pending_xp_u')!), isEmpty);
    expect(
        await auth.updateXPProgress(
            userId: 'u',
            xpDelta: 100,
            statUpdates: {},
            eventId: 'game:g:result'),
        100);
    expect(sent.length, 2);
  });
}
