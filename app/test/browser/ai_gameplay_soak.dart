// Standalone browser integration harness; build with flutter build web
// --target=test/browser/ai_gameplay_soak.dart --output=/tmp/chess-browser-soak.
// Run run_gameplay_soak.cjs against that output. No backend account is used.
import 'dart:async';
import 'dart:convert';
import 'dart:js_interop';
import 'dart:js_interop_unsafe';

import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:chess_master/data/models/game_config.dart';
import 'package:chess_master/data/models/game_model.dart';
import 'package:chess_master/data/models/user_model.dart';
import 'package:chess_master/data/repositories/auth_repository.dart';
import 'package:chess_master/data/repositories/game_repository.dart';
import 'package:chess_master/data/repositories/puzzle_repository.dart';
import 'package:chess_master/data/services/achievement_service.dart';
import 'package:chess_master/data/services/audio_service.dart';
import 'package:chess_master/data/services/mission_service.dart';
import 'package:chess_master/domain/engine/ai_engine.dart';
import 'package:chess_master/domain/engine/chess_engine.dart';
import 'package:chess_master/presentation/blocs/auth/auth_bloc.dart';
import 'package:chess_master/presentation/blocs/game/game_bloc.dart';
import 'package:chess_master/presentation/blocs/multiplayer/multiplayer_bloc.dart';
import 'package:chess_master/presentation/blocs/settings/settings_bloc.dart';
import 'package:chess_master/presentation/blocs/theme/theme_bloc.dart';
import 'package:chess_master/presentation/screens/game/game_screen.dart';

class _Auth extends Mock implements AuthRepository {}

class _Games extends Mock implements GameRepository {}

class _Puzzles extends Mock implements PuzzleRepository {}

class _Achievements extends Mock implements AchievementService {}

class _Missions extends Mock implements MissionService {}

class _AuthBloc extends Mock implements AuthBloc {}

class _MultiplayerBloc extends Mock implements MultiplayerBloc {}

const _user = UserModel(
    id: 'browser-soak',
    username: 'Browser Soak',
    xp: 10000,
    isOnline: false,
    stats: UserStats(),
    deviceId: 'browser-soak-device');
const _targetReplies = int.fromEnvironment('SOAK_REPLIES', defaultValue: 20);
const _requestedDifficulty = String.fromEnvironment('SOAK_DIFFICULTIES',
    defaultValue: 'intermediate,advanced');

void _require(bool condition, String message) {
  if (!condition) throw StateError(message);
}

void _publish(Map<String, dynamic> value) {
  globalContext['chessBrowserSoak'] = value.jsify();
  print('BROWSER_SOAK ${jsonEncode(value)}');
}

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  SharedPreferences.setMockInitialValues({
    'sound': false,
    'vibration': false,
    'notifications': false,
    'move_animation_speed': 'off'
  });
  AudioService().setEnabled(false);
  registerFallbackValue(const UserStats());
  registerFallbackValue(GameState(
      board: List.generate(8, (_) => List<ChessPiece?>.filled(8, null)),
      currentTurn: PieceColor.white));
  registerFallbackValue(GameModel(
      id: '',
      fen: '',
      mode: 'singlePlayer',
      status: 'active',
      result: 'ongoing',
      moveCount: 0,
      updatedAt: DateTime(2026)));
  final auth = _Auth(),
      games = _Games(),
      achievements = _Achievements(),
      missions = _Missions();
  final saved = <String, GameModel>{};
  var nextId = 0;
  when(() => auth.getCurrentUser()).thenAnswer((_) async => _user);
  when(() => auth.updateXPProgress(
      userId: any(named: 'userId'),
      xpDelta: any(named: 'xpDelta'),
      statUpdates: any(named: 'statUpdates'),
      eventId: any(named: 'eventId'))).thenAnswer((_) async => 0);
  when(() => auth.updatePracticeDifficulty(any(), any()))
      .thenAnswer((_) async {});
  when(() => games.saveGame(any())).thenAnswer((invocation) async {
    final game = invocation.positionalArguments.first as GameModel;
    final id = game.id.isEmpty ? 'soak-${++nextId}' : game.id;
    saved[id] = GameModel.fromJson({...game.toJson(), 'id': id});
    return id;
  });
  when(() => games.getSavedGame(any())).thenAnswer(
      (invocation) async => saved[invocation.positionalArguments.first]);
  when(() => games.setLastActiveGameId(any())).thenAnswer((_) async {});
  when(() => games.completeGame(any())).thenAnswer((_) async {});
  when(() => achievements.evaluateSpecialActions(any())).thenReturn(0);
  when(() => achievements.evaluatePostGame(any(), any())).thenReturn(0);
  when(() => missions.recordGameResult(any(),
      isWin: any(named: 'isWin'),
      isOnline: any(named: 'isOnline'),
      currentStreak: any(named: 'currentStreak'))).thenAnswer((_) async {});
  final theme = ThemeBloc(), settings = SettingsBloc();
  final loaded = settings.stream.firstWhere((state) => state.isLoaded);
  settings.add(SettingsLoadEvent());
  await loaded;
  final authBloc = _AuthBloc(), multiplayer = _MultiplayerBloc();
  when(() => authBloc.state).thenReturn(const AuthAuthenticatedState(_user));
  when(() => authBloc.stream)
      .thenAnswer((_) => const Stream<AuthState>.empty());
  when(() => authBloc.isClosed).thenReturn(false);
  when(() => multiplayer.state).thenReturn(const MultiplayerState());
  when(() => multiplayer.stream)
      .thenAnswer((_) => const Stream<MultiplayerState>.empty());
  final game = GameBloc(games, auth, _Puzzles(), theme, achievements, missions);
  final difficulties = _requestedDifficulty
      .split(',')
      .map((name) => AIDifficulty.values.byName(name))
      .toList();
  runApp(MultiBlocProvider(
      providers: [
        BlocProvider<AuthBloc>.value(value: authBloc),
        BlocProvider<MultiplayerBloc>.value(value: multiplayer),
        BlocProvider<ThemeBloc>.value(value: theme),
        BlocProvider<SettingsBloc>.value(value: settings),
        BlocProvider<GameBloc>.value(value: game),
      ],
      child: MaterialApp(
          debugShowCheckedModeBanner: false,
          home: _Soak(game: game, difficulties: difficulties, saved: saved))));
}

class _Soak extends StatefulWidget {
  final GameBloc game;
  final List<AIDifficulty> difficulties;
  final Map<String, GameModel> saved;
  const _Soak(
      {required this.game, required this.difficulties, required this.saved});
  @override
  State<_Soak> createState() => _SoakState();
}

class _SoakState extends State<_Soak> {
  final _results = <Map<String, dynamic>>[];
  final _pauses = <Map<String, dynamic>>[];
  String _label = 'Starting browser gameplay integration';
  GameBloc get game => widget.game;
  GameConfig _config(AIDifficulty difficulty) => GameConfig(
      mode: GameMode.singlePlayer,
      difficulty: difficulty,
      difficultyLevel: difficulty == AIDifficulty.advanced ? 67 : 15,
      playerColor: 'white');
  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addPostFrameCallback((_) => _run());
  }

  Future<GameState> _wait(bool Function(GameState) predicate,
      {int seconds = 35}) async {
    if (predicate(game.state)) return game.state;
    return game.stream
        .firstWhere((state) => predicate(state) || state.engineError != null)
        .timeout(Duration(seconds: seconds));
  }

  Future<void> _run() async {
    try {
      for (final difficulty in widget.difficulties) {
        await _wait((s) =>
            s.aiDifficulty == widget.difficulties.first &&
            s.currentFEN.isNotEmpty);
        if (game.state.aiDifficulty != difficulty ||
            game.state.moveHistory.isNotEmpty) {
          game.add(GameStartEvent(_config(difficulty)));
          await _wait((s) =>
              s.aiDifficulty == difficulty &&
              s.moveHistory.isEmpty &&
              !s.isAIThinking);
        }
        await Future<void>.delayed(const Duration(milliseconds: 100));
        var replies = 0, games = 1, consecutive = 0, longest = 0;
        while (replies < _targetReplies + 1) {
          final before = game.state;
          _require(before.engineError == null,
              'Unexpected engine error: ${before.engineError}');
          if (before.isGameOver) {
            _require(
                games < 6, 'Too many short games before reaching reply target');
            games++;
            consecutive = 0;
            game.add(GameStartEvent(_config(difficulty)));
            await _wait((s) => s.moveHistory.isEmpty && !s.isGameOver);
            await Future<void>.delayed(const Duration(milliseconds: 100));
            continue;
          }
          _require(
              before.currentTurn == PieceColor.white && !before.isAIThinking,
              'Expected a settled human turn');
          final board = ChessEngine.fromFEN(before.currentFEN);
          // Only the test's human move policy uses local Dart analysis. The
          // opponent always follows the real controller and selected worker.
          final options = await AIEngine.getTopMoves(
              board, AIDifficulty.impossible,
              count: 3, timeout: const Duration(milliseconds: 700));
          final move = options.isNotEmpty
              ? options.first.$1
              : board.allLegalMoves().first;
          _require(board.makeMove(move),
              'Human test policy returned an illegal move');
          final expectedAfterHuman = board.toFEN();
          final initialPly = before.moveHistory.length;
          final timer = Stopwatch()..start();
          final replyFuture = _wait((s) =>
              s.isGameOver ||
              (s.moveHistory.length >= initialPly + 2 &&
                  s.currentTurn == PieceColor.white &&
                  !s.isAIThinking));
          game.add(
              GameMakeMoveEvent(move.from, move.to, promotion: move.promotion));
          final after = await replyFuture;
          _require(after.engineError == null,
              '${difficulty.name} stalled: ${after.engineError}');
          if (after.moveHistory.length == initialPly + 1 && after.isGameOver)
            continue;
          _require(after.moveHistory.length == initialPly + 2,
              'Expected exactly one AI reply');
          final ai = after.moveHistory.last;
          final verifier = ChessEngine.fromFEN(expectedAfterHuman);
          _require(verifier.makeMove(Move.fromAlgebraic(ai.toAlgebraic())),
              'AI reply is illegal from the actual human position');
          _require(verifier.toFEN() == after.currentFEN,
              'Applied AI reply/FEN mismatch');
          _require(after.aiDifficulty == difficulty,
              'Difficulty changed during the game');
          final diagnostics = game.engineController.diagnostics;
          _require(
              diagnostics['difficulty'] == difficulty.name &&
                  diagnostics['ownsBridge'] == true,
              'Diagnostics bridge did not return the current controller ownership/difficulty');
          final source = after.lastAIMoveSource;
          _require(
              source ==
                  (difficulty == AIDifficulty.advanced
                      ? 'stockfish'
                      : 'sunfish'),
              'Expected actual selected worker, got $source');
          replies++;
          consecutive++;
          if (consecutive > longest) longest = consecutive;
          _results.add({
            'difficulty': difficulty.name,
            'reply': replies,
            'game': games,
            'ply': after.moveHistory.length,
            'uci': ai.toAlgebraic(),
            'source': source,
            'latencyMs': timer.elapsedMilliseconds,
            'diagnostics': diagnostics,
            'fen': after.currentFEN
          });
          _label =
              '${difficulty.name}: $replies / $_targetReplies actual worker replies';
          if (mounted) setState(() {});
          _publish({'done': false, 'progress': _label, 'last': _results.last});
          if (consecutive == _targetReplies && !after.isGameOver)
            await _pauseResume(difficulty);
        }
        _require(longest >= _targetReplies,
            'No single game reached $_targetReplies worker replies; longest=$longest');
        _publish({
          'done': false,
          'completedDifficulty': difficulty.name,
          'replies': replies,
          'games': games,
          'longestConsecutiveReplies': longest
        });
      }
      _publish({
        'done': true,
        'passed': true,
        'results': _results,
        'pauses': _pauses,
        'scope':
            'Real rendered GameScreen/GameBloc/controller/coach/workers; fake account/storage/progression; untimed games; human moves injected as legal GameMakeMoveEvent'
      });
    } catch (error, stack) {
      _publish({
        'done': true,
        'passed': false,
        'error': error.toString(),
        'stack': stack.toString(),
        'state': {
          'fen': game.state.currentFEN,
          'thinking': game.state.isAIThinking,
          'ply': game.state.moveHistory.length,
          'difficulty': game.state.aiDifficulty?.name,
          'engineError': game.state.engineError
        },
        'results': _results,
        'pauses': _pauses
      });
    }
  }

  Future<void> _pauseResume(AIDifficulty difficulty) async {
    final before = game.state;
    game.add(GameSaveEvent());
    await Future<void>.delayed(const Duration(milliseconds: 100));
    final saved =
        widget.saved.values.where((g) => g.fen == before.currentFEN).toList();
    _require(saved.isNotEmpty, 'No saved snapshot for pause/resume');
    final snapshot = saved.last;
    game.add(GameExitEvent());
    await Future<void>.delayed(const Duration(seconds: 2));
    game.add(GameResumeEvent(snapshot.id));
    await _wait((s) =>
        s.currentFEN == snapshot.fen &&
        s.aiDifficulty == difficulty &&
        !s.isAIThinking);
    await Future<void>.delayed(const Duration(milliseconds: 100));
    _require(
        game.state.aiDifficulty == difficulty, 'Resume changed difficulty');
    _pauses.add({
      'difficulty': difficulty.name,
      'fenPreserved': game.state.currentFEN == before.currentFEN,
      'difficultyPreserved': game.state.aiDifficulty == difficulty,
      'pliesBefore': before.moveHistory.length,
      'pliesAfter': game.state.moveHistory.length
    });
    _publish({'done': false, 'pauseResume': _pauses.last});
  }

  @override
  Widget build(BuildContext context) => Stack(children: [
        GameScreen(config: _config(widget.difficulties.first)),
        Positioned(
            top: 4,
            left: 8,
            right: 8,
            child: IgnorePointer(
                child: Material(
                    color: Colors.black87,
                    child: Padding(
                        padding: const EdgeInsets.all(4),
                        child: Text(_label,
                            style: const TextStyle(
                                color: Colors.white, fontSize: 12)))))),
      ]);
}
