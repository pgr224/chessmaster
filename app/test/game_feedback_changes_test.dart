import 'package:chess_master/domain/engine/chess_engine.dart';
import 'package:chess_master/presentation/blocs/game/game_bloc.dart';
import 'package:chess_master/presentation/blocs/multiplayer/multiplayer_bloc.dart';
import 'package:chess_master/presentation/utils/game_feedback_changes.dart';
import 'package:flutter_test/flutter_test.dart';

GameState _game() => GameState(
      board: List.generate(8, (_) => List<ChessPiece?>.filled(8, null)),
      currentTurn: PieceColor.white,
    );

void main() {
  test('clock and evaluation updates do not replay move or check feedback', () {
    final initial = _game();
    var previous = initial.copyWith(
      moveHistory: [Move.fromAlgebraic('e2e4')],
      status: GameStatus.check,
      currentFEN: 'checked position',
    );
    final first = gameFeedbackChanges(initial, previous);
    expect(first.movePlayed, isTrue);
    expect(first.checkStarted, isTrue);

    for (var tick = 1; tick <= 100; tick++) {
      final current = previous.copyWith(
        whiteTimeMs: 60000.0 - tick * 100,
        evalScore: tick / 10,
      );
      expect(gameFeedbackChanges(previous, current), (
        gameEnded: false,
        movePlayed: false,
        checkStarted: false,
        puzzleSolved: false,
        puzzleMistake: false,
      ));
      previous = current;
    }

    // A later checking move still receives feedback, even if the status stays check.
    final nextMove = previous.copyWith(
      moveHistory: [...previous.moveHistory, Move.fromAlgebraic('e7e5')],
      currentFEN: 'next checked position',
    );
    expect(gameFeedbackChanges(previous, nextMove).movePlayed, isTrue);
    expect(gameFeedbackChanges(previous, nextMove).checkStarted, isTrue);
  });

  test('post-game analysis does not replay completion feedback', () {
    final initial = _game();
    final ended = initial.copyWith(
      status: GameStatus.checkmate,
      result: GameResult.whiteWins,
    );
    expect(gameFeedbackChanges(initial, ended).gameEnded, isTrue);
    final analyzed = ended.copyWith(xpGained: 100, accuracy: 91.0);
    expect(gameFeedbackChanges(ended, analyzed).gameEnded, isFalse);
    final nextGame = _game();
    expect(gameFeedbackChanges(analyzed, nextGame).gameEnded, isFalse);
    expect(gameFeedbackChanges(nextGame, ended).gameEnded, isTrue);
  });

  test('puzzle feedback fires again for a new solve or mistake, never a tick',
      () {
    final initial = _game();
    final mistake = initial.copyWith(tutorialMessage: '❌ Try again');
    expect(gameFeedbackChanges(initial, mistake).puzzleMistake, isTrue);
    expect(
        gameFeedbackChanges(mistake, mistake.copyWith(whiteTimeMs: 50000))
            .puzzleMistake,
        isFalse);
    final retry = mistake.copyWith(tutorialMessage: 'Your turn');
    expect(gameFeedbackChanges(retry, mistake).puzzleMistake, isTrue);
    final solved = initial.copyWith(showPuzzleCelebration: true);
    expect(gameFeedbackChanges(initial, solved).puzzleSolved, isTrue);
    expect(
        gameFeedbackChanges(solved, solved.copyWith(totalPuzzleXP: 50))
            .puzzleSolved,
        isFalse);
  });

  test('draw and save dialogs open once per received offer', () {
    const initial = MultiplayerState(
      status: MultiplayerStatus.inGame,
      gameId: 'first',
      whiteTime: 60,
    );
    final offer =
        initial.copyWith(drawOfferPending: true, saveOfferPending: true);
    final received = multiplayerPromptChanges(initial, offer);
    expect(received.drawOffered, isTrue);
    expect(received.saveRequested, isTrue);
    var previous = offer;
    for (var tick = 1; tick < 50; tick++) {
      final current = previous.copyWith(whiteTime: 60.0 - tick);
      final changes = multiplayerPromptChanges(previous, current);
      expect(changes.drawOffered, isFalse);
      expect(changes.saveRequested, isFalse);
      previous = current;
    }
    final declined =
        previous.copyWith(drawOfferPending: false, saveOfferPending: false);
    expect(multiplayerPromptChanges(declined, offer).drawOffered, isTrue);
    expect(multiplayerPromptChanges(declined, offer).saveRequested, isTrue);
    final ended = offer.copyWith(
        status: MultiplayerStatus.gameOver, gameReason: 'checkmate');
    expect(multiplayerPromptChanges(initial, ended).drawOffered, isFalse);
    expect(multiplayerPromptChanges(initial, ended).saveRequested, isFalse);
  });

  test('network ending is announced once, including deferred reason', () {
    const initial =
        MultiplayerState(status: MultiplayerStatus.inGame, gameId: 'first');
    final ending = initial.copyWith(status: MultiplayerStatus.gameOver);
    expect(multiplayerPromptChanges(initial, ending).gameEnded, isFalse);
    final ended = ending.copyWith(gameReason: 'disconnect_timeout');
    expect(multiplayerPromptChanges(ending, ended).gameEnded, isTrue);
    expect(
        multiplayerPromptChanges(ended, ended.copyWith(xpGained: 100))
            .gameEnded,
        isFalse);
    expect(
        multiplayerPromptChanges(ended, ended.copyWith(gameId: 'second'))
            .gameEnded,
        isTrue);
  });

  test(
      'room shell skips clock rebuilds while preserving notices and configuration',
      () {
    const initial = MultiplayerState(
      status: MultiplayerStatus.inGame,
      gameId: 'first',
      whiteTime: 31,
      blackTime: 60,
    );
    final lowTime = initial.copyWith(whiteTime: 30);
    expect(shouldRebuildGameRoom(initial, lowTime), isFalse);
    expect(shouldListenForRoomNotices(initial, lowTime), isTrue);
    final nextTick = lowTime.copyWith(whiteTime: 29);
    expect(shouldListenForRoomNotices(lowTime, nextTick), isFalse);
    expect(
        shouldListenForRoomNotices(
            nextTick, nextTick.copyWith(drawOfferPending: true)),
        isTrue);
    expect(
        shouldRebuildGameRoom(
            initial, initial.copyWith(opponentConnected: true)),
        isTrue);
    expect(
        shouldRebuildGameRoom(initial, initial.copyWith(timeControl: '10+5')),
        isTrue);
    expect(
        shouldRebuildGameRoom(
            initial, initial.copyWith(status: MultiplayerStatus.gameOver)),
        isTrue);
  });
}
