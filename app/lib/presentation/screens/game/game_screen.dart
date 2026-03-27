import 'dart:math' as math;

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
import '../../../domain/engine/chess_engine.dart';
import '../../widgets/chess_board_widget.dart';
import '../../widgets/captured_pieces_widget.dart';
import '../../widgets/move_history_widget.dart';
import '../../widgets/promotion_dialog.dart';
import '../../widgets/game_over_overlay.dart';
import '../../widgets/player_info_widget.dart';
import '../../widgets/hint_button_widget.dart';

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

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 3));
    _checkAnimController = AnimationController(vsync: this, duration: 500.ms);
    
    // Sync initial settings
    final settings = context.read<SettingsBloc>().state;
    context.read<GameBloc>().add(GameUpdateSettingsEvent(
      confirmMoves: settings.confirmMoves,
      autoQueen: settings.autoQueen,
    ));
    
    context.read<GameBloc>().add(GameStartEvent(widget.config, tutorial: widget.tutorial));
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
    _confettiController.dispose();
    _checkAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return PopScope(
      canPop: false, // Prevent default pop behavior
      onPopInvokedWithResult: (didPop, result) => _onPopInvoked(didPop),
      child: BlocConsumer<GameBloc, GameState>(
        listener: (context, state) {
          if (state.isGameOver) {
            final isWin = (state.result == GameResult.whiteWins &&
                    state.playerColor == PieceColor.white) ||
                (state.result == GameResult.blackWins &&
                    state.playerColor == PieceColor.black);
            if (isWin) _confettiController.play();
          }
          if (state.status == GameStatus.check) {
            _checkAnimController.forward(from: 0);
          }
        },
      builder: (context, state) {
        final minimalMotion = context.select<SettingsBloc, bool>(
          (bloc) => bloc.state.moveAnimationSpeed == 'off',
        );
        return Scaffold(
          backgroundColor: AppTheme.midnight,
          body: Stack(
            children: [
              _buildBackground(),
              SafeArea(
                child: LayoutBuilder(
                  builder: (context, constraints) {
                    final isWide = constraints.maxWidth >= 1080;
                    return isWide
                        ? _buildWideLayout(context, state, constraints)
                        : _buildCompactLayout(context, state, constraints);
                  },
                ),
              ),
              if (state.showPromotionDialog) _buildPromotionOverlay(context, state),
              if (state.isGameOver) _buildGameOverOverlay(context, state),
              _buildConfetti(),
              if (state.status == GameStatus.check) _buildCheckAlert(state, minimalMotion),
              if (!state.isGameOver) _buildTurnOverlay(state, minimalMotion),
              if (state.pendingMove != null) _buildConfirmMoveOverlay(state),
              if (_showMoves) _buildMoveHistoryOverlay(state),
            ],
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
            right: 16, top: 80, bottom: 120,
            width: 200,
            child: Container(
              padding: const EdgeInsets.all(12),
              decoration: BoxDecoration(
                color: AppTheme.navyCard.withValues(alpha: 0.95),
                borderRadius: BorderRadius.circular(24),
                border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.3)),
                boxShadow: [
                  BoxShadow(color: Colors.black.withValues(alpha: 0.4), blurRadius: 20, offset: const Offset(0, 8)),
                ],
              ),
              child: Column(
                children: [
                  Row(
                    children: [
                      const Icon(Icons.history_rounded, color: AppTheme.skyBlue, size: 20),
                      const SizedBox(width: 8),
                      Text('MOVES', style: GoogleFonts.fredoka(color: AppTheme.skyBlue, fontSize: 13, fontWeight: FontWeight.w700)),
                      const Spacer(),
                      _glassAction(icon: Icons.close_rounded, size: 24, onTap: () => setState(() => _showMoves = false)),
                    ],
                  ),
                  const Divider(color: Colors.white10, height: 20),
                  Expanded(child: MoveHistoryWidget(moves: state.moveHistory)),
                ],
              ),
            ),
          ).animate().slideX(begin: 1, duration: 300.ms, curve: Curves.easeOutCubic),
        ],
      ),
    );
  }

  Widget _glassAction({required IconData icon, required double size, void Function()? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(4),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: AppTheme.textPrimary, size: size - 8),
      ),
    );
  }

  Widget _buildTurnOverlay(GameState state, bool minimalMotion) {
    final isMyTurn = state.isPlayerTurn;
    final label = isMyTurn ? 'YOUR TURN!' : "OPPONENT'S TURN";
    final gradient = isMyTurn ? AppTheme.goldGradient : const LinearGradient(colors: [Color(0xFF6B7DB3), Color(0xFF4A5580)]);
    final icon = isMyTurn ? Icons.star_rounded : Icons.hourglass_top_rounded;
    final textColor = isMyTurn ? AppTheme.midnight : Colors.white;

    final overlay = Positioned(
      bottom: isMyTurn ? 120 : null,
      top: isMyTurn ? null : 75,
      left: 0, right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: gradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: (isMyTurn ? AppTheme.goldPrimary : AppTheme.textMuted).withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(icon, color: textColor, size: 20),
              const SizedBox(width: 8),
              Text(
                label,
                style: GoogleFonts.fredoka(
                  color: textColor, fontSize: 14, fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    );

    if (minimalMotion) return overlay;

    if (isMyTurn) {
      return overlay
          .animate(onPlay: (c) => c.repeat(reverse: true))
          .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 800.ms)
          .shimmer(delay: 2.seconds, duration: 1200.ms);
    }
    return overlay.animate().fadeIn(duration: 300.ms);
  }

  Widget _buildConfirmMoveOverlay(GameState state) {
    return Positioned(
      bottom: 120,
      left: 0, right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
          decoration: BoxDecoration(
            color: AppTheme.navyCard.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(24),
            border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.6), width: 2),
            boxShadow: [
              BoxShadow(color: AppTheme.goldPrimary.withValues(alpha: 0.2), blurRadius: 20, offset: const Offset(0, 8)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              IconButton(
                padding: EdgeInsets.zero,
                icon: const Icon(Icons.close_rounded, color: Colors.redAccent, size: 28),
                onPressed: () => context.read<GameBloc>().add(const GameSelectPieceEvent(Square(0, 0))), // Deselect
              ),
              const SizedBox(width: 12),
              Text(
                'Confirm Move?',
                style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontWeight: FontWeight.w700, fontSize: 16),
              ),
              const SizedBox(width: 12),
              Container(
                decoration: const BoxDecoration(color: Colors.green, shape: BoxShape.circle),
                child: IconButton(
                  padding: EdgeInsets.zero,
                  icon: const Icon(Icons.check_rounded, color: Colors.white, size: 28),
                  onPressed: () => context.read<GameBloc>().add(GameConfirmMoveEvent()),
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
                color: (isCompleted ? AppTheme.accentCyan : AppTheme.goldPrimary).withValues(alpha: 0.2),
                blurRadius: 16, offset: const Offset(0, 4),
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
                    isCompleted ? Icons.check_circle_rounded : Icons.psychology_rounded,
                    color: isCompleted ? AppTheme.accentCyan : AppTheme.goldPrimary,
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
                      color: isCompleted ? AppTheme.accentCyan : AppTheme.goldPrimary,
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
                          color: AppTheme.textPrimary, fontSize: 14, fontWeight: FontWeight.w500,
                          height: 1.4,
                        ),
                        textAlign: TextAlign.left,
                      ),
                      // Persistent hint
                      if (step?.hintText != null && !isCompleted) ...[
                        const SizedBox(height: 8),
                        Container(
                          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                          decoration: BoxDecoration(
                            color: AppTheme.skyBlue.withValues(alpha: 0.1),
                            borderRadius: BorderRadius.circular(8),
                            border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.2)),
                          ),
                          child: Row(
                            children: [
                              const Icon(Icons.lightbulb_rounded, color: AppTheme.skyBlue, size: 14),
                              const SizedBox(width: 6),
                              Expanded(
                                child: Text(
                                  step!.hintText!,
                                  style: GoogleFonts.baloo2(
                                    color: AppTheme.skyBlue, fontSize: 12,
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
    return Container(
      decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
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
                BoxShadow(color: Colors.black.withValues(alpha: 0.2), blurRadius: 8, offset: const Offset(0, 4)),
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
                            content: Text('⚠️ Undo attempts exhausted (2/2)', style: GoogleFonts.baloo2()),
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
          color: onTap != null ? AppTheme.surface.withValues(alpha: 0.8) : AppTheme.surface.withValues(alpha: 0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: (onTap != null ? AppTheme.textMuted : Colors.transparent).withValues(alpha: 0.3)),
          boxShadow: onTap != null ? [BoxShadow(color: Colors.black.withValues(alpha: 0.1), blurRadius: 4, offset: const Offset(0, 2))] : null,
        ),
        child: Icon(icon, color: onTap != null ? AppTheme.textPrimary : AppTheme.textMuted, size: 24),
      ),
    );
  }

  Widget _buildOpponentInfo(GameState state) {
    final opponentLabel = state.mode == GameMode.singlePlayer
        ? '🤖 Chess Robot (${state.aiDifficulty?.name.capitalize() ?? ""})'
        : state.mode == GameMode.multiplayer && state.opponentName != null
            ? '🌍 ${state.opponentName}'
            : '👤 Opponent';
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PlayerInfoWidget(
        name: opponentLabel,
        isActive: state.currentTurn != state.playerColor,
        isAI: state.mode == GameMode.singlePlayer,
        isThinking: state.isAIThinking,
        color: PieceColor.black,
      ),
    );
  }

  Widget _buildPlayerInfo(GameState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PlayerInfoWidget(
        name: '👑 You',
        isActive: state.currentTurn == state.playerColor,
        isAI: false,
        isThinking: false,
        color: state.playerColor ?? PieceColor.white,
      ),
    );
  }

  Widget _buildCapturedPieces(GameState state, PieceColor color) {
    final pieces = color == PieceColor.white
        ? state.capturedWhite
        : state.capturedBlack;
    return CapturedPiecesWidget(pieces: pieces, color: color);
  }

  bool _showMoves = false;

  Widget _buildCompactLayout(BuildContext context, GameState state, BoxConstraints constraints) {
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
                      maxDimension: math.min(constraints.maxWidth - 8, constraints.maxHeight * 0.58),
                    ),
                  ),
                ),
                _buildCapturedPieces(state, PieceColor.white),
                if (state.tutorialMessage != null && (state.mode == GameMode.tutorial || state.mode == GameMode.puzzle))
                  Padding(
                    padding: const EdgeInsets.symmetric(vertical: 6, horizontal: 4),
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

  Widget _buildWideLayout(BuildContext context, GameState state, BoxConstraints constraints) {
    const sideWidth = 330.0;
    final maxBoard = math.min(constraints.maxHeight - 32, constraints.maxWidth - sideWidth - 56);

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
                    child: _buildBoardFrame(context, state, maxDimension: maxBoard),
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
                  if (state.moveHistory.isNotEmpty) _buildMoveHistoryCard(state),
                  if (state.tutorialMessage != null && (state.mode == GameMode.tutorial || state.mode == GameMode.puzzle))
                    Padding(
                      padding: const EdgeInsets.only(top: 10),
                      child: _buildTutorialCard(state),
                    ),
                  const SizedBox(height: 10),
                  _buildCapturedPieces(state, PieceColor.white),
                  _buildPlayerInfo(state),
                  const SizedBox(height: 12),
                  _buildActionBar(context, state),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildBoardFrame(BuildContext context, GameState state, {required double maxDimension}) {
    final dimension = math.max(300.0, math.min(maxDimension, 860.0));
    final settings = context.watch<SettingsBloc>().state;
    // In multiplayer, always use playerColor for perspective (never auto-flip)
    final PieceColor perspective;
    if (state.mode == GameMode.multiplayer && state.playerColor != null) {
      perspective = state.playerColor!;
    } else if (settings.autoFlipBoard) {
      perspective = state.currentTurn;
    } else {
      perspective = state.playerColor ?? PieceColor.white;
    }

    return ConstrainedBox(
      constraints: BoxConstraints.tightFor(width: dimension, height: dimension),
      child: ChessBoardWidget(
        board: state.board,
        perspective: perspective,
        selectedSquare: state.selectedSquare,
        legalMoves: settings.showLegalMoves ? state.legalMoves : const [],
        lastMove: state.moveHistory.isNotEmpty ? state.moveHistory.last : null,
        hintMove: state.hintMove,
        status: state.status,
        boardTheme: state.boardTheme ?? 'classic',
        pieceTheme: state.pieceTheme,
        moveAnimationSpeed: settings.moveAnimationSpeed,
        showCoordinates: settings.showCoordinates,
        showSquareLabels: settings.showSquareLabels,
        whitePieceColor: state.whitePieceColor,
        blackPieceColor: state.blackPieceColor,
        currentTurn: state.currentTurn,
        onSquareTap: state.isGameOver
            ? null
            : (sq) {
                context.read<GameBloc>().add(GameSelectPieceEvent(sq));
              },
        isInteractive: !state.isAIThinking && state.isPlayerTurn,
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, GameState state) {
    final settings = context.watch<SettingsBloc>().state;
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: AppTheme.deepSpace.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Wrap(
        alignment: WrapAlignment.spaceEvenly,
        runSpacing: 8,
        spacing: 6,
        children: [
          // Hint button (single player only)
          if (state.mode == GameMode.singlePlayer)
            HintButtonWidget(
              hintsRemaining: state.hintsRemaining,
              onTap: state.hintsRemaining > 0 && state.isPlayerTurn && !state.isGameOver
                  ? () => context.read<GameBloc>().add(GameRequestHintEvent())
                  : null,
            ),
          // Draw offer
          _actionBtn(
            icon: Icons.handshake_rounded,
            label: 'Draw',
            color: AppTheme.skyBlue,
            onTap: !state.isGameOver
                ? () {
                    if (state.mode == GameMode.multiplayer) {
                      context.read<MultiplayerBloc>().add(MpDrawOfferEvent());
                    } else {
                      _offerDraw(context, settings.confirmDrawOffer);
                    }
                  }
                : null,
          ),
          // Resign
          _actionBtn(
            icon: Icons.flag_rounded,
            label: 'Resign',
            color: AppTheme.accentRed,
            onTap: !state.isGameOver
                ? () => _resign(context, settings.confirmResign)
                : null,
          ),
          // Save
          _actionBtn(
            icon: Icons.save_rounded,
            label: 'Save',
            color: AppTheme.accentCyan,
            onTap: () => context.read<GameBloc>().add(GameSaveEvent()),
          ),
          // Share
          _actionBtn(
            icon: Icons.share_rounded,
            label: 'Share',
            color: AppTheme.goldPrimary,
            onTap: () => _sharePgn(
              context.read<GameBloc>().engine.toPGN(),
              'Check out my chess game!',
              'Chess Master Game',
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
  }) {
    return GestureDetector(
      onTap: onTap,
      child: AnimatedContainer(
        duration: 200.ms,
        width: 88,
        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 10),
        decoration: BoxDecoration(
          color: onTap != null ? (color ?? AppTheme.textSecondary).withValues(alpha: 0.1) : Colors.transparent,
          borderRadius: BorderRadius.circular(12),
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Icon(icon, color: onTap != null ? (color ?? AppTheme.textSecondary) : AppTheme.textMuted, size: 26),
            const SizedBox(height: 4),
            Text(label, style: GoogleFonts.fredoka(
              color: onTap != null ? (color ?? AppTheme.textSecondary) : AppTheme.textMuted,
              fontSize: 12, fontWeight: FontWeight.w600,
            )),
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
            style: GoogleFonts.fredoka(color: AppTheme.skyBlue, fontSize: 18, fontWeight: FontWeight.w700),
          ),
          const SizedBox(height: 10),
          Expanded(child: MoveHistoryWidget(moves: state.moveHistory)),
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
      onPlayAgain: () {
        context.read<GameBloc>().add(GameStartEvent(widget.config));
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
        text: '$intro\n\n$pgn\n\n🔥 Think you can beat me? Play Chess Master now:\nhttps://play.google.com/store/apps/details?id=com.chessmaster.app',
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
          AppTheme.goldPrimary, AppTheme.accentCyan,
          AppTheme.accentPurple, AppTheme.accentGreen,
        ],
        numberOfParticles: 40,
        gravity: 0.2,
      ),
    );
  }

  Widget _buildCheckAlert(GameState state, bool minimalMotion) {
    final alert = Positioned(
      top: 100,
      left: 0, right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 14),
          decoration: BoxDecoration(
            color: AppTheme.accentRed.withValues(alpha: 0.95),
            borderRadius: BorderRadius.circular(28),
            boxShadow: [
              BoxShadow(color: AppTheme.accentRed.withValues(alpha: 0.5), blurRadius: 24, spreadRadius: 4),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.warning_rounded, color: Colors.white, size: 24),
              const SizedBox(width: 10),
              Text('⚠️ CHECK!', style: GoogleFonts.fredoka(
                color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20,
              )),
            ],
          ),
        ),
      ),
    );

    if (minimalMotion) return alert;

    // Persistent blinking until check is resolved
    return alert
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .fadeIn(duration: 400.ms)
        .then()
        .fadeOut(duration: 400.ms);
  }

  String _modeName(GameMode mode) => switch (mode) {
    GameMode.tutorial     => '🚀 TUTORIAL',
    GameMode.singlePlayer => '🤖 VS ROBOT',
    GameMode.twoPlayer    => '👥 2 PLAYER',
    GameMode.multiplayer  => '🌍 ONLINE',
    GameMode.puzzle       => '🧩 DAILY PUZZLE',
  };

  Future<void> _showExitDialog(BuildContext context) async {
    final gameState = context.read<GameBloc>().state;
    final isLocalMode = gameState.mode == GameMode.singlePlayer || gameState.mode == GameMode.twoPlayer;

    if (isLocalMode) {
      final action = await showDialog<String>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.navyCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('Leave Game? 👋', style: GoogleFonts.fredoka(color: AppTheme.textPrimary)),
          content: Text(
            'Choose how you want to exit. Local games are not counted as losses when you quit.',
            style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, 'cancel'),
              child: Text('Keep Playing', style: GoogleFonts.fredoka(color: AppTheme.textMuted)),
            ),
            OutlinedButton(
              onPressed: () => Navigator.pop(ctx, 'quit_no_save'),
              style: OutlinedButton.styleFrom(
                side: BorderSide(color: AppTheme.textMuted.withValues(alpha: 0.35)),
              ),
              child: Text('Quit Without Save', style: GoogleFonts.fredoka(color: AppTheme.textSecondary)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentCyan,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(ctx, 'save_quit'),
              child: Text('Save & Quit', style: GoogleFonts.fredoka(color: AppTheme.midnight)),
            ),
          ],
        ),
      );

      if (!context.mounted) return;

      if (action == 'save_quit') {
        context.read<GameBloc>().add(GameSaveEvent());
        context.go('/home');
      } else if (action == 'quit_no_save') {
        context.go('/home');
      }
      return;
    }

    if (gameState.mode == GameMode.multiplayer) {
      final forfeit = await showDialog<bool>(
        context: context,
        builder: (ctx) => AlertDialog(
          backgroundColor: AppTheme.navyCard,
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
          title: Text('Forfeit Match? ⚠️', style: GoogleFonts.fredoka(color: AppTheme.accentRed)),
          content: Text(
            'Leaving an online or tournament game counts as a loss for you.',
            style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16),
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.pop(ctx, false),
              child: Text('Stay', style: GoogleFonts.fredoka(color: AppTheme.textMuted)),
            ),
            ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: AppTheme.accentRed,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
              ),
              onPressed: () => Navigator.pop(ctx, true),
              child: Text('Forfeit', style: GoogleFonts.fredoka(color: Colors.white)),
            ),
          ],
        ),
      );

      if (forfeit == true && context.mounted) {
        context.read<MultiplayerBloc>().add(MpResignEvent());
        context.read<GameBloc>().add(GameResignEvent());
        context.go('/home');
      }
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Leave Game? 👋', style: GoogleFonts.fredoka(color: AppTheme.textPrimary)),
        content: Text(
          'Your current game will be saved for later. Play again soon? 😊',
          style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Keep Playing', style: GoogleFonts.fredoka(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Exit!', style: GoogleFonts.fredoka(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<GameBloc>().add(GameSaveEvent());
      context.go('/home');
    }
  }

  Future<void> _showResignDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        title: Text('Give up? 🏳️', style: GoogleFonts.fredoka(color: AppTheme.accentRed)),
        content: Text(
          'Are you sure you want to stop this game? You can do it! 💪',
          style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('No, I can win!', style: GoogleFonts.fredoka(color: AppTheme.accentCyan)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.accentRed,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Resign', style: GoogleFonts.fredoka(color: Colors.white)),
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

  Future<void> _offerDraw(BuildContext context, bool requireConfirm) async {
    if (!requireConfirm) {
      context.read<GameBloc>().add(GameDrawOfferEvent());
      return;
    }

    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        title: Text('Offer Draw?', style: GoogleFonts.fredoka(color: AppTheme.skyBlue)),
        content: Text(
          'Send a draw offer to your opponent now?',
          style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 15),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx, false),
            child: Text('Cancel', style: GoogleFonts.fredoka(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            style: ElevatedButton.styleFrom(
              backgroundColor: AppTheme.skyBlue,
              shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
            ),
            onPressed: () => Navigator.pop(ctx, true),
            child: Text('Offer', style: GoogleFonts.fredoka(color: AppTheme.midnight)),
          ),
        ],
      ),
    );

    if (confirmed == true && context.mounted) {
      context.read<GameBloc>().add(GameDrawOfferEvent());
    }
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
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
