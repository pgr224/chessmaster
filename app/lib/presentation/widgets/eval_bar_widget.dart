import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../domain/engine/chess_engine.dart';

class EvalBarWidget extends StatelessWidget {
  final double evalScore; // positive for white advantage, negative for black
  final PieceColor perspective; // which color is on the bottom of the screen
  final double width;
  final double height;
  final bool isGameOver;
  final GameResult? result;

  const EvalBarWidget({
    super.key,
    required this.evalScore,
    required this.perspective,
    this.width = 16.0,
    required this.height,
    this.isGameOver = false,
    this.result,
  });

  @override
  Widget build(BuildContext context) {
    // Determine the percentage of the bar that should be WHITE.
    // 0 eval = 50%
    // +5 eval = ~95%
    // -5 eval = ~5%

    double whitePercentage = 0.5;

    if (isGameOver && result != null) {
      if (result == GameResult.whiteWins) {
        whitePercentage = 1.0;
      } else if (result == GameResult.blackWins) {
        whitePercentage = 0.0;
      }
    } else {
      // Non-linear mapping: 0.5 + 0.5 * (2 / pi) * atan(eval / 3.0)
      final mapped = (2.0 / math.pi) * math.atan(evalScore / 3.0);
      whitePercentage = 0.5 + 0.5 * mapped;
    }

    // Clamp to ensure both sides are visible unless checkmate
    if (!isGameOver) {
      whitePercentage = whitePercentage.clamp(0.05, 0.95);
    } else {
      if (result == GameResult.whiteWins) whitePercentage = 1.0;
      if (result == GameResult.blackWins) whitePercentage = 0.0;
    }

    final topIsBlack = perspective == PieceColor.white;
    final bottomColor =
        topIsBlack ? const Color(0xFFF3F3F3) : const Color(0xFF2B2B2B);
    final topColor =
        topIsBlack ? const Color(0xFF2B2B2B) : const Color(0xFFF3F3F3);

    final bottomPercentage =
        topIsBlack ? whitePercentage : (1.0 - whitePercentage);

    return Container(
      width: width,
      height: height,
      clipBehavior: Clip.antiAlias,
      decoration: BoxDecoration(
        color: topColor,
        borderRadius: BorderRadius.circular(width / 2),
        border: Border.all(color: Colors.white.withValues(alpha: 0.1), width: 1),
      ),
      child: Stack(
        alignment: Alignment.bottomCenter,
        children: [
          AnimatedContainer(
            duration: 600.ms,
            curve: Curves.easeOutCubic,
            width: width,
            height: height * bottomPercentage,
            decoration: BoxDecoration(
              color: bottomColor,
            ),
          ),
          if (!isGameOver && evalScore.abs() > 0.1)
            Positioned(
              bottom: bottomPercentage > 0.5 ? 4 : null,
              top: bottomPercentage <= 0.5 ? 4 : null,
              child: RotatedBox(
                quarterTurns: topIsBlack
                    ? 0
                    : 2, // keep text readable depending on flip? Actually just 0
                child: Text(
                  evalScore > 0
                      ? '+${evalScore.toStringAsFixed(1)}'
                      : evalScore.toStringAsFixed(1),
                  style: TextStyle(
                    color: bottomPercentage > 0.5 ? topColor : bottomColor,
                    fontSize: 9,
                    fontWeight: FontWeight.w900,
                  ),
                ),
              ),
            ),
        ],
      ),
    );
  }
}
