import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:confetti/confetti.dart';
import 'package:go_router/go_router.dart';
import 'package:share_plus/share_plus.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/game_config.dart';
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
  const GameScreen({super.key, required this.config});

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
    context.read<GameBloc>().add(GameStartEvent(widget.config));
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
                    const SizedBox(height: 8),
                    _buildOpponentInfo(state),
                    const SizedBox(height: 8),
                    _buildCapturedPieces(state, PieceColor.black),
                    const Spacer(),
                    _buildBoard(context, state),
                    const Spacer(),
                    _buildCapturedPieces(state, PieceColor.white),
                    _buildPlayerInfo(state),
                    _buildActionBar(context, state),
                  ],
                ),
              ),
              if (state.showPromotionDialog) _buildPromotionOverlay(context, state),
              if (state.isGameOver) _buildGameOverOverlay(context, state),
              _buildConfetti(),
              if (state.status == GameStatus.check) _buildCheckAlert(state),
            ],
          ),
        );
      },
    );
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
          // Game mode label
          Container(
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 6),
            decoration: BoxDecoration(
              gradient: const LinearGradient(colors: [AppTheme.goldDark, AppTheme.goldPrimary]),
              borderRadius: BorderRadius.circular(20),
            ),
            child: Text(
              _modeName(state.mode),
              style: const TextStyle(
                color: AppTheme.midnight,
                fontWeight: FontWeight.w700,
                fontSize: 13,
              ),
            ),
          ),
          const Spacer(),
          // Undo button (offline only)
          if (state.mode != GameMode.multiplayer)
            _glassButton(
              icon: Icons.undo_rounded,
              onTap: state.moveHistory.isNotEmpty
                  ? () => context.read<GameBloc>().add(GameUndoEvent())
                  : null,
            ),
        ],
      ),
    );
  }

  Widget _glassButton({required IconData icon, VoidCallback? onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: 42,
        height: 42,
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.6),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: AppTheme.textMuted.withOpacity(0.3)),
        ),
        child: Icon(icon, color: onTap != null ? AppTheme.textPrimary : AppTheme.textMuted, size: 20),
      ),
    );
  }

  Widget _buildOpponentInfo(GameState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16),
      child: PlayerInfoWidget(
        name: state.mode == GameMode.singlePlayer
            ? 'Chess AI (${state.aiDifficulty?.name.capitalize() ?? ""})'
            : 'Opponent',
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
        name: 'You',
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

  Widget _buildBoard(BuildContext context, GameState state) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 8),
      child: Column(
        children: [
          ChessBoardWidget(
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
          const SizedBox(height: 8),
          // Move history scroll
          SizedBox(
            height: 40,
            child: MoveHistoryWidget(moves: state.moveHistory),
          ),
        ],
      ),
    );
  }

  Widget _buildActionBar(BuildContext context, GameState state) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
      decoration: BoxDecoration(
        color: AppTheme.deepSpace.withOpacity(0.8),
        border: const Border(top: BorderSide(color: Color(0xFF1F2952))),
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
            onTap: () => context.read<GameBloc>().add(GameSaveEvent()),
          ),
          // Share
          _actionBtn(
            icon: Icons.share_rounded,
            label: 'Share',
            onTap: () {
              final pgn = context.read<GameBloc>().engine.toPGN() ?? '';
              Share.share('Check out my chess game!\n\n$pgn', subject: 'Chess Game');
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
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, color: onTap != null ? (color ?? AppTheme.textSecondary) : AppTheme.textMuted, size: 22),
          const SizedBox(height: 2),
          Text(label, style: TextStyle(
            color: onTap != null ? (color ?? AppTheme.textSecondary) : AppTheme.textMuted,
            fontSize: 10, fontWeight: FontWeight.w500,
          )),
        ],
      ),
    );
  }

  Widget _buildPromotionOverlay(BuildContext context, GameState state) {
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

  Widget _buildGameOverOverlay(BuildContext context, GameState state) {
    return GameOverOverlay(
      result: state.result,
      drawReason: state.drawReason,
      playerColor: state.playerColor,
      onPlayAgain: () {
        context.read<GameBloc>().add(GameStartEvent(widget.config));
      },
      onGoHome: () => context.go('/home'),
      onShare: () {/* share PGN */},
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
        numberOfParticles: 30,
        gravity: 0.3,
      ),
    );
  }

  Widget _buildCheckAlert(GameState state) {
    return Positioned(
      top: 80,
      left: 0, right: 0,
      child: Center(
        child: AnimatedBuilder(
          animation: _checkAnimController,
          builder: (_, __) => Opacity(
            opacity: (1 - _checkAnimController.value).clamp(0, 1),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 10),
              decoration: BoxDecoration(
                color: AppTheme.accentRed.withOpacity(0.9),
                borderRadius: BorderRadius.circular(24),
                boxShadow: [
                  BoxShadow(color: AppTheme.accentRed.withOpacity(0.4), blurRadius: 16),
                ],
              ),
              child: const Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Icon(Icons.warning_rounded, color: Colors.white, size: 20),
                  SizedBox(width: 8),
                  Text('CHECK!', style: TextStyle(
                    color: Colors.white, fontWeight: FontWeight.w800, fontSize: 16,
                  )),
                ],
              ),
            ),
          ),
        ),
      ),
    ).animate().slideY(begin: -1, end: 0, duration: 300.ms);
  }

  String _modeName(GameMode mode) => switch (mode) {
    GameMode.tutorial     => 'TUTORIAL',
    GameMode.singlePlayer => 'VS AI',
    GameMode.twoPlayer    => '2 PLAYER',
    GameMode.multiplayer  => 'ONLINE',
    GameMode.tournament   => 'TOURNAMENT',
  };

  Future<void> _showExitDialog(BuildContext context) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Exit Game?', style: TextStyle(color: AppTheme.textPrimary)),
        content: const Text(
          'Your current game will be saved. Continue?',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Exit'),
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
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        title: const Text('Resign?', style: TextStyle(color: AppTheme.accentRed)),
        content: const Text(
          'Are you sure you want to resign? This will count as a loss.',
          style: TextStyle(color: AppTheme.textSecondary),
        ),
        actions: [
          TextButton(onPressed: () => Navigator.pop(ctx, false), child: const Text('Cancel')),
          ElevatedButton(
            style: ElevatedButton.styleFrom(backgroundColor: AppTheme.accentRed),
            onPressed: () => Navigator.pop(ctx, true),
            child: const Text('Resign', style: TextStyle(color: Colors.white)),
          ),
        ],
      ),
    );
    if (confirmed == true && context.mounted) {
      context.read<GameBloc>().add(GameResignEvent());
    }
  }
}

extension StringExtension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
