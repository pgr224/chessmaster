part of 'game_screen.dart';

extension GameScreenPlayers on _GameScreenState {
  Widget _buildOpponentInfo(GameState state) {
    final multiplayerState = context.watch<MultiplayerBloc>().state;
    final bool isMultiplayer = state.mode == GameMode.multiplayer;
    final bool isWhite = state.playerColor == PieceColor.white;

    // Resolve opponent info
    String opponentName = 'Robot Master';
    String? opponentAvatar;
    String? opponentLocal;
    bool isOpponentThinking = false;

    if (isMultiplayer && multiplayerState.opponentName != null) {
      opponentName = multiplayerState.opponentName!;
      opponentAvatar = multiplayerState.opponentAvatarUrl;
      opponentLocal = multiplayerState.opponentLocalAvatar;
      isOpponentThinking = state.currentTurn != state.playerColor;
    } else {
      opponentName = _aiName(state.aiDifficulty);
      isOpponentThinking = state.currentTurn != state.playerColor &&
          state.status == GameStatus.active;
    }

    return PlayerInfoWidget(
      name: opponentName,
      color: isWhite ? PieceColor.black : PieceColor.white,
      isActive: state.currentTurn != state.playerColor,
      isAI: !isMultiplayer,
      isThinking: isOpponentThinking,
      avatarUrl: opponentAvatar,
      localAvatar: opponentLocal,
    );
  }

  Widget _buildPlayerInfo(GameState state) {
    final authState = context.watch<AuthBloc>().state;

    // Resolve player info
    String playerName = 'You';
    String? playerAvatar;
    String? playerLocal;

    if (authState is AuthAuthenticatedState) {
      playerName = authState.user.username;
      playerAvatar = authState.user.avatarUrl;
      playerLocal = authState.user.localAvatar;
    }

    return PlayerInfoWidget(
      name: playerName,
      color: state.playerColor ?? PieceColor.white,
      isActive: state.currentTurn == state.playerColor,
      isAI: false,
      isThinking: false,
      avatarUrl: playerAvatar,
      localAvatar: playerLocal,
    );
  }

  Widget _buildCapturedPieces(GameState state, PieceColor color) {
    final captured = color == PieceColor.white ? state.capturedWhite : state.capturedBlack;
    if (captured.isEmpty) return const SizedBox.shrink();

    return CapturedPiecesWidget(
      pieces: captured,
      color: color,
    );
  }

  String _aiName(AIDifficulty? difficulty) => switch (difficulty) {
        AIDifficulty.basic => 'Junior Bot',
        AIDifficulty.intermediate => 'Master Deep',
        AIDifficulty.advanced => 'Grandmaster AI',
        AIDifficulty.impossible => 'The Machine',
        AIDifficulty.aiMode => 'Neural Mind',
        null => 'Grandmaster AI',
      };
}
