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
  final double accuracy;
  final int mistakes;
  final int blunders;
  final int xpGained;
  final String? analysisMessage;

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
    this.accuracy = 0.0,
    this.mistakes = 0,
    this.blunders = 0,
    this.xpGained = 0,
    this.analysisMessage,
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
          color: Colors.black.withOpacity(0.55),
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
              border: Border.all(color: statusColor.withOpacity(0.6), width: 3),
              boxShadow: [
                BoxShadow(color: statusColor.withOpacity(0.3), blurRadius: 40, spreadRadius: 4),
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
                        color: statusColor.withOpacity(0.15),
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

                // PERFORMANCE DASHBOARD
                Container(
                  padding: const EdgeInsets.all(16),
                  decoration: BoxDecoration(
                    color: AppTheme.surface.withOpacity(0.3),
                    borderRadius: BorderRadius.circular(20),
                    border: Border.all(color: AppTheme.skyBlue.withOpacity(0.1)),
                  ),
                  child: Column(
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceAround,
                        children: [
                          _statItem('Accuracy', '${widget.accuracy.toStringAsFixed(1)}%', AppTheme.accentCyan),
                          _statItem('Mistakes', '${widget.mistakes}', AppTheme.accentPurple),
                          _statItem('Blunders', '${widget.blunders}', AppTheme.accentRed),
                        ],
                      ),
                      if (widget.analysisMessage != null) ...[
                        const Divider(height: 24, color: AppTheme.textMuted),
                        Text(
                          widget.analysisMessage!,
                          style: GoogleFonts.baloo2(
                            color: AppTheme.textPrimary,
                            fontSize: 14,
                            fontWeight: FontWeight.w500,
                            height: 1.3,
                          ),
                          textAlign: TextAlign.center,
                        ),
                      ],
                    ],
                  ),
                ).animate().fadeIn(delay: 450.ms).slideX(begin: 0.1),

                const SizedBox(height: 16),

                // XP AND REWARDS
                if (widget.xpGained > 0)
                  Container(
                    margin: const EdgeInsets.only(bottom: 16),
                    padding: const EdgeInsets.symmetric(horizontal: 24, vertical: 12),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(colors: [AppTheme.goldPrimary.withOpacity(0.3), AppTheme.goldPrimary.withOpacity(0.1)]),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.4)),
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        const Icon(Icons.star_rounded, color: AppTheme.goldPrimary, size: 24),
                        const SizedBox(width: 8),
                        Text(
                          '+${widget.xpGained} XP GAINED!',
                          style: GoogleFonts.fredoka(color: AppTheme.goldPrimary, fontSize: 18, fontWeight: FontWeight.w800),
                        ),
                      ],
                    ),
                  ).animate().scale(delay: 700.ms, duration: 400.ms, curve: Curves.easeOutBack),

                // Action buttons
                Row(
                  children: [
                    Expanded(
                      child: OutlinedButton(
                        style: OutlinedButton.styleFrom(
                          foregroundColor: AppTheme.textPrimary,
                          side: BorderSide(color: AppTheme.textMuted.withOpacity(0.3), width: 2),
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

  Widget _statItem(String label, String value, Color color) {
    return Column(
      children: [
        Text(
          value,
          style: GoogleFonts.fredoka(color: color, fontSize: 22, fontWeight: FontWeight.w800),
        ),
        Text(
          label,
          style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 12, fontWeight: FontWeight.w600),
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
    GameMode.practice     => 'Practice',
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
