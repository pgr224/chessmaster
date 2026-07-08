part of 'game_screen.dart';

extension _GameScreenOverlays on _GameScreenState {
  Widget _buildGameOverOverlay(BuildContext context, GameState state) {
    if (!state.isGameOver) return const SizedBox.shrink();

    final isLearningMode =
        state.mode == GameMode.tutorial || state.mode == GameMode.puzzle;
    if (isLearningMode) {
      return _buildLearningCompletionOverlay(context, state);
    }

    if (_showCheckmateIntro && !_showGameOverDetails) {
      return _buildCheckmateIntroOverlay(state);
    }

    if (!_showGameOverDetails) {
      return const SizedBox.shrink();
    }

    return GameOverOverlay(
      result: state.result,
      drawReason: state.drawReason,
      gameReason: state.gameReason,
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

  Widget _buildLearningCompletionOverlay(BuildContext context, GameState state) {
    final isPuzzle = state.mode == GameMode.puzzle;
    final gaveUp = state.puzzleGaveUp;
    final title = isPuzzle
        ? (gaveUp ? 'Nice Try!' : 'Puzzle Solved!')
        : 'Lesson Complete!';
    final subtitle = isPuzzle
        ? (gaveUp
            ? 'You learned the idea. Try another puzzle and keep building pattern power.'
            : 'Great pattern recognition. Keep the momentum going with another challenge.')
        : 'You finished this tutorial step-by-step. Keep going, you are improving fast.';

    return Stack(
      children: [
        Container(color: Colors.black.withValues(alpha: 0.55)),
        Positioned(
          left: 0,
          right: 0,
          bottom: 0,
          child: Container(
            margin: const EdgeInsets.all(14),
            padding: const EdgeInsets.fromLTRB(20, 22, 20, 18),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(24),
              border: Border.all(
                color: AppTheme.accentCyan.withValues(alpha: 0.55),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: AppTheme.accentCyan.withValues(alpha: 0.18),
                  blurRadius: 24,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentCyan.withValues(alpha: 0.12),
                    shape: BoxShape.circle,
                  ),
                  child: Text(
                    isPuzzle ? (gaveUp ? '🧠' : '🎉') : '🎓',
                    style: const TextStyle(fontSize: 34),
                  ),
                ),
                const SizedBox(height: 12),
                Text(
                  title,
                  style: GoogleFonts.fredoka(
                    color: AppTheme.accentCyan,
                    fontSize: 28,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 1.1,
                  ),
                ),
                const SizedBox(height: 8),
                Text(
                  subtitle,
                  textAlign: TextAlign.center,
                  style: GoogleFonts.baloo2(
                    color: AppTheme.textPrimary,
                    fontSize: 14,
                    fontWeight: FontWeight.w600,
                    height: 1.35,
                  ),
                ),
                if ((state.tutorialMessage ?? '').trim().isNotEmpty) ...[
                  const SizedBox(height: 10),
                  Container(
                    width: double.infinity,
                    padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
                    decoration: BoxDecoration(
                      color: Colors.black.withValues(alpha: 0.16),
                      borderRadius: BorderRadius.circular(12),
                    ),
                    child: Text(
                      state.tutorialMessage!,
                      textAlign: TextAlign.center,
                      style: GoogleFonts.baloo2(
                        color: AppTheme.textSecondary,
                        fontSize: 12,
                        fontWeight: FontWeight.w500,
                      ),
                    ),
                  ),
                ],
                const SizedBox(height: 14),
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton.icon(
                        onPressed: () => context.go('/home'),
                        icon: const Icon(Icons.home_rounded, size: 18),
                        label: Text(
                          'Home',
                          style: GoogleFonts.fredoka(
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: BorderSide(
                            color: AppTheme.textMuted.withValues(alpha: 0.4),
                          ),
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                        ),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      flex: 2,
                      child: ElevatedButton.icon(
                        onPressed: () {
                          if (isPuzzle) {
                            context
                                .read<GameBloc>()
                                .add(const GamePuzzleNextEvent());
                          } else {
                            context.go('/learn');
                          }
                        },
                        icon: Icon(
                          isPuzzle
                              ? Icons.skip_next_rounded
                              : Icons.school_rounded,
                          size: 20,
                        ),
                        label: Text(
                          isPuzzle ? 'NEXT PUZZLE' : 'CONTINUE LEARNING',
                          style: GoogleFonts.fredoka(
                            fontWeight: FontWeight.w800,
                            letterSpacing: 0.8,
                          ),
                        ),
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentCyan,
                          foregroundColor: AppTheme.midnight,
                          padding: const EdgeInsets.symmetric(vertical: 12),
                          shape: RoundedRectangleBorder(
                            borderRadius: BorderRadius.circular(14),
                          ),
                          elevation: 8,
                        ),
                      ),
                    ),
                  ],
                ),
              ],
            ),
          )
              .animate()
              .fadeIn(duration: 260.ms)
              .slideY(begin: 0.08, end: 0, duration: 260.ms),
        ),
      ],
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

    final themeState = context.watch<ThemeBloc>().state;
    final settings = context.watch<SettingsBloc>().state;

    final PieceColor perspective;
    if (state.mode == GameMode.multiplayer && state.playerColor != null) {
      perspective = state.playerColor!;
    } else if (settings.autoFlipBoard) {
      perspective = state.currentTurn;
    } else {
      perspective = state.playerColor ?? PieceColor.white;
    }

    final bool shouldRotate = state.mode == GameMode.twoPlayer && state.currentTurn != perspective;

    Widget dialog = PromotionDialog(
      color: state.currentTurn,
      shape: themeState.pieceShape,
      style: themeState.pieceStyle,
      whitePieceColor: state.whitePieceColor,
      blackPieceColor: state.blackPieceColor,
      onSelect: (type) {
        context.read<GameBloc>().add(GameMakeMoveEvent(
              state.promotionFrom!,
              state.promotionTo!,
              promotion: type,
            ));
      },
    );

    if (shouldRotate) {
      dialog = RotatedBox(quarterTurns: 2, child: dialog);
    }

    return dialog;
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

