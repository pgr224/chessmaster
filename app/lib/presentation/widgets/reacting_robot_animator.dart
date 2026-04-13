part of 'reacting_robot_widget.dart';

extension ReactingRobotAnimator on _ReactingRobotWidgetState {
  // ═══════════════════════════════════════════════
  // ROBOT AVATAR — Full animated body
  // ═══════════════════════════════════════════════
  Widget _buildRobotAvatar() {
    return AnimatedBuilder(
      animation: _breathController,
      builder: (context, child) {
        final breathOffset = _breathController.value * 2.0;
        return SizedBox(
          width: 62,
          height: 78,
          child: Stack(
            alignment: Alignment.center,
            children: [
              // GLOW AURA
              _buildGlowAura(),

              // BODY
              Positioned(
                top: 24 + breathOffset,
                child: _buildBody(),
              ),

              // HEAD (floats up/down with breathing)
              Positioned(
                top: 4 + breathOffset,
                child: _buildHead(),
              ),

              // LEFT ARM
              _buildAnimatedArm(isLeft: true, breathOffset: breathOffset),

              // RIGHT ARM
              _buildAnimatedArm(isLeft: false, breathOffset: breathOffset),

              // ANTENNA
              Positioned(
                top: breathOffset,
                child: _buildAntenna(),
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildGlowAura() {
    return AnimatedBuilder(
      animation: _pulseController,
      builder: (context, _) {
        final pulseVal = 0.08 + (_pulseController.value * 0.12);
        return Container(
          width: 56,
          height: 56,
          decoration: BoxDecoration(
            shape: BoxShape.circle,
            boxShadow: [
              BoxShadow(
                color: _moodColor.withValues(alpha: pulseVal),
                blurRadius: 24,
                spreadRadius: 8,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildBody() {
    return Container(
      width: 36,
      height: 40,
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(10),
        border: Border.all(color: _moodColor.withValues(alpha: 0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: _moodColor.withValues(alpha: 0.25),
            blurRadius: 12,
            spreadRadius: 1,
          ),
        ],
      ),
      child: Center(
        child: // Small chest light
            AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            return Container(
              width: 8,
              height: 8,
              decoration: BoxDecoration(
                color:
                    _moodColor.withValues(alpha: 0.4 + _pulseController.value * 0.6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _moodColor.withValues(alpha: 0.3),
                    blurRadius: 6,
                  ),
                ],
              ),
            );
          },
        ),
      ),
    );
  }

  Widget _buildHead() {
    return Container(
      width: 42,
      height: 32,
      decoration: BoxDecoration(
        color: const Color(0xFF222244),
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: _moodColor, width: 2),
        boxShadow: [
          BoxShadow(
            color: _moodColor.withValues(alpha: 0.2),
            blurRadius: 8,
          ),
        ],
      ),
      child: Stack(
        children: [
          // LEFT EYE
          Positioned(
            left: 7,
            top: 8,
            child: _buildEye(),
          ),
          // RIGHT EYE
          Positioned(
            right: 7,
            top: 8,
            child: _buildEye(),
          ),
          // MOUTH
          Positioned(
            bottom: 5,
            left: 11,
            right: 11,
            child: _buildMouth(),
          ),
        ],
      ),
    );
  }

  Widget _buildEye() {
    return AnimatedBuilder(
      animation: _blinkController,
      builder: (context, _) {
        final blinkVal = 1.0 - (_blinkController.value * 0.9);
        return Container(
          width: 9,
          height: 9 * blinkVal,
          decoration: BoxDecoration(
            color: _eyeColor,
            borderRadius: BorderRadius.circular(5),
            boxShadow: [
              BoxShadow(
                color: _eyeColor.withValues(alpha: 0.7),
                blurRadius: 6,
                spreadRadius: 1,
              ),
            ],
          ),
        );
      },
    );
  }

  Widget _buildMouth() {
    // Mouth shape changes with mood
    final isHappy = _mood == RobotMood.happy ||
        _mood == RobotMood.impressed ||
        _mood == RobotMood.celebrating;
    final isWorried =
        _mood == RobotMood.worried || _mood == RobotMood.disappointed;

    if (isHappy) {
      // Smile arc
      return CustomPaint(
        size: const Size(20, 6),
        painter: _SmilePainter(color: _moodColor.withValues(alpha: 0.7)),
      );
    } else if (isWorried) {
      // Worried mouth (slight frown)
      return CustomPaint(
        size: const Size(20, 6),
        painter: _FrownPainter(color: _moodColor.withValues(alpha: 0.7)),
      );
    }

    // Neutral line
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: _moodColor.withValues(alpha: 0.5),
        borderRadius: BorderRadius.circular(2),
      ),
    );
  }

  Widget _buildAnimatedArm(
      {required bool isLeft, required double breathOffset}) {
    return AnimatedBuilder(
      animation: _handController,
      builder: (context, _) {
        double rotation = 0;
        double offsetX = 0;
        double offsetY = 0;

        final handVal = _handController.value;

        switch (_mood) {
          case RobotMood.thinking:
            // Circular thinking motion
            rotation =
                math.sin(handVal * math.pi * 2) * 0.4 * (isLeft ? 1 : -1);
            offsetY = math.cos(handVal * math.pi * 2) * 4;
          case RobotMood.happy:
          case RobotMood.celebrating:
            // Wave/cheer
            rotation = math.sin(handVal * math.pi) * 0.6 * (isLeft ? 1 : -1);
            offsetY = -handVal * 12;
          case RobotMood.impressed:
            // Rapid excited wave
            rotation =
                math.sin(handVal * math.pi * 4) * 0.5 * (isLeft ? 1 : -1);
            offsetY = -handVal * 15;
          case RobotMood.worried:
            // Nervous fidget
            offsetX = math.sin(handVal * math.pi * 3) * 3 * (isLeft ? -1 : 1);
            rotation = 0.2 * (isLeft ? -1 : 1);
          case RobotMood.disappointed:
            // Droop down
            offsetY = handVal * 6;
            rotation = -0.3 * (isLeft ? 1 : -1);
          case RobotMood.hinting:
            // Point outward
            offsetX = handVal * 8 * (isLeft ? -1 : 1);
            rotation = 0.4 * (isLeft ? 1 : -1);
          case RobotMood.idle:
            // Gentle sway
            rotation = math.sin(handVal * math.pi) * 0.15 * (isLeft ? 1 : -1);
        }

        return Positioned(
          left: isLeft ? 1 + offsetX : null,
          right: isLeft ? null : 1 - offsetX,
          top: 30 + breathOffset + offsetY,
          child: Transform.rotate(
            angle: rotation,
            child: Container(
              width: 14,
              height: 7,
              decoration: BoxDecoration(
                color: _moodColor.withValues(alpha: 0.85),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: _moodColor.withValues(alpha: 0.35),
                    blurRadius: 5,
                  ),
                ],
              ),
            ),
          ),
        );
      },
    );
  }

  Widget _buildAntenna() {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        // Antenna tip (pulsing)
        AnimatedBuilder(
          animation: _pulseController,
          builder: (context, _) {
            return Container(
              width: 6,
              height: 6,
              decoration: BoxDecoration(
                color:
                    _moodColor.withValues(alpha: 0.5 + _pulseController.value * 0.5),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _moodColor.withValues(alpha: 0.4),
                    blurRadius: 6,
                    spreadRadius: 2,
                  ),
                ],
              ),
            );
          },
        ),
        // Antenna stem
        Container(
          width: 3,
          height: 6,
          decoration: BoxDecoration(
            color: _moodColor.withValues(alpha: 0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }
}

