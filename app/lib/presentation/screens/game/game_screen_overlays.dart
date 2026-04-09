part of 'game_screen.dart';

extension _GameScreenOverlays on _GameScreenState {
  Widget _buildGameOverOverlay(BuildContext context, GameState state) {
    if (!state.isGameOver) return const SizedBox.shrink();

    if (_showCheckmateIntro && !_showGameOverDetails) {
      return _buildCheckmateIntroOverlay(state);
    }

    if (!_showGameOverDetails) {
      return const SizedBox.shrink();
    }

    return GameOverOverlay(
      result: state.result,
      drawReason: state.drawReason,
      playerColor: state.playerColor,
      puzzle: state.puzzle,
      gameMode: state.mode,
      opponentName: state.opponentName,
      moveCount: state.moveHistory.length,
      accuracy: state.accuracy,
      opponentAccuracy: state.opponentAccuracy,
      mistakes: state.mistakes,
      opponentMistakes: state.opponentMistakes,
      blunders: state.blunders,
      opponentBlunders: state.opponentBlunders,
      xpGained: state.xpGained,
      xpReward: state.xpReward,
      xpPenalty: state.xpPenalty,
      analysisMessage: state.analysisMessage,
      evalHistory: state.evalHistory,
      eloChange: state.eloChange,
      currentElo: 1200, // Will be updated from user model
      bestMoves: state.bestMoves,
      onPlayAgain: () {
        if (state.mode == GameMode.puzzle) {
          context.read<GameBloc>().add(const GamePuzzleNextEvent());
        } else {
          context.read<GameBloc>().add(GameStartEvent(widget.config));
        }
      },
      onGoHome: () => context.go('/home'),
      onShare: () => context.read<GameBloc>().add(GameSaveEvent()),
    );
  }

  Widget _buildCheckmateIntroOverlay(GameState state) {
    final didPlayerWin = (state.result == GameResult.whiteWins &&
            state.playerColor == PieceColor.white) ||
        (state.result == GameResult.blackWins &&
            state.playerColor == PieceColor.black);

    final title = state.result == GameResult.draw
        ? 'GAME OVER'
        : (didPlayerWin ? 'CHECKMATE!' : 'CHECKMATE!');

    final subtitle = state.result == GameResult.draw
        ? 'Game finished. Review the final position...'
        : (didPlayerWin
            ? 'You delivered checkmate. Review the board...'
            : 'You are checkmated. Review the board...');

    return Positioned(
      top: 96,
      left: 16,
      right: 16,
      child: IgnorePointer(
        ignoring: true,
        child: Center(
          child: Container(
            constraints: const BoxConstraints(maxWidth: 520),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.midnight.withValues(alpha: 0.9),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: didPlayerWin
                    ? AppTheme.goldPrimary.withValues(alpha: 0.7)
                    : AppTheme.accentRed.withValues(alpha: 0.7),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: Colors.black.withValues(alpha: 0.35),
                  blurRadius: 16,
                  offset: const Offset(0, 8),
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  title,
                  style: GoogleFonts.fredoka(
                    color: didPlayerWin
                        ? AppTheme.goldPrimary
                        : AppTheme.accentRed,
                    fontSize: 30,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.6,
                  ),
                ),
                const SizedBox(height: 6),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    color: AppTheme.textSecondary,
                    fontSize: 13,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 240.ms)
              .slideY(begin: -0.12, end: 0, duration: 240.ms),
        ),
      ),
    );
  }

  Widget _buildPromotionOverlay(BuildContext context, GameState state) {
    if (!state.showPromotionDialog) return const SizedBox.shrink();

    return PromotionDialog(
      color: state.currentTurn,
      onSelect: (type) {
        context.read<GameBloc>().add(GameMakeMoveEvent(
              state.promotionFrom!,
              state.promotionTo!,
              promotion: type,
            ));
      },
    );
  }

  Widget _buildCheckAlert(GameState state, bool minimalMotion) {
    if (state.status != GameStatus.check) return const SizedBox.shrink();

    return Positioned(
      top: 100,
      left: 0,
      right: 0,
      child: IgnorePointer(
        child: Center(
          child: Container(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
            decoration: BoxDecoration(
              color: AppTheme.accentRed.withValues(alpha: 0.95),
              borderRadius: BorderRadius.circular(28),
              boxShadow: [
                BoxShadow(
                    color: AppTheme.accentRed.withValues(alpha: 0.5),
                    blurRadius: 24,
                    spreadRadius: 4),
              ],
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
                const SizedBox(width: 10),
                Text('⚠️ CHECK!',
                    style: GoogleFonts.fredoka(
                      color: Colors.white,
                      fontWeight: FontWeight.w800,
                      fontSize: 20,
                    )),
              ],
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .fadeIn(duration: 400.ms)
              .then()
              .fadeOut(duration: 400.ms),
        ),
      ),
    );
  }

  Widget _buildConfetti() {
    return Align(
      alignment: Alignment.topCenter,
      child: ConfettiWidget(
        confettiController: _confettiController,
        blastDirectionality: BlastDirectionality.explosive,
        colors: const [
          AppTheme.goldPrimary,
          AppTheme.accentCyan,
          AppTheme.accentPurple,
          AppTheme.accentGreen,
        ],
        numberOfParticles: 40,
        gravity: 0.2,
      ),
    );
  }
}
