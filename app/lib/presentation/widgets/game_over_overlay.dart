import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';

class GameOverOverlay extends StatelessWidget {
  final GameResult result;
  final DrawReason? drawReason;
  final PieceColor? playerColor;
  final VoidCallback onPlayAgain;
  final VoidCallback onGoHome;
  final VoidCallback onShare;

  const GameOverOverlay({
    super.key,
    required this.result,
    this.drawReason,
    this.playerColor,
    required this.onPlayAgain,
    required this.onGoHome,
    required this.onShare,
  });

  @override
  Widget build(BuildContext context) {
    final isWin = (result == GameResult.whiteWins && playerColor == PieceColor.white) ||
        (result == GameResult.blackWins && playerColor == PieceColor.black);
    final isDraw = result == GameResult.draw;

    final statusColor = isWin ? AppTheme.goldPrimary 
        : isDraw ? AppTheme.accentCyan 
        : AppTheme.accentRed;

    return Container(
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
                      onPressed: onShare,
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
                      onPressed: onPlayAgain,
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
                onPressed: onGoHome,
                child: Text('← Back to Home',
                    style: GoogleFonts.fredoka(color: AppTheme.textMuted, fontSize: 16, fontWeight: FontWeight.w600)),
              ).animate().fadeIn(delay: 650.ms),
            ],
          ),
        ),
      ),
    );
  }

  String _resultText() {
    if (result == GameResult.draw) {
      return switch (drawReason) {
        DrawReason.stalemate        => 'Stalemate — no legal moves left! 😅',
        DrawReason.insufficientMaterial => 'Draw — not enough pieces to win! ♟️',
        DrawReason.fiftyMoveRule    => 'Draw — 50 moves without a catch! ⏳',
        DrawReason.threefoldRepetition => 'Draw — the same move happened 3 times! 🔄',
        DrawReason.agreement        => 'Draw by mutual agreement! 🤝',
        null                        => 'The game ends in a draw! 😊',
      };
    }
    final winner = result == GameResult.whiteWins ? 'White' : 'Black';
    return '$winner wins the battle! 🥳';
  }
}
