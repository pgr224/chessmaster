import '../../domain/engine/chess_engine.dart';
import '../blocs/game/game_bloc.dart';
import '../blocs/multiplayer/multiplayer_bloc.dart';

/// Feedback follows gameplay transitions, never clock or analysis updates.
({
  bool gameEnded,
  bool movePlayed,
  bool checkStarted,
  bool puzzleSolved,
  bool puzzleMistake
}) gameFeedbackChanges(GameState previous, GameState current) {
  return (
    gameEnded: !previous.isGameOver && current.isGameOver,
    movePlayed: current.moveHistory.length > previous.moveHistory.length,
    checkStarted: current.status == GameStatus.check &&
        (previous.status != GameStatus.check ||
            previous.currentFEN != current.currentFEN),
    puzzleSolved:
        current.showPuzzleCelebration && !previous.showPuzzleCelebration,
    puzzleMistake: (current.tutorialMessage?.startsWith('❌') ?? false) &&
        current.tutorialMessage != previous.tutorialMessage,
  );
}

({bool drawOffered, bool saveRequested, bool gameEnded, bool disconnected})
    multiplayerPromptChanges(
        MultiplayerState previous, MultiplayerState current) {
  final newGame = previous.gameId != current.gameId;
  return (
    drawOffered: current.drawOfferPending &&
        (!previous.drawOfferPending || newGame) &&
        current.status == MultiplayerStatus.inGame,
    saveRequested: current.saveOfferPending &&
        (!previous.saveOfferPending || newGame) &&
        current.status == MultiplayerStatus.inGame,
    gameEnded: current.status == MultiplayerStatus.gameOver &&
        current.gameReason != null &&
        (previous.status != MultiplayerStatus.gameOver ||
            previous.gameReason == null ||
            newGame),
    disconnected: current.status == MultiplayerStatus.disconnected &&
        previous.status != MultiplayerStatus.disconnected,
  );
}

bool multiplayerHasLowTime(MultiplayerState state) =>
    (state.whiteTime > 0 && state.whiteTime <= 30) ||
    (state.blackTime > 0 && state.blackTime <= 30);

/// The room shell contains stable game configuration; clocks and chat have
/// their own listeners inside it.
bool shouldRebuildGameRoom(
        MultiplayerState previous, MultiplayerState current) =>
    previous.status != current.status ||
    previous.gameId != current.gameId ||
    previous.opponentConnected != current.opponentConnected ||
    previous.opponentName != current.opponentName ||
    previous.playerColor != current.playerColor ||
    previous.timeControl != current.timeControl ||
    previous.variantId != current.variantId;

bool shouldListenForRoomNotices(
        MultiplayerState previous, MultiplayerState current) =>
    previous.status != current.status ||
    previous.gameId != current.gameId ||
    previous.gameReason != current.gameReason ||
    previous.drawOfferPending != current.drawOfferPending ||
    previous.saveOfferPending != current.saveOfferPending ||
    previous.opponentUndoCount != current.opponentUndoCount ||
    previous.chatMessages.length != current.chatMessages.length ||
    multiplayerHasLowTime(previous) != multiplayerHasLowTime(current);
