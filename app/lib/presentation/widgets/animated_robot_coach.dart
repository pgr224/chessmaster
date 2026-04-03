import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../data/models/coach_model.dart';

class AnimatedRobotCoach extends StatelessWidget {
  final bool isThinking;
  final MoveClassification? classification;
  final bool isHint;

  const AnimatedRobotCoach({
    super.key,
    required this.isThinking,
    this.classification,
    this.isHint = false,
  });

  @override
  Widget build(BuildContext context) {
    // Determine color and mood
    Color mainColor = Colors.blueAccent;
    if (isThinking) {
      mainColor = Colors.cyanAccent;
    } else if (isHint) {
      mainColor = Colors.amberAccent;
    } else if (classification != null) {
      mainColor = switch (classification!) {
        MoveClassification.brilliant => Colors.purpleAccent,
        MoveClassification.best => Colors.greenAccent,
        MoveClassification.good => Colors.lightGreenAccent,
        MoveClassification.needsImprovement => Colors.orangeAccent,
        MoveClassification.mistake => Colors.deepOrangeAccent,
        MoveClassification.blunder => Colors.redAccent,
      };
    }

    return SizedBox(
      width: 60,
      height: 70,
      child: Stack(
        alignment: Alignment.center,
        children: [
          // ROBOT BODY
          Container(
            width: 34,
            height: 38,
            decoration: BoxDecoration(
              color: Colors.grey[900],
              borderRadius: BorderRadius.circular(8),
              border: Border.all(color: mainColor.withOpacity(0.5), width: 2),
              boxShadow: [
                BoxShadow(
                    color: mainColor.withOpacity(0.3),
                    blurRadius: 10,
                    spreadRadius: 1),
              ],
            ),
          ),

          // ROBOT HEAD
          Positioned(
            top: 2,
            child: Container(
              width: 40,
              height: 30,
              decoration: BoxDecoration(
                color: Colors.grey[850],
                borderRadius: BorderRadius.circular(12),
                border: Border.all(color: mainColor, width: 2),
              ),
              child: Stack(
                children: [
                  // EYES
                  Positioned(
                    left: 6,
                    top: 8,
                    child: _buildEye(mainColor),
                  ),
                  Positioned(
                    right: 6,
                    top: 8,
                    child: _buildEye(mainColor),
                  ),
                  // MOUTH LINE
                  Positioned(
                    bottom: 4,
                    left: 10,
                    right: 10,
                    child: Container(
                      height: 2,
                      decoration: BoxDecoration(
                        color: mainColor.withOpacity(0.5),
                        borderRadius: BorderRadius.circular(2),
                      ),
                    ),
                  ),
                ],
              ),
            ),
          )
              .animate(onPlay: (c) => c.repeat(reverse: true))
              .moveY(begin: 0, end: -2, duration: 2.seconds),

          // ARMS / HANDS
          _buildArm(true, mainColor),
          _buildArm(false, mainColor),

          // ANTENNA
          Positioned(
            top: -2,
            child: Container(
              width: 4,
              height: 8,
              color: mainColor,
            ).animate(onPlay: (c) => c.repeat()).shimmer(duration: 1.seconds),
          ),
        ],
      ),
    );
  }

  Widget _buildEye(Color color) {
    return Container(
      width: 8,
      height: 8,
      decoration: BoxDecoration(
        color: color,
        shape: BoxShape.circle,
        boxShadow: [BoxShadow(color: color, blurRadius: 4)],
      ),
    )
        .animate(onPlay: (c) => c.repeat(reverse: true))
        .scaleY(
            begin: 1, end: 0.1, delay: 2.seconds, duration: 150.ms) // Blinking
        .then(delay: 3.seconds);
  }

  Widget _buildArm(bool isLeft, Color color) {
    // Default: Breathing/Floating motion
    void Function(AnimationController) animation =
        (AnimationController c) => c.repeat(reverse: true);

    bool isSuccess = classification == MoveClassification.brilliant ||
        classification == MoveClassification.best;
    bool isWarning = classification == MoveClassification.mistake ||
        classification == MoveClassification.blunder;

    if (isThinking) {
      animation = (AnimationController c) => c.repeat();
    } else if (isSuccess) {
      animation = (AnimationController c) => c.repeat(reverse: true);
    } else if (isWarning) {
      animation = (AnimationController c) => c.repeat(reverse: true);
    } else if (isHint) {
      animation = (AnimationController c) => c.repeat(reverse: true);
    }

    // Since onPlay only handles the controller, we apply the visual effects via the chain.
    // The animation parameter is just to control the execution (repeat/reverse).

    var anim = Container(
      width: 14,
      height: 6,
      decoration: BoxDecoration(
        color: color.withOpacity(0.9),
        borderRadius: BorderRadius.circular(4),
        boxShadow: [BoxShadow(color: color.withOpacity(0.4), blurRadius: 4)],
      ),
    ).animate(onPlay: animation);

    if (isThinking) {
      anim = anim
          .rotate(
              begin: 0, end: 6.28 * (isLeft ? 1 : -1), duration: 0.8.seconds)
          .scale(
              begin: const Offset(1, 1),
              end: const Offset(1.2, 1.2),
              duration: 0.4.seconds);
    } else if (isSuccess) {
      anim = anim
          .moveY(begin: 0, end: -15, duration: 300.ms)
          .rotate(begin: 0, end: 0.5 * (isLeft ? 1 : -1), duration: 200.ms)
          .shake(hz: 8);
    } else if (isWarning) {
      anim = anim
          .moveY(begin: 0, end: 5, duration: 1.seconds)
          .rotate(begin: 0, end: -0.3 * (isLeft ? 1 : -1), duration: 500.ms);
    } else if (isHint) {
      anim = anim
          .moveX(begin: 0, end: 8 * (isLeft ? 1 : -1), duration: 600.ms)
          .rotate(begin: 0, end: 0.4 * (isLeft ? 1 : -1), duration: 600.ms);
    } else {
      anim = anim.rotate(
          begin: 0, end: 0.2 * (isLeft ? 1 : -1), duration: 1.2.seconds);
    }

    return Positioned(
      left: isLeft ? 1 : null,
      right: isLeft ? null : 1,
      top: 28,
      child: anim,
    );
  }
}
