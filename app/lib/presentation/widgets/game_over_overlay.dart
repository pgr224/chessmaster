import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
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

    return Container(
      color: Colors.black.withOpacity(0.85),
      child: Center(
        child: Container(
          margin: const EdgeInsets.all(24),
          padding: const EdgeInsets.all(32),
          decoration: BoxDecoration(
            gradient: AppTheme.cardGradient,
            borderRadius: BorderRadius.circular(28),
            border: Border.all(
              color: isWin ? AppTheme.goldPrimary
                  : isDraw ? AppTheme.accentCyan
                  : AppTheme.accentRed,
              width: 1.5,
            ),
            boxShadow: [
              BoxShadow(
                color: (isWin ? AppTheme.goldPrimary
                    : isDraw ? AppTheme.accentCyan
                    : AppTheme.accentRed).withOpacity(0.3),
                blurRadius: 32,
                spreadRadius: 4,
              ),
            ],
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Trophy / Result emoji
              Text(
                isWin ? '🏆' : isDraw ? '🤝' : '💔',
                style: const TextStyle(fontSize: 64),
              ).animate()
                  .scale(begin: const Offset(0.5, 0.5), duration: 500.ms, curve: Curves.elasticOut),

              const SizedBox(height: 16),

              // Result text
              Text(
                isWin ? 'Victory!' : isDraw ? 'Draw!' : 'Defeat',
                style: TextStyle(
                  color: isWin ? AppTheme.goldPrimary
                      : isDraw ? AppTheme.accentCyan
                      : AppTheme.accentRed,
                  fontSize: 36,
                  fontWeight: FontWeight.w900,
                  letterSpacing: 1,
                ),
              ).animate().fadeIn(delay: 200.ms),

              const SizedBox(height: 8),

              Text(
                _resultText(),
                style: const TextStyle(color: AppTheme.textSecondary, fontSize: 16),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),

              const SizedBox(height: 32),

              // Action buttons
              Row(
                children: [
                  Expanded(
                    child: OutlinedButton.icon(
                      onPressed: onShare,
                      icon: const Icon(Icons.share_rounded),
                      label: const Text('Share'),
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: ElevatedButton.icon(
                      onPressed: onPlayAgain,
                      icon: const Icon(Icons.replay_rounded),
                      label: const Text('Play Again'),
                    ),
                  ),
                ],
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.2),

              const SizedBox(height: 12),

              TextButton(
                onPressed: onGoHome,
                child: const Text('← Back to Home',
                    style: TextStyle(color: AppTheme.textSecondary)),
              ).animate().fadeIn(delay: 500.ms),
            ],
          ),
        ),
      ),
    );
  }

  String _resultText() {
    if (result == GameResult.draw) {
      return switch (drawReason) {
        DrawReason.stalemate        => 'Stalemate — no legal moves',
        DrawReason.insufficientMaterial => 'Draw — insufficient material',
        DrawReason.fiftyMoveRule    => 'Draw — 50-move rule',
        DrawReason.threefoldRepetition => 'Draw — threefold repetition',
        DrawReason.agreement        => 'Draw by mutual agreement',
        null                        => 'The game ends in a draw',
      };
    }
    return result == GameResult.whiteWins ? 'White wins!' : 'Black wins!';
  }
}
