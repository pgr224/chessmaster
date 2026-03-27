import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';
import '../../../data/models/puzzle_model.dart';
import '../../../data/models/game_config.dart';

class GameOverOverlay extends StatefulWidget {
  final GameResult result;
  final DrawReason? drawReason;
  final PieceColor? playerColor;
  final VoidCallback onPlayAgain;
  final VoidCallback onGoHome;
  final VoidCallback onShare;
  final Puzzle? puzzle;
  final String? opponentName;
  final int? moveCount;
  final GameMode? gameMode;

  const GameOverOverlay({
    super.key,
    required this.result,
    this.drawReason,
    this.playerColor,
    required this.onPlayAgain,
    required this.onGoHome,
    required this.onShare,
    this.puzzle,
    this.opponentName,
    this.moveCount,
    this.gameMode,
  });

  @override
  State<GameOverOverlay> createState() => _GameOverOverlayState();
}

class _GameOverOverlayState extends State<GameOverOverlay> {
  late ConfettiController _confettiController;

  @override
  void initState() {
    super.initState();
    _confettiController = ConfettiController(duration: const Duration(seconds: 4));
    
    final isWin = (widget.result == GameResult.whiteWins && widget.playerColor == PieceColor.white) ||
        (widget.result == GameResult.blackWins && widget.playerColor == PieceColor.black);
    
    if (isWin) {
      _confettiController.play();
    }
  }

  @override
  void dispose() {
    _confettiController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final isWin = (widget.result == GameResult.whiteWins && widget.playerColor == PieceColor.white) ||
        (widget.result == GameResult.blackWins && widget.playerColor == PieceColor.black);
    final isDraw = widget.result == GameResult.draw;
    final isCheckmate = !isDraw && !isWin;

    final statusColor = isWin ? AppTheme.goldPrimary 
        : isDraw ? AppTheme.accentCyan 
        : AppTheme.accentRed;

    return Stack(
      children: [
        // Semi-transparent background so the board is visible behind
        Container(
          color: Colors.black.withValues(alpha: 0.55),
        ),
        // Result panel at the bottom, not covering the entire board
        Positioned(
          left: 0, right: 0,
          bottom: 0,
          child: Container(
            margin: const EdgeInsets.all(16),
            padding: const EdgeInsets.fromLTRB(24, 28, 24, 24),
            decoration: BoxDecoration(
              gradient: AppTheme.cardGradient,
              borderRadius: BorderRadius.circular(28),
              border: Border.all(color: statusColor.withValues(alpha: 0.6), width: 3),
              boxShadow: [
                BoxShadow(color: statusColor.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 4),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              children: [
                // Trophy / Result emoji
                Row(
                  mainAxisAlignment: MainAxisAlignment.center,
                  children: [
                    Container(
                      padding: const EdgeInsets.all(16),
                      decoration: BoxDecoration(
                        color: statusColor.withValues(alpha: 0.15),
                        shape: BoxShape.circle,
                      ),
                      child: Text(
                        isWin ? '🏆' : isDraw ? '🤝' : '💔',
                        style: const TextStyle(fontSize: 48),
                      ),
                    ).animate()
                        .scale(begin: const Offset(0.4, 0.4), duration: 600.ms, curve: Curves.elasticOut)
                        .fadeIn(),
                    const SizedBox(width: 16),
                    Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          isCheckmate ? 'CHECKMATE!' : isWin ? 'VICTORY!' : isDraw ? 'DRAW!' : 'DEFEAT',
                          style: GoogleFonts.fredoka(
                            color: statusColor,
                            fontSize: 32,
                            fontWeight: FontWeight.w900,
                            letterSpacing: 2,
                          ),
                        ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),
                        const SizedBox(height: 4),
                        Text(
                          _resultText(),
                          style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 14, fontWeight: FontWeight.w600),
                        ).animate().fadeIn(delay: 350.ms),
                      ],
                    ),
                  ],
                ),

                const SizedBox(height: 16),

                // Game info row
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withValues(alpha: 0.3),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                    children: [
                      _infoChip(Icons.sports_esports_rounded, _modeLabel()),
                      if (widget.opponentName != null)
                        _infoChip(Icons.person_rounded, 'vs ${widget.opponentName}'),
                      if (widget.moveCount != null && widget.moveCount! > 0)
                        _infoChip(Icons.grid_on_rounded, '${widget.moveCount} moves'),
                    ],
                  ),
                ).animate().fadeIn(delay: 400.ms),

                if (widget.puzzle != null && isWin) ...[
                  const SizedBox(height: 16),
                  Container(
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 14),
                    decoration: BoxDecoration(
                      color: AppTheme.goldPrimary.withValues(alpha: 0.1),
                      borderRadius: BorderRadius.circular(20),
                      border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.3)),
                    ),
                    child: Column(
                      children: [
                        Text(
                          '🎁 REWARD UNLOCKED!',
                          style: GoogleFonts.fredoka(color: AppTheme.goldPrimary, fontSize: 14, fontWeight: FontWeight.w700),
                        ),
                        const SizedBox(height: 6),
                        Text(
                          widget.puzzle!.reward,
                          style: GoogleFonts.baloo2(color: Colors.white, fontSize: 16, fontWeight: FontWeight.w600),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ),
                  ).animate().scale(delay: 800.ms, duration: 400.ms, curve: Curves.easeOutBack),
                ],

                const SizedBox(height: 20),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: BorderSide(color: AppTheme.textMuted.withValues(alpha: 0.3), width: 2),
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                        ),
                        onPressed: widget.onShare,
                        child: Text('Share ✨', style: GoogleFonts.fredoka(fontWeight: FontWeight.w600)),
                      ),
                    ),
                    const SizedBox(width: 12),
                    Expanded(
                      child: ElevatedButton(
                        style: ElevatedButton.styleFrom(
                          backgroundColor: statusColor,
                          foregroundColor: AppTheme.midnight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                          padding: const EdgeInsets.symmetric(vertical: 14),
                          elevation: 8,
                        ),
                        onPressed: widget.onPlayAgain,
                        child: Text('Rematch 🔄', style: GoogleFonts.fredoka(fontWeight: FontWeight.w700, fontSize: 15)),
                      ),
                    ),
                  ],
                ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),

                const SizedBox(height: 10),

                TextButton(
                  onPressed: widget.onGoHome,
                  child: Text('← Back to Home',
                      style: GoogleFonts.fredoka(color: AppTheme.textMuted, fontSize: 15, fontWeight: FontWeight.w600)),
                ).animate().fadeIn(delay: 650.ms),
              ],
            ),
          ),
        ),
        
        // Confetti effect on top
        if (isWin)
          Align(
            alignment: Alignment.topCenter,
            child: ConfettiWidget(
              confettiController: _confettiController,
              blastDirectionality: BlastDirectionality.explosive,
              shouldLoop: false,
              colors: const [
                AppTheme.goldPrimary,
                AppTheme.accentCyan,
                AppTheme.accentPurple,
                AppTheme.skyBlue,
                Colors.white,
              ],
              numberOfParticles: 50,
              maximumSize: const Size(15, 7),
              gravity: 0.2,
            ),
          ),
      ],
    );
  }

  Widget _infoChip(IconData icon, String label) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        Icon(icon, color: AppTheme.textMuted, size: 16),
        const SizedBox(width: 4),
        Text(label, style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 12, fontWeight: FontWeight.w600)),
      ],
    );
  }

  String _modeLabel() => switch (widget.gameMode) {
    GameMode.singlePlayer => 'Solo',
    GameMode.multiplayer  => 'Online',
    GameMode.twoPlayer    => '2 Player',
    GameMode.tutorial     => 'Tutorial',
    GameMode.puzzle       => 'Puzzle',
    null                  => 'Game',
  };

  String _resultText() {
    if (widget.result == GameResult.draw) {
      return switch (widget.drawReason) {
        DrawReason.stalemate        => 'Stalemate — no legal moves left! 😅',
        DrawReason.insufficientMaterial => 'Not enough pieces to win! ♟️',
        DrawReason.fiftyMoveRule    => '50 moves without a catch! ⏳',
        DrawReason.threefoldRepetition => 'Same position repeated 3 times! 🔄',
        DrawReason.agreement        => 'Draw by mutual agreement! 🤝',
        null                        => 'The game ends in a draw! 😊',
      };
    }
    final winner = widget.result == GameResult.whiteWins ? 'White' : 'Black';
    if (widget.puzzle != null) return 'Puzzle solved with brilliance! 🧠';
    return '$winner wins the battle! 🥳';
  }
}
