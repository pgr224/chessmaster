part of 'game_screen.dart';

extension GameScreenControls on _GameScreenState {
  Widget _buildActionBar(BuildContext context, GameState state) {
    final settings = context.watch<SettingsBloc>().state;
    final isPracticeOrSingle = state.mode == GameMode.singlePlayer ||
        state.mode == GameMode.practice ||
        state.mode == GameMode.twoPlayer;
    final isMultiplayer = state.mode == GameMode.multiplayer;
    final isPuzzle = state.mode == GameMode.puzzle;

    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: AppTheme.deepSpace.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 20,
              offset: const Offset(0, -4)),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        runSpacing: 8,
        spacing: 6,
        children: [
          // Puzzle specific buttons
          if (isPuzzle && !state.isGameOver)
            _actionBtn(
              icon: Icons.flag_rounded,
              label: 'Give Up',
              color: AppTheme.accentRed,
              onTap: () =>
                  context.read<GameBloc>().add(const GamePuzzleGiveUpEvent()),
              width: 78,
            ),
          if (isPuzzle && state.isGameOver)
            _actionBtn(
              icon: Icons.skip_next_rounded,
              label: 'Next Puzzle',
              color: AppTheme.accentCyan,
              onTap: () =>
                  context.read<GameBloc>().add(const GamePuzzleNextEvent()),
              width: 90,
            ),

          // Hint button
          if (isPracticeOrSingle || isPuzzle || isMultiplayer)
            _actionBtn(
              icon: Icons.lightbulb_rounded,
              label: isPuzzle
                  ? 'Hint (10XP)'
                  : state.mode == GameMode.practice
                      ? 'Hint ∞'
                      : 'Hint',
              color: AppTheme.goldPrimary,
              onTap: !state.isGameOver &&
                      (state.isPlayerTurn ||
                          state.mode == GameMode.practice ||
                          state.mode == GameMode.twoPlayer) &&
                      !state.isAIThinking
                  ? () => context.read<GameBloc>().add(const GameRequestHintEvent())
                  : null,
            ),

          if (isPuzzle)
            _actionBtn(
              icon: Icons.psychology_rounded,
              label: 'Explain',
              color: AppTheme.skyBlue,
              onTap: () {
                if (state.puzzleStep < 0 ||
                    state.puzzleStep >= state.parsedPuzzleMoves.length) {
                  return;
                }

                final parsedMove = state.parsedPuzzleMoves[state.puzzleStep];
                if (parsedMove == null) return;
                context.read<GameBloc>().add(GameExplainMoveEvent(
                      move: parsedMove,
                      fen: state.currentFEN,
                    ));
              },
            ),
          // Undo
          if (isPracticeOrSingle || isMultiplayer)
            _actionBtn(
              icon: Icons.undo_rounded,
              label: state.mode == GameMode.practice ? 'Undo ∞' : 'Undo',
              color: AppTheme.skyBlue,
              onTap: (isPracticeOrSingle &&
                          state.moveHistory.isNotEmpty &&
                          !state.isGameOver) ||
                      state.canMpUndo
                  ? () => context.read<GameBloc>().add(GameUndoEvent())
                  : null,
            ),
          // Resign (not for puzzles)
          if (!isPuzzle)
            _actionBtn(
              icon: Icons.flag_rounded,
              label: 'Resign',
              color: AppTheme.accentRed,
              onTap: !state.isGameOver
                  ? () => _resign(context, settings.confirmResign)
                  : null,
              width: isMultiplayer ? 70 : 80,
            ),

          // Coach Settings
          if (state.mode == GameMode.practice)
            _actionBtn(
              icon: Icons.face_rounded,
              label: 'Coach',
              color: AppTheme.accentPurple,
              onTap: () => _showCoachSettings(context, state),
            ),
        ],
      ),
    );
  }

  Widget _buildMoveHistoryCard(GameState state) {
    if (state.moveHistory.isEmpty) return const SizedBox.shrink();

    return Container(
      height: 220,
      padding: const EdgeInsets.all(12),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            'Recent Moves',
            style: GoogleFonts.fredoka(
                color: AppTheme.skyBlue,
                fontSize: 18,
                fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Expanded(
            child: MoveHistoryWidget(
              moves: state.moveHistory,
              currentFen: state.currentFEN,
            ),
          ),
        ],
      ),
    );
  }

  Widget _actionBtn({
    required IconData icon,
    required String label,
    Color? color,
    VoidCallback? onTap,
    double? width,
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        width: width ?? 78,
        padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 8),
        decoration: BoxDecoration(
          color: onTap != null
              ? (color ?? AppTheme.textSecondary).withValues(alpha: 0.1)
              : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon,
                color: onTap != null
                    ? (color ?? AppTheme.textSecondary)
                    : AppTheme.textMuted,
                size: 22),
            const SizedBox(height: 4),
            Text(label,
                style: GoogleFonts.fredoka(
                  color: onTap != null
                      ? (color ?? AppTheme.textSecondary)
                      : AppTheme.textMuted,
                  fontSize: 10,
                  fontWeight: FontWeight.w600,
                ),
                textAlign: TextAlign.center,
                maxLines: 1,
                overflow: TextOverflow.ellipsis),
          ],
        ),
      ),
    );
  }

  void _showCoachSettings(BuildContext context, GameState state) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(
              color: AppTheme.accentPurple.withValues(alpha: 0.3), width: 2),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  padding: const EdgeInsets.all(12),
                  decoration: BoxDecoration(
                    color: AppTheme.accentPurple.withValues(alpha: 0.2),
                    shape: BoxShape.circle,
                  ),
                  child: const Icon(Icons.face_rounded,
                      color: AppTheme.accentPurple, size: 28),
                ),
                const SizedBox(width: 16),
                Text(
                  'AI Coach Settings',
                  style: GoogleFonts.fredoka(
                      color: AppTheme.textPrimary,
                      fontSize: 24,
                      fontWeight: FontWeight.bold),
                ),
                const Spacer(),
                IconButton(
                  onPressed: () => Navigator.pop(ctx),
                  icon: const Icon(Icons.close_rounded,
                      color: AppTheme.textMuted),
                ),
              ],
            ),
            const SizedBox(height: 24),

            // Toggle Coaching
            SwitchListTile(
              title: Text('Real-time Feedback',
                  style: GoogleFonts.fredoka(
                      color: AppTheme.textPrimary, fontSize: 18)),
              subtitle: Text('Context-aware help while playing',
                  style: GoogleFonts.baloo2(color: AppTheme.textSecondary)),
              value: state.coachSettings.enableRealTimeCoaching,
              activeThumbColor: AppTheme.accentPurple,
              onChanged: (val) {
                context.read<GameBloc>().add(GameUpdateCoachSettingsEvent(
                      state.coachSettings.copyWith(enableRealTimeCoaching: val),
                    ));
              },
            ),
            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

