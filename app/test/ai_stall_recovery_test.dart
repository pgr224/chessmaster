import 'dart:async';
import 'package:flutter_test/flutter_test.dart';
import 'package:flutter/services.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/data/models/game_config.dart';
import 'package:chess_master/data/models/game_model.dart';
import 'package:chess_master/data/models/coach_model.dart';
import 'package:chess_master/data/repositories/auth_repository.dart';
import 'package:chess_master/data/repositories/game_repository.dart';
import 'package:chess_master/data/repositories/puzzle_repository.dart';
import 'package:chess_master/data/services/achievement_service.dart';
import 'package:chess_master/data/services/mission_service.dart';
import 'package:chess_master/data/services/audio_service.dart';
import 'package:chess_master/domain/engine/adaptive_ai_profile.dart';
import 'package:chess_master/domain/engine/chess_engine.dart';
import 'package:chess_master/domain/engine/coach_controller.dart';
import 'package:chess_master/domain/engine/engine_controller.dart';
import 'package:chess_master/presentation/blocs/game/game_bloc.dart';
import 'package:chess_master/presentation/blocs/theme/theme_bloc.dart';

class _Auth extends Mock implements AuthRepository {}

class _Games extends Mock implements GameRepository {}

class _Puzzles extends Mock implements PuzzleRepository {}

class _Theme extends Mock implements ThemeBloc {}

class _Achievements extends Mock implements AchievementService {}

class _Missions extends Mock implements MissionService {}

class _Coach extends Mock implements CoachController {}

class _Engine extends AIEngineController {
  final requests = <Completer<String?>>[];
  int cancellations = 0;
  AIDifficulty? selected;
  int? level;
  @override
  void init(GameMode mode, AIDifficulty? difficulty, {int? difficultyLevel}) {
    selected = difficulty;
    level = difficultyLevel;
  }

  @override
  String get aiMessage => 'Thinking';
  @override
  String get lastMoveSource => 'controlled';
  @override
  void cancelEngine() {
    cancellations++;
  }

  @override
  void dispose() {
    cancellations++;
  }

  @override
  Future<String?> getBestMove(String fen,
      {ChessEngine? engine,
      bool humanized = true,
      int moveNumber = 0,
      double? playerAccuracy,
      AdaptiveAIProfile? adaptiveProfile}) {
    final pending = Completer<String?>();
    requests.add(pending);
    return pending.future;
  }
}

void main() {
  TestWidgetsFlutterBinding.ensureInitialized();
  setUpAll(() {
    registerFallbackValue(ChessEngine());
    registerFallbackValue(Move.fromAlgebraic('e2e4'));
    final messenger =
        TestDefaultBinaryMessengerBinding.instance.defaultBinaryMessenger;
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global'), (_) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers.global/events'),
        (_) async => null);
    messenger.setMockMethodCallHandler(
        const MethodChannel('xyz.luan/audioplayers'), (call) async {
      if (call.method == 'create') {
        final id = (call.arguments as Map)['playerId'];
        messenger.setMockMethodCallHandler(
            MethodChannel('xyz.luan/audioplayers/events/$id'),
            (_) async => null);
      }
      return null;
    });
    registerFallbackValue(GameModel(
        id: '',
        fen: '',
        mode: 'singlePlayer',
        status: 'active',
        result: 'ongoing',
        moveCount: 0,
        updatedAt: DateTime(2026)));
  });
  late _Games games;
  late _Coach coach;
  late _Engine engine;
  late GameBloc bloc;
  setUp(() {
    SharedPreferences.setMockInitialValues({});
    AudioService().setEnabled(false);
    games = _Games();
    coach = _Coach();
    engine = _Engine();
    final auth = _Auth(), achievements = _Achievements();
    when(() => auth.getCurrentUser()).thenAnswer((_) async => null);
    when(() => games.saveGame(any())).thenAnswer((_) async => 'g');
    when(() => games.setLastActiveGameId(any())).thenAnswer((_) async {});
    when(() => achievements.evaluateSpecialActions(any())).thenReturn(0);
    when(() => coach.analyzeFullGame(
        moveHistory: any(named: 'moveHistory'),
        initialFEN: any(named: 'initialFEN'))).thenAnswer((_) async => {});
    bloc = GameBloc(
        games, auth, _Puzzles(), _Theme(), achievements, _Missions(),
        engineController: engine, coachController: coach);
  });
  tearDown(() async {
    for (final request in engine.requests)
      if (!request.isCompleted) request.complete(null);
    await bloc.close();
  });
  Future<void> start(
      {String color = 'white',
      int? seconds,
      GameMode mode = GameMode.singlePlayer}) async {
    final started = bloc.stream
        .firstWhere((s) => s.mode == mode && s.currentFEN.isNotEmpty);
    bloc.add(GameStartEvent(GameConfig(
        mode: mode,
        difficulty: AIDifficulty.advanced,
        difficultyLevel: 67,
        playerColor: color,
        timeControl: seconds)));
    await started;
    // Disable optional coaching for deterministic orchestration tests.
    bloc.add(const GameUpdateCoachSettingsEvent(
        CoachSettings(enableRealTimeCoaching: false)));
    await Future<void>.delayed(const Duration(milliseconds: 20));
  }

  Future<void> waitRequests(int count) async {
    final until = DateTime.now().add(const Duration(seconds: 3));
    while (engine.requests.length < count && DateTime.now().isBefore(until))
      await Future<void>.delayed(const Duration(milliseconds: 10));
    expect(engine.requests.length, count);
  }

  Future<void> humanMove() async {
    final moved = bloc.stream.firstWhere((s) => s.moveHistory.length == 1);
    bloc.add(
        GameMakeMoveEvent(Square.fromString('e2'), Square.fromString('e4')));
    await moved;
    await waitRequests(1);
  }

  test(
      'undo while the AI is searching removes one ply and ignores its stale reply',
      () async {
    await start();
    await humanMove();
    final undone =
        bloc.stream.firstWhere((s) => s.moveHistory.isEmpty && !s.isAIThinking);
    bloc.add(GameUndoEvent());
    await undone;
    engine.requests.first.complete('e7e5');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.moveHistory, isEmpty);
    expect(bloc.state.currentTurn, PieceColor.white);
    final played = bloc.stream.firstWhere((s) => s.moveHistory.length == 1);
    bloc.add(
        GameMakeMoveEvent(Square.fromString('e2'), Square.fromString('e4')));
    await played;
    await waitRequests(2);
    final reply = bloc.stream.firstWhere((s) => s.moveHistory.length == 2);
    engine.requests[1].complete('e7e5');
    await reply;
    expect(bloc.state.isAIThinking, false);
    expect(engine.selected, AIDifficulty.advanced);
    expect(engine.level, 67);
  });
  test('duplicate AI requests do not cancel or restart the foreground search',
      () async {
    await start();
    await humanMove();
    bloc.add(GameAIRequestEvent());
    bloc.add(GameAIRequestEvent());
    await Future<void>.delayed(const Duration(milliseconds: 40));
    expect(engine.requests.length, 1);
  });
  test('accepting a draw cancels thinking and rejects the pending AI move',
      () async {
    await start();
    await humanMove();
    final ended = bloc.stream.firstWhere((s) => s.result == GameResult.draw);
    bloc.add(GameDrawAcceptEvent());
    await ended;
    engine.requests.first.complete('e7e5');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.isAIThinking, false);
    expect(bloc.state.moveHistory.length, 1);
    expect(engine.cancellations, greaterThan(1));
  });
  test(
      'clock flag clears thinking and prevents a delayed move after the game ends',
      () async {
    await start(seconds: 1);
    await humanMove();
    final ended = bloc.stream.firstWhere((s) => s.isGameOver);
    await ended.timeout(const Duration(seconds: 3));
    engine.requests.first.complete('e7e5');
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.isAIThinking, false);
    expect(bloc.state.gameReason, 'timeout');
    expect(bloc.state.moveHistory.length, 1);
  });
  test(
      'failed local storage does not prevent the computer from starting as White',
      () async {
    when(() => games.saveGame(any()))
        .thenThrow(StateError('storage unavailable'));
    await start(color: 'black');
    await waitRequests(1);
    expect(bloc.state.isAIThinking, true);
    expect(engine.selected, AIDifficulty.advanced);
  });
  test('a stalled coach cannot block the next practice AI turn', () async {
    when(() => coach.evaluateMove(
            engineBeforeMove: any(named: 'engineBeforeMove'),
            playedMove: any(named: 'playedMove'),
            engineAfterMove: any(named: 'engineAfterMove')))
        .thenAnswer((_) => Completer<CoachFeedback>().future);
    await start(mode: GameMode.practice);
    bloc.add(const GameUpdateCoachSettingsEvent(
        CoachSettings(enableRealTimeCoaching: true)));
    await Future<void>.delayed(const Duration(milliseconds: 10));
    await humanMove();
    expect(engine.selected, AIDifficulty.advanced);
    expect(engine.level, 67);
    expect(bloc.state.isAIThinking, true);
  });
  test(
      'a late autosave from the previous game cannot invalidate a new AI reply',
      () async {
    final oldSave = Completer<String>();
    var saves = 0;
    when(() => games.saveGame(any())).thenAnswer((_) {
      saves++;
      return saves == 2
          ? oldSave.future
          : Future.value(saves == 1 ? 'first' : 'second');
    });
    await start();
    bloc.add(GameSaveEvent());
    await Future<void>.delayed(const Duration(milliseconds: 20));
    expect(saves, 2);
    final restarted =
        bloc.stream.firstWhere((s) => s.playerColor == PieceColor.black);
    bloc.add(const GameStartEvent(GameConfig(
        mode: GameMode.singlePlayer,
        difficulty: AIDifficulty.advanced,
        playerColor: 'black')));
    await restarted;
    await waitRequests(1);
    oldSave.complete('old');
    await Future<void>.delayed(const Duration(milliseconds: 20));
    final reply = bloc.stream.firstWhere((s) => s.moveHistory.length == 1);
    engine.requests.first.complete('e2e4');
    await reply.timeout(const Duration(seconds: 1));
    expect(bloc.state.isAIThinking, false);
    expect(bloc.state.currentTurn, PieceColor.black);
  });
  test('undoing before Black has moved cannot leave the computer turn stalled',
      () async {
    await start(color: 'black');
    await waitRequests(1);
    final opening = bloc.stream.firstWhere((s) => s.moveHistory.length == 1);
    engine.requests.first.complete('e2e4');
    await opening;
    bloc.add(GameUndoEvent());
    await Future<void>.delayed(const Duration(milliseconds: 30));
    expect(bloc.state.moveHistory.length, 1);
    expect(bloc.state.currentTurn, PieceColor.black);
    expect(bloc.state.isAIThinking, false);
  });

  test('saved AI difficulty and numeric level survive resume', () async {
    final saved = GameModel(
        id: 'saved',
        fen: ChessEngine().toFEN(),
        mode: 'singlePlayer',
        status: 'active',
        result: 'ongoing',
        moveCount: 0,
        playerColor: 'white',
        aiDifficulty: 'impossible',
        aiDifficultyLevel: 93,
        updatedAt: DateTime.now());
    final roundTrip = GameModel.fromJson(saved.toJson());
    expect(roundTrip.aiDifficulty, 'impossible');
    expect(roundTrip.aiDifficultyLevel, 93);
    when(() => games.getSavedGame('saved')).thenAnswer((_) async => roundTrip);
    final resumed = bloc.stream
        .firstWhere((s) => s.aiDifficulty == AIDifficulty.impossible);
    bloc.add(const GameResumeEvent('saved'));
    await resumed;
    expect(engine.selected, AIDifficulty.impossible);
    expect(engine.level, 93);
    expect(bloc.state.playerColor, PieceColor.white);
  });
}
