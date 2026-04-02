import 'dart:math' as math;
import 'package:audioplayers/audioplayers.dart';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confetti/confetti.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/game_config.dart';
import '../../../data/models/tutorial_model.dart';
import '../../../presentation/blocs/game/game_bloc.dart';
import '../../../presentation/blocs/settings/settings_bloc.dart';
import '../../../presentation/blocs/multiplayer/multiplayer_bloc.dart';
import '../../../presentation/blocs/auth/auth_bloc.dart';
import '../../../presentation/blocs/theme/theme_bloc.dart';
import '../../../data/models/user_model.dart';
import '../../../domain/engine/chess_engine.dart';
import '../../widgets/chess_board_widget.dart';
import '../../widgets/captured_pieces_widget.dart';
import '../../widgets/move_history_widget.dart';
import '../../widgets/promotion_dialog.dart';
import '../../widgets/game_over_overlay.dart';
import '../../widgets/player_info_widget.dart';

import '../../widgets/coach_interaction_widget.dart';
import '../../widgets/timer_widget.dart';
import '../../widgets/game_rules_dialog.dart';
import '../../widgets/eval_bar_widget.dart';
import '../../widgets/chat_widget.dart';
import '../../../data/models/coach_model.dart';

class GameScreen extends StatefulWidget {
  final GameConfig config;
  final TutorialLesson? tutorial;
  const GameScreen({super.key, required this.config, this.tutorial});

  @override
  State<GameScreen> createState() => _GameScreenState();
}

class _GameScreenState extends State<GameScreen> with TickerProviderStateMixin {
  late ConfettiController _confettiController;
  late AnimationController _checkAnimController;
  final AudioPlayer _audioPlayer = AudioPlayer();
  Offset _chatPosition = const Offset(16, 450); // Initial floating chat position
  bool _isChatDragging = false;

  @override
  void initState() {
    super.initState();
    _confettiController =
        ConfettiController(duration: const Duration(seconds: 3));
    _checkAnimController = AnimationController(vsync: this, duration: 500.ms);

    // Sync initial settings
    final settings = context.read<SettingsBloc>().state;
    context.read<GameBloc>().add(GameUpdateSettingsEvent(
          confirmMoves: settings.confirmMoves,
          autoQueen: settings.autoQueen,
        ));

    if (widget.config.activeGameId != null) {
      context
          .read<GameBloc>()
          .add(GameResumeEvent(widget.config.activeGameId!));
    } else {
      context
          .read<GameBloc>()
          .add(GameStartEvent(widget.config, tutorial: widget.tutorial));
    }
  }

  /// Handle system back button (Android hardware or gesture back)
  /// Returns true to prevent default pop, false/null to allow
  Future<bool> _onPopInvoked(bool didPop) async {
    if (didPop) return true; // Already popped, don't do anything further
    // Show exit dialog instead of just popping
    await _showExitDialog(context);
    return true; // Prevent default pop (dialog handles nav)
  }

  @override
  void dispose() {
    context.read<GameBloc>().add(GameExitEvent());
    _confettiController.dispose();
    _checkAnimController.dispose();
    _audioPlayer.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvokedWithResult: (didPop, result) => _onPopInvoked(didPop),
      child: BlocConsumer<GameBloc, GameState>(
        listener: (context, state) {
          final settings = context.read<SettingsBloc>().state;

          if (state.isGameOver) {
            final isWin = (state.result == GameResult.whiteWins &&
                    state.playerColor == PieceColor.white) ||
                (state.result == GameResult.blackWins &&
                    state.playerColor == PieceColor.black);
            if (isWin) {
              _confettiController.play();
              if (settings.soundEnabled) {
                _audioPlayer.play(AssetSource('sounds/win.wav'));
              }
            }
          }
          if (state.showPuzzleCelebration) {
            _confettiController.play();
            if (settings.soundEnabled) {
              _audioPlayer.play(AssetSource('sounds/win.wav'));
            }
          }
          if (state.status == GameStatus.check) {
            _checkAnimController.forward(from: 0);
          }

          // Move Sound
          if (state.moveHistory.isNotEmpty) {
            if (settings.soundEnabled) {
              _audioPlayer.play(AssetSource('sounds/move.wav'));
            }
          }

          // Warning Sound for wrong puzzle moves
          if (state.tutorialMessage?.startsWith('❌') ?? false) {
            if (settings.soundEnabled) {
              _audioPlayer.play(AssetSource('sounds/warning.wav'));
            }
          }

          // Show Rules Dialog on start of Multiplayer
          if (state.mode == GameMode.multiplayer &&
              state.moveHistory.isEmpty &&
              !state.isGameOver &&
              !_didShowRules) {
            final mpState = context.read<MultiplayerBloc>().state;
            if (mpState.status == MultiplayerStatus.inGame) {
              _didShowRules = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                showDialog(
                  context: context,
                  builder: (ctx) => GameRulesDialog(
                    timeControl: mpState.timeControl ?? '30+0',
                    mode: 'Multiplayer',
                  ),
                );
              });
            }
          }

          if (state.mode != GameMode.multiplayer) {
            _didShowRules = false; // Reset for next game
          }

          // Handle Multiplayer Game Over
          if (state.mode == GameMode.multiplayer) {
            final mpState = context.read<MultiplayerBloc>().state;
            if (mpState.status == MultiplayerStatus.gameOver &&
                !state.isGameOver) {
              // Map mpResult to GameResult
              GameResult res = GameResult.ongoing;
              if (mpState.gameResult == 'white') {
                res = GameResult.whiteWins;
              } else if (mpState.gameResult == 'black') {
                res = GameResult.blackWins;
              } else if (mpState.gameResult == 'draw') {
                res = GameResult.draw;
              }

              DrawReason? reason;
              if (mpState.gameReason == 'stalemate') {
                reason = DrawReason.stalemate;
              } else if (mpState.gameReason == 'agreement') {
                reason = DrawReason.agreement;
              } else if (mpState.gameReason == 'insufficient_material') {
                reason = DrawReason.insufficientMaterial;
              }

              context
                  .read<GameBloc>()
                  .add(MpGameOverSyncEvent(res, reason, mpState.xpGained));
            }
          }
        },
        builder: (context, state) {
          final minimalMotion = context.select<SettingsBloc, bool>(
            (bloc) => bloc.state.moveAnimationSpeed == 'off',
          );
          return Scaffold(
            backgroundColor: AppTheme.midnight,
            body: LayoutBuilder(
              builder: (context, constraints) {
                return Stack(
                  children: [
                    _buildBackground(),
                    SafeArea(
                      child: constraints.maxWidth >= 1080
                          ? _buildWideLayout(context, state, constraints)
                          : _buildCompactLayout(context, state, constraints),
                    ),
                    if (state.showPromotionDialog)
                      _buildPromotionOverlay(context, state),
                    if (state.isGameOver) _buildGameOverOverlay(context, state),
                    _buildConfetti(),
                    if (state.status == GameStatus.check)
                      _buildCheckAlert(state, minimalMotion),
                    if (state.pendingMove != null)
                      _buildConfirmMoveOverlay(state),
                    if (_showMoves) _buildMoveHistoryOverlay(state),
                    if (state.isPuzzleRush) _buildPuzzleRushOverlay(state),
                    if (state.showMiniLesson && state.coachFeedback == null)
                      _buildMiniLessonOverlay(context, state),
                    // Only show floating chat on mobile/compact, wide layout has sidebar chat
                    // Universal floating chat window (all layouts)
                    if (state.mode == GameMode.multiplayer)
                      _buildFloatingChat(context),
                    if (state.puzzleExplanation != null)
                      _buildBrainExplainer(state),
                    if (state.engineError != null)
                      _buildEngineErrorOverlay(context, state),
                  ],
                );
              },
            ),
          );
        },
      ),
    );
  }

  Widget _buildMoveHistoryOverlay(GameState state) {
    return Positioned.fill(
      child: Stack(
        children: [
          GestureDetector(
            onTap: () => setState(() => _showMoves = false),
            child: Container(color: Colors.black.withValues(alpha: 0.2)),
          ),
          Positioned(
            right: 16,
            top: 80,
            bottom: 120,
            width: 200,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.navyCard.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border:
                    Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.4),
                      blurRadius: 20,
                      offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded,
                          color: AppTheme.skyBlue, size: 20),
                      const SizedBox(width: 8),
                      Text('MOVES',
                          style: GoogleFonts.fredoka(
                              color: AppTheme.skyBlue,
                              fontSize: 13,
                              fontWeight: FontWeight.w700)),
                      const Spacer(),
                      _glassAction(
                          icon: Icons.close_rounded,
                          size: 24,
                          onTap: () => setState(() => _showMoves = false)),
                    ],
                  ),
                   const Divider(color: Colors.white10, height: 20),
                   Expanded(
                     child: MoveHistoryWidget(
                       moves: state.moveHistory,
                       currentFen: state.currentFEN,
                     ),
                   ),
                 ],
              ),
            )
                .animate()
                .slideX(begin: 1, duration: 300.ms, curve: Curves.easeOutCubic),
          ),
        ],
      ),
    );
  }

  Widget _glassAction(
      {required IconData icon, required double size, void Function()? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
            color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: AppTheme.textPrimary, size: size - 8),
      ),
    );
  }

  Widget _buildTurnOverlay(GameState state, bool minimalMotion) {
    final isMyTurn = state.isPlayerTurn;
    final label = isMyTurn ? '⚡ YOUR TURN!' : "⏳ OPPONENT'S TURN";
    final gradient = isMyTurn
        ? AppTheme.goldGradient
        : const LinearGradient(colors: [Color(0xFF4A5580), Color(0xFF3A4570)]);
    final textColor = isMyTurn ? AppTheme.midnight : Colors.white70;
    final shadowColor = isMyTurn ? AppTheme.goldPrimary : AppTheme.textMuted;

    Widget turnPill = Container(
      padding: const EdgeInsets.symmetric(horizontal: 22, vertical: 10),
      decoration: BoxDecoration(
        gradient: gradient,
        borderRadius: BorderRadius.circular(24),
        boxShadow: [
          BoxShadow(
            color: shadowColor.withValues(alpha: isMyTurn ? 0.5 : 0.2),
            blurRadius: isMyTurn ? 20 : 10,
            offset: const Offset(0, 4),
          ),
          if (isMyTurn)
            BoxShadow(
              color: AppTheme.goldPrimary.withValues(alpha: 0.3),
              blurRadius: 30,
              spreadRadius: 2,
            ),
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Text(
            label,
            style: GoogleFonts.fredoka(
              color: textColor,
              fontSize: isMyTurn ? 14 : 12,
              fontWeight: FontWeight.w800,
              letterSpacing: 1.2,
            ),
          ),
        ],
      ),
    );

    if (minimalMotion) return turnPill;

    if (isMyTurn) {
      return IgnorePointer(
        child: turnPill
            .animate(onPlay: (c) => c.repeat(reverse: true))
            .fadeIn(duration: 300.ms)
            .then()
            .fade(
                begin: 1.0,
                end: 0.4,
                duration: 700.ms,
                curve: Curves.easeInOut)
            .scale(
                begin: const Offset(1.0, 1.0),
                end: const Offset(1.06, 1.06),
                duration: 700.ms,
                curve: Curves.easeInOut)
            .shimmer(
                delay: 3.seconds,
                duration: 1200.ms,
                color: AppTheme.goldLight.withValues(alpha: 0.3)),
      );
    }

    return IgnorePointer(
      child: Opacity(
        opacity: 0.85,
        child: turnPill,
      ),
    );
  }

  Widget _buildEngineErrorOverlay(BuildContext context, GameState state) {
    return Positioned.fill(
      child: Container(
        color: Colors.black87,
        padding: const EdgeInsets.all(32),
        child: Center(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.error_outline_rounded,
                  color: AppTheme.accentRed, size: 64),
              const SizedBox(height: 24),
              Text(
                "ENGINE STALLED",
                style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 24,
                    fontWeight: FontWeight.w700),
              ),
              const SizedBox(height: 12),
              Text(
                state.engineError ?? "Oops! I can't think anymore.",
                textAlign: TextAlign.center,
                style: GoogleFonts.inter(color: Colors.white70, fontSize: 16),
              ),
              const SizedBox(height: 32),
              ElevatedButton.icon(
                onPressed: () {
                  context.read<GameBloc>().add(GameDismissErrorEvent());
                  if (widget.config.activeGameId != null) {
                    context
                        .read<GameBloc>()
                        .add(GameResumeEvent(widget.config.activeGameId!));
                  } else {
                    context.read<GameBloc>().add(GameStartEvent(widget.config,
                        tutorial: widget.tutorial));
                  }
                },
                icon: const Icon(Icons.refresh_rounded),
                label: Text('RELOAD GAME',
                    style: GoogleFonts.fredoka(fontWeight: FontWeight.w600)),
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldPrimary,
                  foregroundColor: AppTheme.midnight,
                  padding:
                      const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildConfirmMoveOverlay(GameState state) {
    return Positioned(
      bottom: 120,
      left: 0,
      right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.navyCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(
                color: AppTheme.goldPrimary.withValues(alpha: 0.6), width: 2),
            boxShadow: [
              BoxShadow(
                  color: AppTheme.goldPrimary.withValues(alpha: 0.2),
                  blurRadius: 20,
                  offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close_rounded,
                    color: Colors.redAccent, size: 28),
                onPressed: () => context
                    .read<GameBloc>()
                    .add(const GameSelectPieceEvent(Square(0, 0))), // Deselect
              ),
              const SizedBox(width: 12),
              Text(
                'Confirm Move?',
                style: GoogleFonts.fredoka(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 16),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: const BoxDecoration(
                    color: Colors.green, shape: BoxShape.circle),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.check_rounded,
                      color: Colors.white, size: 28),
                  onPressed: () =>
                      context.read<GameBloc>().add(GameConfirmMoveEvent()),
                ),
              ),
            ],
          ),
        ).animate().scale(duration: 200.ms, curve: Curves.easeOutBack).fadeIn(),
      ),
    );
  }

  Widget _buildTutorialCard(GameState state) {
    final lesson = state.tutorial;
    final totalSteps = lesson?.steps.length ?? 1;
    final currentStep = state.tutorialStep + 1;
    final isCompleted = state.isGameOver;
    final step = lesson != null && state.tutorialStep < lesson.steps.length
        ? lesson.steps[state.tutorialStep]
        : null;

    return IgnorePointer(
      ignoring: false,
      child: Container(
        constraints: const BoxConstraints(maxHeight: 220),
        padding: const EdgeInsets.all(16),
        decoration: BoxDecoration(
          color: AppTheme.navyCard.withValues(alpha: 0.97),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color: isCompleted
                ? AppTheme.accentCyan.withValues(alpha: 0.7)
                : AppTheme.goldPrimary.withValues(alpha: 0.5),
            width: 2,
          ),
          boxShadow: [
            BoxShadow(
              color: (isCompleted ? AppTheme.accentCyan : AppTheme.goldPrimary)
                  .withValues(alpha: 0.2),
              blurRadius: 16,
              offset: const Offset(0, 4),
            ),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            // Header with step counter
            Row(
              children: [
                Icon(
                  isCompleted
                      ? Icons.check_circle_rounded
                      : Icons.psychology_rounded,
                  color:
                      isCompleted ? AppTheme.accentCyan : AppTheme.goldPrimary,
                  size: 20,
                ),
                const SizedBox(width: 8),
                Text(
                  state.mode == GameMode.puzzle
                      ? 'CHALLENGE'
                      : isCompleted
                          ? '✅ COMPLETE'
                          : 'STEP $currentStep of $totalSteps',
                  style: GoogleFonts.fredoka(
                    color: isCompleted
                        ? AppTheme.accentCyan
                        : AppTheme.goldPrimary,
                    fontSize: 12,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 0.8,
                  ),
                ),
                const Spacer(),
                // Progress dots
                if (lesson != null)
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: List.generate(totalSteps, (i) {
                      final isActive = i == state.tutorialStep;
                      final isDone = i < state.tutorialStep;
                      return Container(
                        width: isActive ? 14 : 8,
                        height: 8,
                        margin: const EdgeInsets.only(left: 3),
                        decoration: BoxDecoration(
                          color: isDone
                              ? AppTheme.accentCyan
                              : isActive
                                  ? AppTheme.goldPrimary
                                  : AppTheme.textMuted.withValues(alpha: 0.3),
                          borderRadius: BorderRadius.circular(4),
                        ),
                      );
                    }),
                  ),
              ],
            ),
            const SizedBox(height: 10),
            // Tutorial text (scrollable)
            Flexible(
              child: SingleChildScrollView(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      state.tutorialMessage!,
                      style: GoogleFonts.baloo2(
                        color: AppTheme.textPrimary,
                        fontSize: 14,
                        fontWeight: FontWeight.w500,
                        height: 1.4,
                      ),
                      textAlign: TextAlign.left,
                    ),
                    // Persistent hint
                    if (step?.hintText != null && !isCompleted) ...[
                      const SizedBox(height: 8),
                      Container(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 10, vertical: 6),
                        decoration: BoxDecoration(
                          color: AppTheme.skyBlue.withValues(alpha: 0.1),
                          borderRadius: BorderRadius.circular(8),
                          border: Border.all(
                              color: AppTheme.skyBlue.withValues(alpha: 0.2)),
                        ),
                        child: Row(
                          children: [
                            const Icon(Icons.lightbulb_rounded,
                                color: AppTheme.skyBlue, size: 14),
                            const SizedBox(width: 6),
                            Expanded(
                              child: Text(
                                step!.hintText!,
                                style: GoogleFonts.baloo2(
                                  color: AppTheme.skyBlue,
                                  fontSize: 12,
                                ),
                              ),
                            ),
                          ],
                        ),
                      ),
                    ],
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.15);
  }

  Widget _buildBackground() {
    final bgTheme = context.watch<SettingsBloc>().state.backgroundTheme;
    return Container(
      decoration: BoxDecoration(gradient: AppTheme.getBackground(bgTheme)),
    );
  }

  Widget _buildTopBar(BuildContext context, GameState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
      child: Row(
        children: [
          // Back button
          _glassButton(
            icon: Icons.arrow_back_rounded,
            onTap: () => _showExitDialog(context),
          ),
          const Spacer(),
          // Game mode label — bubbly style
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 8),
            decoration: BoxDecoration(
              gradient: AppTheme.rainbowGradient,
              borderRadius: BorderRadius.circular(20),
              boxShadow: [
                BoxShadow(
                    color: Colors.black.withValues(alpha: 0.2),
                    blurRadius: 8,
                    offset: const Offset(0, 4)),
              ],
            ),
            child: Text(
              _modeName(state.mode),
              style: GoogleFonts.fredoka(
                color: AppTheme.midnight,
                fontWeight: FontWeight.w700,
                fontSize: 14,
              ),
            ),
          ),
          const Spacer(),
          // Undo button - show in multiplayer with conditions
          if (state.mode == GameMode.multiplayer)
            _glassButton(
              icon: Icons.undo_rounded,
              onTap: state.canMpUndo
                  ? () {
                      context.read<GameBloc>().add(GameUndoEvent());
                      if (state.mpUndosUsed + 1 >= 2) {
                        ScaffoldMessenger.of(context).showSnackBar(
                          SnackBar(
                            content: Text('⚠️ Undo attempts exhausted (2/2)',
                                style: GoogleFonts.baloo2()),
                            backgroundColor: AppTheme.accentRed,
                          ),
                        );
                      }
                    }
                  : null,
            )
          else if (state.mode != GameMode.multiplayer)
            _glassButton(
              icon: Icons.undo_rounded,
              onTap: state.moveHistory.isNotEmpty
                  ? () => context.read<GameBloc>().add(GameUndoEvent())
                  : null,
            ),
          const SizedBox(width: 8),
          // History button
          _glassButton(
            icon: Icons.history_rounded,
            onTap: () => setState(() => _showMoves = true),
          ),
          if (state.mode == GameMode.puzzle) ...[
            const SizedBox(width: 8),
            _glassButton(
              icon: Icons.psychology_rounded,
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
          ],
        ],
      ),
    );
  }

  Widget _glassButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        width: 48,
        height: 48,
        decoration: BoxDecoration(
          color: onTap != null
              ? AppTheme.surface.withValues(alpha: 0.8)
              : AppTheme.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: (onTap != null ? AppTheme.textMuted : Colors.transparent)
                  .withValues(alpha: 0.3)),
          boxShadow: onTap != null
              ? [
                  BoxShadow(
                      color: Colors.black.withValues(alpha: 0.1),
                      blurRadius: 4,
                      offset: const Offset(0, 2))
                ]
              : null,
        ),
        child: Icon(icon,
            color: onTap != null ? AppTheme.textPrimary : AppTheme.textMuted,
            size: 24),
      ),
    );
  }

  Widget _buildOpponentInfo(GameState state) {
    final mpState = context.read<MultiplayerBloc>().state;
    final opponentLabel = state.mode == GameMode.singlePlayer
        ? 'Chess Robot (${state.aiDifficulty?.name.capitalize() ?? ""})'
        : state.mode == GameMode.multiplayer && state.opponentName != null
            ? '🌍 ${state.opponentName}'
            : '👤 Opponent';

    final isOpponentTurn = state.currentTurn != state.playerColor;
    final opponentTime = state.playerColor == PieceColor.white
        ? mpState.blackTime
        : mpState.whiteTime;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlayerInfoWidget(
            name: opponentLabel,
            isActive: isOpponentTurn,
            isAI: state.mode == GameMode.singlePlayer,
            isThinking: false, // Using overlay now
            color: state.playerColor == PieceColor.white
                ? PieceColor.black
                : PieceColor.white,
            avatarUrl: state.mode == GameMode.multiplayer ? mpState.opponentAvatarUrl : null,
            localAvatar: state.mode == GameMode.multiplayer ? mpState.opponentLocalAvatar : null,
          ),
          if (state.mode == GameMode.multiplayer) ...[
            const SizedBox(width: 12),
            TimerWidget(
                timeInSeconds: opponentTime,
                isActive: isOpponentTurn,
                label: 'Opponent'),
          ]
        ],
      ),
    );
  }

  Widget _buildPlayerInfo(GameState state) {
    final mpState = context.read<MultiplayerBloc>().state;
    final authState = context.read<AuthBloc>().state;
    UserModel? user;
    if (authState is AuthAuthenticatedState) {
      user = authState.user;
    }

    final isPlayerTurn = state.currentTurn == state.playerColor;
    final playerTime = state.playerColor == PieceColor.white
        ? mpState.whiteTime
        : mpState.blackTime;

    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          PlayerInfoWidget(
            name: user?.username ?? '👑 You',
            isActive: isPlayerTurn,
            isAI: false,
            isThinking: false,
            color: state.playerColor ?? PieceColor.white,
            avatarUrl: user?.avatarUrl,
            localAvatar: user?.localAvatar,
          ),
          if (state.mode == GameMode.multiplayer) ...[
            const SizedBox(width: 12),
            TimerWidget(
                timeInSeconds: playerTime,
                isActive: isPlayerTurn,
                label: 'You'),
          ]
        ],
      ),
    );
  }

  Widget _buildCapturedPieces(GameState state, PieceColor color) {
    final pieces =
        color == PieceColor.white ? state.capturedWhite : state.capturedBlack;
    return CapturedPiecesWidget(pieces: pieces, color: color);
  }

  bool _showMoves = false;
  bool _didShowRules = false;

  Widget _buildCompactLayout(
      BuildContext context, GameState state, BoxConstraints constraints) {
    return Column(
      children: [
        _buildTopBar(context, state),
        const SizedBox(height: 2),
        Expanded(
          child: Padding(
            padding: const EdgeInsets.symmetric(horizontal: 8),
            child: Column(
              children: [
                _buildOpponentInfo(state),
                _buildCapturedPieces(state, PieceColor.black),
                Expanded(
                  child: Center(
                    child: _buildBoardFrame(
                      context,
                      state,
                      maxDimension: math.min(constraints.maxWidth - 8,
                          constraints.maxHeight * 0.58),
                    ),
                  ),
                ),
                _buildCapturedPieces(state, PieceColor.white),
                if (state.tutorialMessage != null &&
                    (state.mode == GameMode.tutorial ||
                        state.mode == GameMode.puzzle))
                  Padding(
                    padding:
                        const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
                    child: _buildTutorialCard(state),
                  ),
                _buildPlayerInfo(state),
              ],
            ),
          ),
        ),
        const SizedBox(height: 4),
        _buildActionBar(context, state),
      ],
    );
  }

  Widget _buildFloatingChat(BuildContext context) {
    return LayoutBuilder(builder: (context, constraints) {
      return BlocBuilder<MultiplayerBloc, MultiplayerState>(
        builder: (context, mpState) {
          final messages = mpState.chatMessages.where((msg) {
            // Keep messages sent within the last 2 minutes for bubble previews
            final age = DateTime.now().difference(msg.timestamp);
            return age.inSeconds < 120;
          }).toList();

          return Positioned(
            left: _chatPosition.dx,
            top: _chatPosition.dy,
            child: GestureDetector(
              onPanUpdate: (details) {
                setState(() {
                  _isChatDragging = true;
                  // Clamp to screen boundaries
                  double newX = _chatPosition.dx + details.delta.dx;
                  double newY = _chatPosition.dy + details.delta.dy;
                  newX = newX.clamp(0.0, constraints.maxWidth - 60);
                  newY = newY.clamp(80.0, constraints.maxHeight - 200);
                  _chatPosition = Offset(newX, newY);
                });
              },
              onPanEnd: (_) => setState(() => _isChatDragging = false),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Recent message bubbles (Fade out preview)
                  if (!_isChatDragging)
                    IgnorePointer(
                      child: ConstrainedBox(
                        constraints: const BoxConstraints(maxWidth: 250, maxHeight: 150),
                        child: ListView.builder(
                          shrinkWrap: true,
                          itemCount: messages.length > 3 ? 3 : messages.length,
                          itemBuilder: (context, index) {
                            final msg = messages[messages.length - 1 - index];
                            return _chatBubble(msg.message, msg.isMe)
                                .animate()
                                .fadeIn(duration: 400.ms)
                                .slideY(begin: 0.2, end: 0)
                                .fadeOut(delay: 5.seconds, duration: 1.seconds);
                          },
                        ),
                      ),
                    ),
                  const SizedBox(height: 8),
                  // The main drabbable bubble/handle
                  GestureDetector(
                    onTap: () => _showChatHistory(context, mpState.chatMessages),
                    child: Container(
                      width: 56,
                      height: 56,
                      decoration: BoxDecoration(
                        gradient: AppTheme.rainbowGradient,
                        shape: BoxShape.circle,
                        boxShadow: [
                          BoxShadow(
                            color: Colors.black.withValues(alpha: 0.4),
                            blurRadius: 12,
                            offset: const Offset(0, 4),
                          ),
                        ],
                      ),
                      child: Stack(
                        alignment: Alignment.center,
                        children: [
                          const Icon(Icons.forum_rounded, color: AppTheme.midnight, size: 28),
                          if (mpState.chatMessages.isNotEmpty)
                             Positioned(
                              top: 0,
                              right: 0,
                              child: Container(
                                padding: const EdgeInsets.all(4),
                                decoration: const BoxDecoration(
                                  color: AppTheme.accentRed,
                                  shape: BoxShape.circle,
                                ),
                                constraints: const BoxConstraints(minWidth: 18, minHeight: 18),
                                child: Text(
                                  '${mpState.chatMessages.length}',
                                  style: const TextStyle(color: Colors.white, fontSize: 10, fontWeight: FontWeight.bold),
                                  textAlign: TextAlign.center,
                                ),
                              ),
                            ),
                        ],
                      ),
                    ),
                  ).animate(onPlay: (c) => c.repeat(reverse: true))
                   .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 2.seconds, curve: Curves.easeInOut),
                ],
              ),
            ),
          );
        },
      );
    });
  }

  void _showChatHistory(BuildContext context, List<ChatMessage> messages) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      backgroundColor: Colors.transparent,
      builder: (ctx) => FractionallySizedBox(
        heightFactor: 0.7,
        child: ChatWidget(
          messages: messages,
          onSendMessage: (msg) {
            context.read<MultiplayerBloc>().add(MpSendChatEvent(msg));
          },
        ),
      ),
    );
  }

  Widget _chatBubble(String text, bool isMe) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 6),
      child: Container(
        padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
        decoration: BoxDecoration(
          color: (isMe ? AppTheme.goldPrimary : Colors.white)
              .withValues(alpha: 0.15),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
              color: (isMe ? AppTheme.goldPrimary : Colors.white)
                  .withValues(alpha: 0.1)),
        ),
        child: Text(
          text,
          style: GoogleFonts.baloo2(
              color: Colors.white, fontSize: 13, fontWeight: FontWeight.w500),
        ),
      ),
    );
  }


  Widget _buildPuzzleRushOverlay(GameState state) {
    return Positioned(
      top: 140,
      left: 16,
      right: 16,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          // Strikes
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: Colors.black38,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: Colors.white12),
            ),
            child: Row(
              children: List.generate(3, (i) {
                final isStrike = i < state.puzzleRushStrikes;
                return Padding(
                  padding: const EdgeInsets.symmetric(horizontal: 2),
                  child: Icon(
                    isStrike
                        ? Icons.close_rounded
                        : Icons.check_circle_outline_rounded,
                    color: isStrike ? AppTheme.accentRed : Colors.white24,
                    size: 20,
                  ),
                );
              }),
            ),
          ),
          // Timer
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.navyCard,
              borderRadius: BorderRadius.circular(12),
              border:
                  Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.5)),
            ),
            child: Row(
              children: [
                const Icon(Icons.timer_outlined,
                    color: AppTheme.accentCyan, size: 18),
                const SizedBox(width: 6),
                Text(
                  '${(state.puzzleRushTime ~/ 60)}:${(state.puzzleRushTime % 60).toString().padLeft(2, '0')}',
                  style: GoogleFonts.fredoka(
                      color: Colors.white, fontWeight: FontWeight.w700),
                ),
              ],
            ),
          ),
          // XP
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
            decoration: BoxDecoration(
              color: AppTheme.goldPrimary.withValues(alpha: 0.1),
              borderRadius: BorderRadius.circular(12),
              border: Border.all(
                  color: AppTheme.goldPrimary.withValues(alpha: 0.3)),
            ),
            child: Text(
              '${state.totalPuzzleXP} XP',
              style: GoogleFonts.fredoka(
                  color: AppTheme.goldPrimary, fontWeight: FontWeight.w700),
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: -0.2);
  }

  Widget _buildBrainExplainer(GameState state) {
    if (state.puzzleExplanation == null) return const SizedBox.shrink();
    
    return Positioned(
      top: 180,
      left: 24,
      right: 24,
      child: Center(
        child: Container(
          constraints: const BoxConstraints(maxWidth: 400),
          padding: const EdgeInsets.all(20),
          decoration: BoxDecoration(
            color: AppTheme.navyCard.withValues(alpha: 0.98),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.4), width: 2),
            boxShadow: [
              BoxShadow(
                color: AppTheme.skyBlue.withValues(alpha: 0.15),
                blurRadius: 30,
                spreadRadius: 5,
              ),
              const BoxShadow(color: Colors.black54, blurRadius: 20),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Row(
                mainAxisAlignment: MainAxisAlignment.spaceBetween,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.psychology_rounded, color: AppTheme.skyBlue, size: 28),
                      const SizedBox(width: 12),
                      Text('BRAIN EXPLAINS',
                          style: GoogleFonts.fredoka(
                              color: AppTheme.skyBlue,
                              fontSize: 16,
                              fontWeight: FontWeight.bold,
                              letterSpacing: 1.1)),
                    ],
                  ),
                  IconButton(
                    onPressed: () => context
                        .read<GameBloc>()
                        .add(const GameExplainMoveEvent()), // Clear
                    icon: const Icon(Icons.close_rounded, color: AppTheme.textMuted),
                    padding: EdgeInsets.zero,
                    constraints: const BoxConstraints(),
                  ),
                ],
              ),
              const SizedBox(height: 16),
              Text(
                state.puzzleExplanation!,
                style: GoogleFonts.baloo2(
                  color: Colors.white, 
                  fontSize: 16,
                  height: 1.5,
                  fontWeight: FontWeight.w500,
                ),
              ),
              const SizedBox(height: 12),
              Align(
                alignment: Alignment.centerRight,
                child: TextButton(
                  onPressed: () => context
                      .read<GameBloc>()
                      .add(const GameExplainMoveEvent()), // Clear
                  child: Text('GOT IT!', style: GoogleFonts.fredoka(color: AppTheme.skyBlue, fontWeight: FontWeight.bold)),
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate().fadeIn().scale(curve: Curves.easeOutBack);
  }

  Widget _buildWideLayout(
      BuildContext context, GameState state, BoxConstraints constraints) {
    const sideWidth = 330.0;
    final maxBoard = math.min(
        constraints.maxHeight - 32, constraints.maxWidth - sideWidth - 56);

    return Padding(
      padding: const EdgeInsets.fromLTRB(14, 8, 14, 12),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Expanded(
            child: Column(
              children: [
                _buildTopBar(context, state),
                const SizedBox(height: 8),
                Expanded(
                  child: Center(
                    child: _buildBoardFrame(context, state,
                        maxDimension: maxBoard),
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: 18),
          SizedBox(
            width: sideWidth,
            child: SingleChildScrollView(
              child: Column(
                children: [
                  _buildOpponentInfo(state),
                  _buildCapturedPieces(state, PieceColor.black),
                  const SizedBox(height: 10),
                  if (state.moveHistory.isNotEmpty)
                    _buildMoveHistoryCard(state),
                  if (state.tutorialMessage != null &&
                      (state.mode == GameMode.tutorial ||
                          state.mode == GameMode.puzzle))
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _buildTutorialCard(state),
                    ),
                  const SizedBox(height: 10),
                  _buildCapturedPieces(state, PieceColor.white),
                  _buildPlayerInfo(state),
                  const SizedBox(height: 12),
                  _buildActionBar(context, state),
                  // Sidebar chat removed per user request - use floating chat instead
                  const SizedBox(height: 12),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardFrame(BuildContext context, GameState state,
      {required double maxDimension}) {
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
      constraints:
          BoxConstraints.tightFor(width: dimension + 30, height: dimension),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          if (state.coachSettings.showEvalBar &&
              (state.mode == GameMode.singlePlayer ||
                  state.mode == GameMode.practice)) ...[
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
                  legalMoves:
                      settings.showLegalMoves ? state.legalMoves : const [],
                  lastMove: state.moveHistory.isNotEmpty
                      ? state.moveHistory.last
                      : null,
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
                          context
                              .read<GameBloc>()
                              .add(GameSelectPieceEvent(sq));
                        },
                  isInteractive: !state.isAIThinking,
                  lastCorrectMove: state.coachMove,
                  preMove: state.preMove,
                ),
              ),

              // TURN INDICATORS - Centered & Stick to borders
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

              // AI COACH TALKING WINDOW - Elegantly floating near active side
              if (state.isAIThinking ||
                  state.coachFeedback != null ||
                  state.activeHint != null)
                Positioned(
                  left: -20,
                  right: -20,
                  top: state.currentTurn == perspective ? null : -130,
                  bottom: state.currentTurn == perspective ? -130 : null,
                  child: CoachInteractionWidget(state: state),
                ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, GameState state) {
    final settings = context.watch<SettingsBloc>().state;
    final isPracticeOrSingle =
        state.mode == GameMode.singlePlayer || state.mode == GameMode.practice || state.mode == GameMode.twoPlayer;
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

          // Hint button (single player, practice, puzzle, or online multiplayer)
          if (isPracticeOrSingle || isPuzzle || isMultiplayer)
            _actionBtn(
              icon: Icons.lightbulb_rounded,
              label: isPuzzle ? 'Hint (10XP)' : 'Hint',
              color: AppTheme.goldPrimary,
              onTap: !state.isGameOver &&
                      (state.isPlayerTurn || state.mode == GameMode.practice || state.mode == GameMode.twoPlayer) &&
                      !state.isAIThinking
                  ? () => context.read<GameBloc>().add(GameRequestHintEvent())
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
          // Undo — available for practice, single, and multiplayer
          if (isPracticeOrSingle || isMultiplayer)
            _actionBtn(
              icon: Icons.undo_rounded,
              label: 'Undo',
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
          // Draw offer — multiplayer only
          if (isMultiplayer)
            _actionBtn(
              icon: Icons.handshake_rounded,
              label: 'Draw',
              color: AppTheme.skyBlue,
              onTap: !state.isGameOver
                  ? () =>
                      context.read<MultiplayerBloc>().add(MpDrawOfferEvent())
                  : null,
              width: 70,
            ),
          // Save (multiplayer)
          if (isMultiplayer)
            _actionBtn(
              icon: Icons.save_rounded,
              label: 'Save Game',
              color: AppTheme.accentCyan,
              onTap: !state.isGameOver
                  ? () =>
                      context.read<MultiplayerBloc>().add(MpSaveRequestEvent())
                  : null,
              width: 70,
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

            // Toggle Multiplayer Feedback
            SwitchListTile(
              title: Text('Coaching in Online/2P',
                  style: GoogleFonts.fredoka(
                      color: AppTheme.textPrimary, fontSize: 18)),
              subtitle: Text('Enable analysis in competitive matches (Off by default)',
                  style: GoogleFonts.baloo2(color: AppTheme.textSecondary)),
              value: state.coachSettings.enableMultiplayerCoaching,
              activeThumbColor: AppTheme.accentCyan,
              onChanged: (val) {
                context.read<GameBloc>().add(GameUpdateCoachSettingsEvent(
                      state.coachSettings.copyWith(enableMultiplayerCoaching: val),
                    ));
              },
            ),

            const Divider(color: Colors.white12, height: 32),

            // Personality Selector
            Text('Coach Personality',
                style: GoogleFonts.fredoka(
                    color: AppTheme.textPrimary, fontSize: 18)),
            const SizedBox(height: 12),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: CoachPersonality.values.map((p) {
                final isSelected = state.coachSettings.personality == p;
                return GestureDetector(
                  onTap: () {
                    context.read<GameBloc>().add(GameUpdateCoachSettingsEvent(
                          state.coachSettings.copyWith(personality: p),
                        ));
                  },
                  child: AnimatedContainer(
                    duration: const Duration(milliseconds: 200),
                    padding: const EdgeInsets.symmetric(
                        horizontal: 16, vertical: 10),
                    decoration: BoxDecoration(
                      color: isSelected
                          ? AppTheme.accentPurple
                          : AppTheme.surface.withValues(alpha: 0.5),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(
                        color: isSelected
                            ? AppTheme.accentPurple
                            : AppTheme.textMuted.withValues(alpha: 0.2),
                      ),
                    ),
                    child: Text(
                      p.name[0].toUpperCase() + p.name.substring(1),
                      style: GoogleFonts.fredoka(
                        color: isSelected
                            ? AppTheme.midnight
                            : AppTheme.textPrimary,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                );
              }).toList(),
            ),

            const SizedBox(height: 24),

            // Level Selector
            Text('Coaching Level',
                style: GoogleFonts.fredoka(
                    color: AppTheme.textPrimary, fontSize: 18)),
            const SizedBox(height: 12),
            Container(
              decoration: BoxDecoration(
                color: AppTheme.surface.withValues(alpha: 0.3),
                borderRadius: BorderRadius.circular(16),
              ),
              child: Slider(
                value: CoachingLevel.values
                    .indexOf(state.coachSettings.level)
                    .toDouble(),
                min: 0,
                max: (CoachingLevel.values.length - 1).toDouble(),
                divisions: CoachingLevel.values.length - 1,
                activeColor: AppTheme.accentPurple,
                onChanged: (val) {
                  context.read<GameBloc>().add(GameUpdateCoachSettingsEvent(
                        state.coachSettings
                            .copyWith(level: CoachingLevel.values[val.toInt()]),
                      ));
                },
              ),
            ),
            Row(
              mainAxisAlignment: MainAxisAlignment.spaceBetween,
              children: CoachingLevel.values
                  .map((l) => Text(
                        l.name.toUpperCase(),
                        style: GoogleFonts.jura(
                            color: AppTheme.textMuted,
                            fontSize: 10,
                            fontWeight: FontWeight.bold),
                      ))
                  .toList(),
            ),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }

  Widget _buildMoveHistoryCard(GameState state) {
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

  Widget _buildPromotionOverlay(BuildContext context, GameState state) {
    return DecorationOverlay(
      child: PromotionDialog(
        color: state.currentTurn,
        onSelect: (type) {
          context.read<GameBloc>().add(GameMakeMoveEvent(
                state.promotionFrom!,
                state.promotionTo!,
                promotion: type,
              ));
        },
      ),
    );
  }

  Widget _buildGameOverOverlay(BuildContext context, GameState state) {
    return GameOverOverlay(
      result: state.result,
      drawReason: state.drawReason,
      playerColor: state.playerColor,
      puzzle: state.puzzle,
      gameMode: state.mode,
      opponentName: state.opponentName,
      moveCount: state.moveHistory.length,
      accuracy: state.accuracy,
      mistakes: state.mistakes,
      blunders: state.blunders,
      xpGained: state.xpGained,
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
      onShare: () => _sharePgn(
        context.read<GameBloc>().engine.toPGN(),
        'Check out my chess game results!',
        'Chess Master Results',
      ),
    );
  }

  Future<void> _sharePgn(String pgn, String intro, String subject) {
    return SharePlus.instance.share(
      ShareParams(
        text:
            '$intro\n\n$pgn\n\n🔥 Think you can beat me? Play Chess Master now:\nhttps://play.google.com/store/apps/details?id=com.chessmaster.app',
        subject: subject,
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

  Widget _buildCheckAlert(GameState state, bool minimalMotion) {
    if (minimalMotion) {
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
                  const Icon(Icons.warning_rounded,
                      color: Colors.white, size: 24),
                  const SizedBox(width: 10),
                  Text('⚠️ CHECK!',
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontWeight: FontWeight.w800,
                        fontSize: 20,
                      )),
                ],
              ),
            ),
          ),
        ),
      );
    }

    // Persistent blinking until check is resolved
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
                const Icon(Icons.warning_rounded,
                    color: Colors.white, size: 24),
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

  String _modeName(GameMode mode) => switch (mode) {
        GameMode.tutorial => '🚀 TUTORIAL',
        GameMode.singlePlayer => '🤖 VS ROBOT',
        GameMode.twoPlayer => '👥 2 PLAYER',
        GameMode.multiplayer => '🌍 ONLINE',
        GameMode.puzzle => '🧩 DAILY PUZZLE',
        GameMode.practice => '🎯 PRACTICE',
        GameMode.tournament => '🏆 TOURNAMENT',
      };

  Future<void> _showExitDialog(BuildContext context) async {
    final gameState = context.read<GameBloc>().state;
    final isLocalMode = gameState.mode == GameMode.singlePlayer ||
        gameState.mode == GameMode.twoPlayer;

    if (isLocalMode) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.navyCard,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('Leave Game? 👋',
              style: GoogleFonts.fredoka(color: AppTheme.textPrimary)),
          content: Text(
            'Choose how you want to exit. Local games are not counted as losses when you quit.',
            style:
                GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text('Keep Playing',
                  style: GoogleFonts.fredoka(color: AppTheme.textMuted)),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'quit_no_save'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(
                    color: AppTheme.textMuted.withValues(alpha: 0.35)),
              ),
              child: Text('Quit Without Save',
                  style: GoogleFonts.fredoka(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(ctx, 'save_quit'),
              child: Text('Save & Quit',
                  style: GoogleFonts.fredoka(color: AppTheme.midnight)),
            ),
          ],
        ),
      );

      if (!context.mounted) return;

      if (action == 'save_quit') {
        context.read<GameBloc>().add(GameSaveEvent());
        await Future.delayed(const Duration(milliseconds: 200));
        if (context.mounted) context.go('/home');
      } else if (action == 'quit_no_save') {
        context.read<GameBloc>().add(GameDiscardEvent());
        await Future.delayed(const Duration(milliseconds: 200));
        if (context.mounted) context.go('/home');
      }
      return;
    }

    if (gameState.mode == GameMode.multiplayer) {
      final forfeit = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.navyCard,
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('Forfeit Match? ⚠️',
              style: GoogleFonts.fredoka(color: AppTheme.accentRed)),
          content: Text(
            'Leaving an online or tournament game counts as a loss for you.',
            style:
                GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Stay',
                  style: GoogleFonts.fredoka(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Forfeit',
                  style: GoogleFonts.fredoka(color: Colors.white)),
            ),
          ],
        ),
      );

      if (forfeit == true && context.mounted) {
        context.read<MultiplayerBloc>().add(MpResignEvent());
        context.read<GameBloc>().add(GameResignEvent());
        await Future.delayed(const Duration(milliseconds: 200));
        if (context.mounted) context.go('/home');
      }
      return;
    }
    // For puzzle and tutorial modes, simply leave
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Leave Game? 👋',
            style: GoogleFonts.fredoka(color: AppTheme.textPrimary)),
        content: Text(
          'Your current progress will be lost. Are you sure?',
          style:
              GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Playing',
                style: GoogleFonts.fredoka(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Exit!', style: GoogleFonts.fredoka(color: Colors.white)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<GameBloc>().add(GameDiscardEvent());
      await Future.delayed(const Duration(milliseconds: 200));
      if (context.mounted) context.go('/home');
    }
  }

  Future<void> _showResignDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Give up? 🏳️',
            style: GoogleFonts.fredoka(color: AppTheme.accentRed)),
        content: Text(
          'Are you sure you want to stop this game? You can do it! 💪',
          style:
              GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No, I can win!',
                style: GoogleFonts.fredoka(color: AppTheme.accentCyan)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              shape: RoundedRectangleBorder(
                  borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child:
                Text('Resign', style: GoogleFonts.fredoka(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<GameBloc>().add(GameResignEvent());
    }
  }

  void _resign(BuildContext context, bool requireConfirm) {
    if (requireConfirm) {
      _showResignDialog(context);
      return;
    }
    context.read<GameBloc>().add(GameResignEvent());
  }

  Widget _buildMiniLessonOverlay(BuildContext context, GameState state) {
    return Positioned.fill(
      child: Stack(
        children: [
          Container(color: Colors.black.withValues(alpha: 0.4)),
          Center(
            child: Container(
              width: 300,
              padding: const EdgeInsets.all(24),
              decoration: BoxDecoration(
                color: AppTheme.navyCard,
                borderRadius: BorderRadius.circular(24),
                border: Border.all(
                    color: AppTheme.goldPrimary.withValues(alpha: 0.5)),
                boxShadow: [
                  BoxShadow(
                      color: Colors.black,
                      blurRadius: 30,
                      offset: const Offset(0, 10)),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Text('🚩', style: TextStyle(fontSize: 48)),
                  const SizedBox(height: 16),
                  Text('MINI LESSON',
                      style: GoogleFonts.fredoka(
                          color: AppTheme.goldPrimary,
                          fontSize: 13,
                          fontWeight: FontWeight.w700,
                          letterSpacing: 1.5)),
                  const SizedBox(height: 8),
                  Text('That move was a Blunder',
                      style: GoogleFonts.fredoka(
                          color: AppTheme.textPrimary,
                          fontSize: 20,
                          fontWeight: FontWeight.w600)),
                  const SizedBox(height: 12),
                  Text(
                      'You just lost significant material or a tactical advantage. This typically happens when a piece is left hanging or a fork is missed.',
                      style: GoogleFonts.baloo2(
                          color: AppTheme.textSecondary, fontSize: 15),
                      textAlign: TextAlign.center),
                  const SizedBox(height: 24),
                  ElevatedButton(
                    style: ElevatedButton.styleFrom(
                      backgroundColor: AppTheme.goldPrimary,
                      foregroundColor: Colors.black,
                      shape: RoundedRectangleBorder(
                          borderRadius: BorderRadius.circular(12)),
                      padding: const EdgeInsets.symmetric(
                          horizontal: 32, vertical: 12),
                    ),
                    onPressed: () =>
                        context.read<GameBloc>().add(GameUndoEvent()),
                    child: Text('TAKE BACK',
                        style:
                            GoogleFonts.fredoka(fontWeight: FontWeight.w700)),
                  ),
                  const SizedBox(height: 8),
                  TextButton(
                    onPressed: () => context
                        .read<GameBloc>()
                        .add(const GameDismissMiniLessonEvent()),
                    child: Text('CONTINUE ANYWAY',
                        style: GoogleFonts.baloo2(color: AppTheme.textMuted)),
                  ),
                ],
              ),
            ).animate().scale(begin: const Offset(0.8, 0.8)).fadeIn(),
          ),
        ],
      ),
    );
  }
}

class DecorationOverlay extends StatelessWidget {
  final Widget child;
  const DecorationOverlay({super.key, required this.child});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Container(
        margin: const EdgeInsets.symmetric(horizontal: 24),
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(
          gradient: AppTheme.rainbowGradient,
          borderRadius: BorderRadius.circular(32),
        ),
        child: ClipRRect(
          borderRadius: BorderRadius.circular(28),
          child: child,
        ),
      ),
    );
  }
}

extension StringExtension on String {
  String capitalize() =>
      isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
