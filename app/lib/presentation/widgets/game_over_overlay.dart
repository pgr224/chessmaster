import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:confetti/confetti.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';
import '../../../data/models/puzzle_model.dart';

class GameOverOverlay extends StatefulWidget {
  final GameResult result;
  final DrawReason? drawReason;
  final PieceColor? playerColor;
  final VoidCallback onPlayAgain;
  final VoidCallback onGoHome;
  final VoidCallback onShare;
  final Puzzle? puzzle;

  const GameOverOverlay({
    super.key,
    required this.result,
    this.drawReason,
    this.playerColor,
    required this.onPlayAgain,
    required this.onGoHome,
    required this.onShare,
    this.puzzle,
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

    final statusColor = isWin ? AppTheme.goldPrimary 
        : isDraw ? AppTheme.accentCyan 
        : AppTheme.accentRed;

    return Stack(
      children: [
        Container(
          color: Colors.black.withValues(alpha: 0.85),
          child: Center(
            child: Container(
              margin: const EdgeInsets.symmetric(horizontal: 28),
              padding: const EdgeInsets.all(36),
              decoration: BoxDecoration(
                gradient: AppTheme.cardGradient,
                borderRadius: BorderRadius.circular(32),
                border: Border.all(color: statusColor.withValues(alpha: 0.6), width: 3),
                boxShadow: [
                  BoxShadow(color: statusColor.withValues(alpha: 0.3), blurRadius: 40, spreadRadius: 4),
                ],
              ),
              child: Column(
                mainAxisSize: MainAxisSize.min,
                children: [
                  // Trophy / Result emoji — big and bouncy
                  Container(
                    padding: const EdgeInsets.all(24),
                    decoration: BoxDecoration(
                      color: statusColor.withValues(alpha: 0.15),
                      shape: BoxShape.circle,
                    ),
                    child: Text(
                      isWin ? '🏆' : isDraw ? '🤝' : '💔',
                      style: const TextStyle(fontSize: 72),
                    ),
                  ).animate()
                      .scale(begin: const Offset(0.4, 0.4), duration: 600.ms, curve: Curves.elasticOut)
                      .fadeIn(),

                  const SizedBox(height: 24),

                  // Result title
                  Text(
                    isWin ? 'VICTORY!' : isDraw ? 'DRAW!' : 'DEFEAT',
                    style: GoogleFonts.fredoka(
                      color: statusColor,
                      fontSize: 40,
                      fontWeight: FontWeight.w900,
                      letterSpacing: 2,
                    ),
                  ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.2),

                  const SizedBox(height: 10),

                  Text(
                    _resultText(),
                    style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 18, fontWeight: FontWeight.w600),
                    textAlign: TextAlign.center,
                  ).animate().fadeIn(delay: 350.ms),

                  if (widget.puzzle != null && isWin) ...[
                    const SizedBox(height: 24),
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
                    ).animate().scale(delay: 800.ms, duration: 400.ms, curve: Curves.backOut),
                  ],

                  const SizedBox(height: 40),

                  // Action buttons — colorful and large
                  Row(
                    children: [
                      Expanded(
                        child: OutlinedButton(
                          style: OutlinedButton.styleFrom(
                            foregroundColor: AppTheme.textPrimary,
                            side: BorderSide(color: AppTheme.textMuted.withValues(alpha: 0.3), width: 2),
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                          ),
                          onPressed: widget.onShare,
                          child: Text('Share ✨', style: GoogleFonts.fredoka(fontWeight: FontWeight.w600)),
                        ),
                      ),
                      const SizedBox(width: 16),
                      Expanded(
                        child: ElevatedButton(
                          style: ElevatedButton.styleFrom(
                            backgroundColor: statusColor,
                            foregroundColor: AppTheme.midnight,
                            shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
                            padding: const EdgeInsets.symmetric(vertical: 16),
                            elevation: 8,
                          ),
                          onPressed: widget.onPlayAgain,
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text('Restart 🔄', style: GoogleFonts.fredoka(fontWeight: FontWeight.w700, fontSize: 16)),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ).animate().fadeIn(delay: 500.ms).slideY(begin: 0.3),

                  const SizedBox(height: 16),

                  TextButton(
                    onPressed: widget.onGoHome,
                    child: Text('← Back to Home',
                        style: GoogleFonts.fredoka(color: AppTheme.textMuted, fontSize: 16, fontWeight: FontWeight.w600)),
                  ).animate().fadeIn(delay: 650.ms),
                ],
              ),
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

  String _resultText() {
    if (widget.result == GameResult.draw) {
      return switch (widget.drawReason) {
        DrawReason.stalemate        => 'Stalemate — no legal moves left! 😅',
        DrawReason.insufficientMaterial => 'Draw — not enough pieces to win! ♟️',
        DrawReason.fiftyMoveRule    => 'Draw — 50 moves without a catch! ⏳',
        DrawReason.threefoldRepetition => 'Draw — the same move happened 3 times! 🔄',
        DrawReason.agreement        => 'Draw by mutual agreement! 🤝',
        null                        => 'The game ends in a draw! 😊',
      };
    }
    final winner = widget.result == GameResult.whiteWins ? 'White' : 'Black';
    if (widget.puzzle != null) return 'Puzzle solved with brilliance! 🧠';
    return '$winner wins the battle! 🥳';
  }
}
}
