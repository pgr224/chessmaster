part of 'game_screen.dart';

extension GameScreenBoard on _GameScreenState {
  Widget _buildBoardFrame(BuildContext context, GameState state, {required double maxDimension}) {
    final dimension = math.max(300.0, math.min(maxDimension, 860.0));
    final settings = context.watch<SettingsBloc>().state;
    final themeState = context.watch<ThemeBloc>().state;

    // In multiplayer, always use playerColor for perspective (never auto-flip)
    final PieceColor perspective;
    if (state.mode == GameMode.multiplayer && state.playerColor != null) {
      perspective = state.playerColor!;
    } else if (settings.autoFlipBoard) {
      perspective = state.currentTurn;
    } else {
      perspective = state.playerColor ?? PieceColor.white;
    }

    final minimalMotion = settings.moveAnimationSpeed == 'off';

    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: dimension + 30, height: dimension),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (state.coachSettings.showEvalBar && (state.mode == GameMode.singlePlayer || state.mode == GameMode.practice)) ...[
            EvalBarWidget(
              evalScore: state.evalScore,
              perspective: perspective,
              height: dimension,
              isGameOver: state.isGameOver,
              result: state.result,
            ),
            const SizedBox(width: 8),
          ],
          Stack(
            clipBehavior: Clip.none,
            children: [
              // THE BOARD
              SizedBox(
                width: dimension,
                height: dimension,
                child: ChessBoardWidget(
                  board: state.board,
                  perspective: perspective,
                  selectedSquare: state.selectedSquare,
                  legalMoves: settings.showLegalMoves ? state.legalMoves : const [],
                  lastMove: state.moveHistory.isNotEmpty ? state.moveHistory.last : null,
                  hintMove: state.hintMove,
                  status: state.status,
                  boardTheme: themeState.boardTheme,
                  pieceShape: themeState.pieceShape,
                  pieceStyle: themeState.pieceStyle,
                  moveAnimationSpeed: settings.moveAnimationSpeed,
                  showCoordinates: settings.showCoordinates,
                  showSquareLabels: settings.showSquareLabels,
                  whitePieceColor: state.whitePieceColor,
                  blackPieceColor: state.blackPieceColor,
                  currentTurn: state.currentTurn,
                  lastUndoPenaltySquare: state.lastUndoPenaltySquare,
                  onSquareTap: state.isGameOver
                      ? null
                      : (sq) {
                          context.read<GameBloc>().add(GameSelectPieceEvent(sq));
                        },
                  isInteractive: state.mode == GameMode.multiplayer || !state.isAIThinking,
                  lastCorrectMove: state.coachMove,
                  preMove: state.preMove,
                ),
              ),

              // TURN INDICATORS
              if (!state.isGameOver)
                Positioned(
                  left: 0,
                  right: 0,
                  top: state.currentTurn == perspective ? null : -45,
                  bottom: state.currentTurn == perspective ? -45 : null,
                  child: Center(
                    child: _buildTurnOverlay(state, minimalMotion),
                  ),
                ),

              // AI COACH TALKING WINDOW
              if ((state.isAIThinking && state.mode != GameMode.practice && state.mode != GameMode.multiplayer) || state.coachFeedback != null || state.activeHint != null)
                Positioned(
                  left: -20,
                  right: -20,
                  top: state.currentTurn == perspective ? null : -130,
                  bottom: state.currentTurn == perspective ? -130 : null,
                  child: ReactingRobotWidget(state: state),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildTurnOverlay(GameState state, bool minimalMotion) {
    final isMyTurn = state.currentTurn == state.playerColor;
    if (state.isGameOver) return const SizedBox.shrink();

    final isMultiplayer = state.mode == GameMode.multiplayer;
    final opponentLabel = isMultiplayer ? 'OPPONENT\'S TURN' : 'AI THINKING...';
    final opponentIcon = isMultiplayer ? Icons.person_rounded : Icons.computer_rounded;

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: isMyTurn ? AppTheme.accentCyan.withValues(alpha: 0.2) : Colors.black45,
        borderRadius: BorderRadius.circular(12),
        border: Border.all(
          color: isMyTurn ? AppTheme.accentCyan : Colors.white24,
          width: 2,
        ),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            isMyTurn ? Icons.person_rounded : opponentIcon,
            color: isMyTurn ? AppTheme.accentCyan : Colors.white70,
            size: 18,
          ),
          const SizedBox(width: 8),
          Text(
            isMyTurn ? 'YOUR TURN' : opponentLabel,
            style: GoogleFonts.fredoka(
              color: isMyTurn ? AppTheme.accentCyan : Colors.white70,
              fontSize: 14,
              fontWeight: FontWeight.bold,
              letterSpacing: 1,
            ),
          ),
        ],
      ),
    );
  }
}
