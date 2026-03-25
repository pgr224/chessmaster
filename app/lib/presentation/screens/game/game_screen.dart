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
    context.read<GameBloc>().add(GameStartEvent(widget.config, tutorial: widget.tutorial));
  }

  @override
  void dispose() {
    _confettiController.dispose();
    _checkAnimController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return BlocConsumer<GameBloc, GameState>(
      listener: (context, state) {
        if (state.isGameOver) {
          final isWin = state.result == GameResult.whiteWins &&
              state.playerColor == PieceColor.white ||
              state.result == GameResult.blackWins &&
              state.playerColor == PieceColor.black;
          if (isWin) _confettiController.play();
        }
        if (state.status == GameStatus.check) {
          _checkAnimController.forward(from: 0);
        }
      },
      builder: (context, state) {
        return Scaffold(
          backgroundColor: AppTheme.midnight,
          body: Stack(
            children: [
              _buildBackground(),
              SafeArea(
                child: Column(
                  children: [
                    _buildTopBar(context, state),
                    const SizedBox(height: 4),
                    _buildOpponentInfo(state),
                    _buildCapturedPieces(state, PieceColor.black),
                    Expanded(
                      child: Center(
                        child: _buildBoard(context, state),
                      ),
                    ),
                    _buildCapturedPieces(state, PieceColor.white),
                    _buildPlayerInfo(state),
                    const SizedBox(height: 6),
                    _buildActionBar(context, state),
                  ],
                ),
              ),
              if (state.showPromotionDialog) _buildPromotionOverlay(context, state),
              if (state.isGameOver) _buildGameOverOverlay(context, state),
              _buildConfetti(),
              if (state.status == GameStatus.check) _buildCheckAlert(state),
              if (state.isPlayerTurn && !state.isGameOver) _buildTurnOverlay(state),
              if (_showMoves) _buildMoveHistoryOverlay(state),
              if (state.tutorialMessage != null) _buildTutorialOverlay(state),
            ],
          ),
        );
      },
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

  Widget _buildTurnOverlay(GameState state) {
    return Positioned(
      bottom: 120,
      left: 0, right: 0,
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 10),
          decoration: BoxDecoration(
            gradient: AppTheme.goldGradient,
            borderRadius: BorderRadius.circular(20),
            boxShadow: [
              BoxShadow(color: AppTheme.goldPrimary.withValues(alpha: 0.3), blurRadius: 15, offset: const Offset(0, 5)),
            ],
          ),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              const Icon(Icons.star_rounded, color: AppTheme.midnight, size: 20),
              const SizedBox(width: 8),
              Text(
                'YOUR TURN!',
                style: GoogleFonts.fredoka(
                  color: AppTheme.midnight, fontSize: 14, fontWeight: FontWeight.w800,
                  letterSpacing: 1.0,
                ),
              ),
            ],
          ),
        ),
      ),
    ).animate(onPlay: (c) => c.repeat(reverse: true))
        .scale(begin: const Offset(1, 1), end: const Offset(1.05, 1.05), duration: 800.ms)
        .shimmer(delay: 2.seconds, duration: 1200.ms);
  }

  Widget _buildTutorialOverlay(GameState state) {
    return Positioned(
      bottom: 140,
      left: 16, right: 16,
      child: Container(
        padding: const EdgeInsets.all(22),
        decoration: BoxDecoration(
          color: AppTheme.navyCard.withValues(alpha: 0.96),
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.5), width: 2),
          boxShadow: [
            BoxShadow(color: AppTheme.goldPrimary.withValues(alpha: 0.15), blurRadius: 24),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.school_rounded, color: AppTheme.goldPrimary, size: 24),
                const SizedBox(width: 10),
                Text(
                  '🎓 TUTORIAL STEP ${state.tutorialStep + 1}',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.goldPrimary, fontSize: 14, fontWeight: FontWeight.w700,
                    letterSpacing: 1.2,
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Text(
              state.tutorialMessage!,
              style: GoogleFonts.baloo2(
                color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600,
                height: 1.4,
              ),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
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
          // Undo button
          if (state.mode != GameMode.multiplayer)
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
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PlayerInfoWidget(
        name: state.mode == GameMode.singlePlayer
            ? '🤖 Chess Robot (${state.aiDifficulty?.name.capitalize() ?? ""})'
            : '👤 Opponent',
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

  Widget _buildBoard(BuildContext context, GameState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Expanded(
            child: ChessBoardWidget(
              board: state.board,
              perspective: state.playerColor ?? PieceColor.white,
              selectedSquare: state.selectedSquare,
              legalMoves: state.legalMoves,
              lastMove: state.moveHistory.isNotEmpty ? state.moveHistory.last : null,
              hintMove: state.hintMove,
              status: state.status,
              boardTheme: state.boardTheme ?? 'classic',
              onSquareTap: state.isGameOver ? null : (sq) {
                context.read<GameBloc>().add(GameSelectPieceEvent(sq));
              },
              isInteractive: !state.isAIThinking && state.isPlayerTurn,
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, GameState state) {
    return Container(
      padding: const EdgeInsets.fromLTRB(12, 8, 12, 16),
      decoration: BoxDecoration(
        color: AppTheme.deepSpace.withValues(alpha: 0.9),
        borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
        boxShadow: [
          BoxShadow(color: Colors.black.withValues(alpha: 0.3), blurRadius: 20, offset: const Offset(0, -4)),
        ],
      ),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
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
                ? () => context.read<GameBloc>().add(GameDrawOfferEvent())
                : null,
          ),
          // Resign
          _actionBtn(
            icon: Icons.flag_rounded,
            label: 'Resign',
            color: AppTheme.accentRed,
            onTap: !state.isGameOver
                ? () => _showResignDialog(context)
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
            onTap: () {
              final pgn = context.read<GameBloc>().engine.toPGN() ?? '';
              Share.share('Check out my chess game!\n\n$pgn', subject: 'Chess Master Game');
            },
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
        padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
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
      onPlayAgain: () {
        context.read<GameBloc>().add(GameStartEvent(widget.config));
      },
      onGoHome: () => context.go('/home'),
      onShare: () {
        final pgn = context.read<GameBloc>().engine.toPGN() ?? '';
        Share.share('Check out my chess game results!\n\n$pgn', subject: 'Chess Master Results');
      },
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

  Widget _buildCheckAlert(GameState state) {
    return Positioned(
      top: 100,
      left: 0, right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _checkAnimController,
          builder: (_, __) => Opacity(
            opacity: (1 - _checkAnimController.value).clamp(0, 1),
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
                  Text('OH NO! CHECK!', style: GoogleFonts.fredoka(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 20,
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().scale(begin: const Offset(0.5, 0.5)).fadeIn();
  }

  String _modeName(GameMode mode) => switch (mode) {
    GameMode.tutorial     => '🚀 TUTORIAL',
    GameMode.singlePlayer => '🤖 VS ROBOT',
    GameMode.twoPlayer    => '👥 2 PLAYER',
    GameMode.multiplayer  => '🌍 ONLINE',
    GameMode.tournament   => '🏆 TOURNAMENT',
  };

  Future<void> _showExitDialog(BuildContext context) async {
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
