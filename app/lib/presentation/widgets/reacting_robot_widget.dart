/// ReactingRobotWidget — Unified AI Coach component
/// Combines the animated robot avatar, thought bubble, and move reactions
/// into a single cohesive "alive" widget that reacts to game state.
library;

import 'dart:async';
import 'dart:math' as math;
import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:chess_master/presentation/blocs/game/game_bloc.dart';
import 'package:chess_master/core/theme/app_theme.dart';
import 'package:chess_master/data/models/coach_model.dart';
import 'package:chess_master/data/models/game_config.dart';
import 'package:chess_master/domain/engine/personality_engine.dart';

// ═══════════════════════════════════════════════════
// ROBOT STATE — Determines the robot's overall mood
// ═══════════════════════════════════════════════════
enum RobotMood {
  idle, // Calm, waiting for player's move
  thinking, // AI is calculating
  happy, // Player made a good move / AI is confident
  impressed, // Brilliant move from player
  worried, // Player made a strong move against AI
  disappointed, // Player blundered
  hinting, // Showing a hint
  celebrating, // Checkmate or win
}

// ═══════════════════════════════════════════════════
// MAIN WIDGET
// ═══════════════════════════════════════════════════
class ReactingRobotWidget extends StatefulWidget {
  final GameState state;
  const ReactingRobotWidget({super.key, required this.state});

  @override
  State<ReactingRobotWidget> createState() => _ReactingRobotWidgetState();
}

class _ReactingRobotWidgetState extends State<ReactingRobotWidget>
    with TickerProviderStateMixin {
  // Message cycling for thinking state
  int _messageIndex = 0;
  Timer? _messageCycleTimer;
  String? _currentReaction;
  RobotMood _mood = RobotMood.idle;

  // Animation controllers
  late AnimationController _blinkController;
  late AnimationController _breathController;
  late AnimationController _handController;
  late AnimationController _pulseController;

  // Personality-aware reaction messages
  static const Map<RobotMood, List<String>> _moodReactions = {
    RobotMood.idle: [
      "Your move, champ! ♟️",
      "I'm watching... 👀",
      "Take your time! ⏳",
      "What will you play? 🤔",
      "Show me what you've got! 💪",
    ],
    RobotMood.thinking: [
      "🤔 Hmm... let me think",
      "⏳ Calculating possibilities...",
      "🧠 Deep analysis mode!",
      "♟️ This position is interesting",
      "💭 Finding the best path...",
      "🔍 Evaluating options...",
      "⚙️ Processing moves...",
      "🛡️ Planning my strategy!",
    ],
    RobotMood.happy: [
      "Nice one! 👍✨",
      "Solid move! 💎",
      "You're getting better! 📈",
      "Good thinking! 🎯",
      "That's the spirit! 🌟",
    ],
    RobotMood.impressed: [
      "WOW! Brilliant!! 🔥🏆",
      "I didn't see that coming! 🤩",
      "A MASTERFUL move! 👑✨",
      "You're playing like a pro! 💫",
      "Incredible vision! 🧠🔥",
    ],
    RobotMood.worried: [
      "Uh oh... that's strong 😰",
      "I need to be careful now! 🛡️",
      "You're pressing hard! 💪😬",
      "That puts pressure on me! 😥",
      "I have to recalculate... 🔄",
    ],
    RobotMood.disappointed: [
      "Hmm, are you sure? 🤨",
      "I think there was better... 😕",
      "Watch out for that! ⚠️",
      "Oops! Check the board 👀",
      "That might cost you! 😬",
    ],
    RobotMood.hinting: [
      "Here's a little help! 💡",
      "Let me point you right... 🎯",
      "A hint for the wise! 🦉",
    ],
    RobotMood.celebrating: [
      "Great game! 🎉🏆",
      "What a match! 👏✨",
      "Well played! 🎊",
    ],
  };

  @override
  void initState() {
    super.initState();
    _blinkController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 150),
    );
    _breathController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 2200),
    )..repeat(reverse: true);
    _handController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 800),
    )..repeat(reverse: true);
    _pulseController = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 1200),
    )..repeat(reverse: true);

    _startBlinkLoop();
    _updateMood();
  }

  @override
  void didUpdateWidget(covariant ReactingRobotWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    final oldState = oldWidget.state;
    final newState = widget.state;

    // Detect transitions and update mood + reaction
    if (oldState.isAIThinking != newState.isAIThinking ||
        oldState.coachFeedback != newState.coachFeedback ||
        oldState.activeHint != newState.activeHint ||
        oldState.aiMessage != newState.aiMessage) {
      _updateMood();
    }
  }

  void _updateMood() {
    final s = widget.state;
    final feedback = s.coachFeedback;
    final oldMood = _mood;

    if (feedback != null) {
      _mood = _moodFromClassification(feedback.classification);
      // Generate a contextual reaction from personality + classification
      _currentReaction = _generateReaction(feedback, s);
      if (s.isAIThinking && s.mode != GameMode.practice) {
        _startMessageCycle();
      } else {
        _stopMessageCycle();
      }
    } else if (s.activeHint != null) {
      _mood = RobotMood.hinting;
      _stopMessageCycle();
    } else if (s.isAIThinking && s.mode != GameMode.practice) {
      _mood = RobotMood.thinking;
      _startMessageCycle();
    } else if (s.isGameOver) {
      _mood = RobotMood.celebrating;
      _stopMessageCycle();
    } else {
      // Player's turn — show idle reactions
      _mood = RobotMood.idle;
      _stopMessageCycle();
      _currentReaction = _pickRandomMessage(RobotMood.idle);
    }

    // Only rebuild if mood actually changed
    if (oldMood != _mood && mounted) {
      setState(() {});
    }
  }

  RobotMood _moodFromClassification(MoveClassification c) {
    return switch (c) {
      MoveClassification.brilliant => RobotMood.impressed,
      MoveClassification.best => RobotMood.happy,
      MoveClassification.good => RobotMood.happy,
      MoveClassification.needsImprovement => RobotMood.worried,
      MoveClassification.mistake => RobotMood.disappointed,
      MoveClassification.blunder => RobotMood.disappointed,
    };
  }

  String _generateReaction(CoachFeedback feedback, GameState state) {
    // Use personality to flavor the message
    final personality = state.activePersonality ?? AIPersonality.aggressive;
    final classification = feedback.classification;

    // If feedback already has a rich message, use it
    if (feedback.message.isNotEmpty) return feedback.message;

    // Map classification to string key for personality engine
    final classKey = switch (classification) {
      MoveClassification.brilliant => 'brilliant',
      MoveClassification.best => 'best',
      MoveClassification.good => 'good',
      MoveClassification.needsImprovement => 'mistake',
      MoveClassification.mistake => 'mistake',
      MoveClassification.blunder => 'blunder',
    };

    // Get personality-flavored reaction
    return personality.getMoveReaction(classKey);
  }

  String _pickRandomMessage(RobotMood mood) {
    final pool = _moodReactions[mood] ?? _moodReactions[RobotMood.idle]!;
    return pool[math.Random().nextInt(pool.length)];
  }

  void _startBlinkLoop() {
    Future.doWhile(() async {
      if (!mounted) return false;
      // Random delay between blinks (2-5 seconds)
      await Future.delayed(
          Duration(milliseconds: 2000 + math.Random().nextInt(3000)));
      if (!mounted) return false;
      await _blinkController.forward();
      await _blinkController.reverse();
      return mounted;
    });
  }

  void _startMessageCycle() {
    _messageCycleTimer?.cancel();
    _messageCycleTimer =
        Timer.periodic(const Duration(milliseconds: 2800), (_) {
      if (mounted && widget.state.isAIThinking) {
        setState(() {
          _messageIndex++;
        });
      }
    });
  }

  void _stopMessageCycle() {
    _messageCycleTimer?.cancel();
    _messageCycleTimer = null;
  }

  @override
  void dispose() {
    _messageCycleTimer?.cancel();
    _blinkController.dispose();
    _breathController.dispose();
    _handController.dispose();
    _pulseController.dispose();
    super.dispose();
  }

  // ═══════════════════════════════════════════════
  // COLORS
  // ═══════════════════════════════════════════════
  Color get _moodColor => switch (_mood) {
        RobotMood.idle => AppTheme.skyBlue,
        RobotMood.thinking => AppTheme.accentCyan,
        RobotMood.happy => const Color(0xFF81C784),
        RobotMood.impressed => AppTheme.lavender,
        RobotMood.worried => AppTheme.accentOrange,
        RobotMood.disappointed => AppTheme.accentRed,
        RobotMood.hinting => AppTheme.goldPrimary,
        RobotMood.celebrating => AppTheme.goldPrimary,
      };

  Color get _eyeColor => switch (_mood) {
        RobotMood.idle => AppTheme.skyBlue,
        RobotMood.thinking => const Color(0xFF00FFFF),
        RobotMood.happy => const Color(0xFF4CAF50),
        RobotMood.impressed => const Color(0xFFE040FB),
        RobotMood.worried => const Color(0xFFFF9800),
        RobotMood.disappointed => const Color(0xFFFF5722),
        RobotMood.hinting => AppTheme.goldPrimary,
        RobotMood.celebrating => AppTheme.goldLight,
      };

  // ═══════════════════════════════════════════════
  // BUILD
  // ═══════════════════════════════════════════════
  @override
  Widget build(BuildContext context) {
    final s = widget.state;
    final feedback = s.coachFeedback;
    final hint = s.activeHint;
    // In practice mode, suppress thinking display — only show reactions & hints
    final isThinking = s.isAIThinking && s.mode != GameMode.practice;

    // Determine what message to show
    String bubbleText;
    String? subtextStr;
    bool showBubble = true;

    if (isThinking) {
      final thinkMsgs = _moodReactions[RobotMood.thinking]!;
      final thinkText =
          s.aiMessage ?? thinkMsgs[_messageIndex % thinkMsgs.length];

      if (feedback != null) {
        // Unify coaching feedback with thinking indicator
        bubbleText = '${_currentReaction ?? feedback.message}\n\n$thinkText';
        subtextStr = feedback.explanation;
      } else {
        bubbleText = thinkText;
      }
    } else if (hint != null) {
      bubbleText = '${hint.currentLevelEmoji} ${hint.currentLevelLabel}';
      subtextStr = hint.currentHintText;
    } else if (feedback != null) {
      bubbleText = _currentReaction ?? feedback.message;
      subtextStr = feedback.explanation;
    } else if (_mood == RobotMood.idle || _mood == RobotMood.celebrating) {
      bubbleText = _currentReaction ?? _pickRandomMessage(_mood);
    } else {
      showBubble = false;
      bubbleText = '';
    }

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 🤖 ANIMATED ROBOT AVATAR
        _buildRobotAvatar()
            .animate()
            .slideX(
                begin: -0.5,
                end: 0,
                duration: 400.ms,
                curve: Curves.easeOutBack)
            .fadeIn(),

        const SizedBox(width: 6),

        // 💬 UNIFIED QUOTE BUBBLE
        if (showBubble)
          Flexible(
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                _buildQuoteBubble(
                  context: context,
                  text: bubbleText,
                  subtext: subtextStr,
                  hint: hint,
                  isThinking: isThinking,
                ),
                if (hint != null && !isThinking)
                  _buildHintUpgradeBar(context, hint),
              ],
            ),
          ),
      ],
    );
  }

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
                color: _moodColor.withOpacity(pulseVal),
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
        border: Border.all(color: _moodColor.withOpacity(0.6), width: 2),
        boxShadow: [
          BoxShadow(
            color: _moodColor.withOpacity(0.25),
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
                    _moodColor.withOpacity(0.4 + _pulseController.value * 0.6),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _moodColor.withOpacity(0.3),
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
            color: _moodColor.withOpacity(0.2),
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
                color: _eyeColor.withOpacity(0.7),
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
        painter: _SmilePainter(color: _moodColor.withOpacity(0.7)),
      );
    } else if (isWorried) {
      // Worried mouth (slight frown)
      return CustomPaint(
        size: const Size(20, 6),
        painter: _FrownPainter(color: _moodColor.withOpacity(0.7)),
      );
    }

    // Neutral line
    return Container(
      height: 2,
      decoration: BoxDecoration(
        color: _moodColor.withOpacity(0.5),
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
                color: _moodColor.withOpacity(0.85),
                borderRadius: BorderRadius.circular(4),
                boxShadow: [
                  BoxShadow(
                    color: _moodColor.withOpacity(0.35),
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
                    _moodColor.withOpacity(0.5 + _pulseController.value * 0.5),
                shape: BoxShape.circle,
                boxShadow: [
                  BoxShadow(
                    color: _moodColor.withOpacity(0.4),
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
            color: _moodColor.withOpacity(0.6),
            borderRadius: BorderRadius.circular(2),
          ),
        ),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // QUOTE BUBBLE
  // ═══════════════════════════════════════════════
  Widget _buildQuoteBubble({
    required BuildContext context,
    required String text,
    required String? subtext,
    required HintResult? hint,
    required bool isThinking,
  }) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E).withOpacity(0.97),
        borderRadius: const BorderRadius.only(
          topLeft: Radius.circular(22),
          topRight: Radius.circular(22),
          bottomLeft: Radius.circular(4),
          bottomRight: Radius.circular(22),
        ),
        border: Border.all(
          color: _moodColor.withOpacity(0.5),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: _moodColor.withOpacity(0.12),
            blurRadius: 18,
            spreadRadius: 2,
          ),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Mood indicator pill
          _buildMoodPill(hint),

          const SizedBox(height: 6),

          // Main text with animated switcher
          AnimatedSwitcher(
            duration: 350.ms,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: anim.drive(Tween<Offset>(
                  begin: const Offset(0, 0.15),
                  end: Offset.zero,
                )),
                child: child,
              ),
            ),
            child: Text(
              text,
              key: ValueKey(text),
              style: GoogleFonts.outfit(
                color: Colors.white,
                fontSize: 13,
                fontWeight: FontWeight.w700,
                letterSpacing: 0.2,
              ),
            ),
          ),

          // Subtext explanation
          if (subtext != null && subtext.isNotEmpty) ...[
            const SizedBox(height: 5),
            Text(
              subtext,
              style: GoogleFonts.outfit(
                color: Colors.white.withOpacity(0.8),
                fontSize: 12,
                height: 1.4,
                fontWeight: FontWeight.w500,
              ),
            ),
          ],

          // Thinking indicator
          if (isThinking) ...[
            const SizedBox(height: 6),
            _buildThinkingDots(),
          ],

          // Dismiss for hints
          if (hint != null) ...[
            const SizedBox(height: 6),
            GestureDetector(
              onTap: () =>
                  context.read<GameBloc>().add(const GameDismissHintEvent()),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.close_rounded,
                      size: 11, color: Colors.white30),
                  const SizedBox(width: 3),
                  Text(
                    'Dismiss',
                    style: GoogleFonts.outfit(
                      color: Colors.white30,
                      fontSize: 10,
                    ),
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    )
        .animate()
        .slideX(begin: 0.15, end: 0, duration: 280.ms, curve: Curves.easeOut)
        .fadeIn();
  }

  Widget _buildMoodPill(HintResult? hint) {
    final String label;
    final IconData icon;

    if (hint != null) {
      label =
          'HINT LVL ${hint.currentLevel} — ${hint.currentLevelLabel.toUpperCase()}';
      icon = Icons.lightbulb_rounded;
    } else {
      label = switch (_mood) {
        RobotMood.thinking => 'THINKING',
        RobotMood.happy || RobotMood.impressed => 'NICE MOVE',
        RobotMood.worried => 'STRONG PLAY',
        RobotMood.disappointed => 'CAREFUL!',
        RobotMood.hinting => 'HINT',
        RobotMood.celebrating => 'GAME OVER',
        _ => 'AI COACH',
      };
      icon = switch (_mood) {
        RobotMood.thinking => Icons.psychology_rounded,
        RobotMood.happy || RobotMood.impressed => Icons.thumb_up_alt_rounded,
        RobotMood.worried => Icons.warning_amber_rounded,
        RobotMood.disappointed => Icons.error_outline_rounded,
        RobotMood.celebrating => Icons.emoji_events_rounded,
        _ => Icons.smart_toy_rounded,
      };
    }

    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 3),
      decoration: BoxDecoration(
        color: _moodColor.withOpacity(0.12),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: _moodColor.withOpacity(0.35)),
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(icon, size: 10, color: _moodColor),
          const SizedBox(width: 4),
          Text(
            label,
            style: GoogleFonts.outfit(
              color: _moodColor,
              fontSize: 8,
              fontWeight: FontWeight.w900,
              letterSpacing: 0.6,
            ),
          ),
          if (hint != null && hint.pattern != TacticalPattern.none) ...[
            const SizedBox(width: 5),
            Text(
              hint.pattern.emoji,
              style: const TextStyle(fontSize: 9),
            ),
            const SizedBox(width: 2),
            Text(
              hint.pattern.label.toUpperCase(),
              style: GoogleFonts.outfit(
                color: _moodColor.withOpacity(0.6),
                fontSize: 8,
                fontWeight: FontWeight.w700,
              ),
            ),
          ],
        ],
      ),
    );
  }

  Widget _buildThinkingDots() {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: [
        SizedBox(
          width: 16,
          height: 16,
          child: CircularProgressIndicator(
            strokeWidth: 2,
            valueColor:
                AlwaysStoppedAnimation<Color>(_moodColor.withOpacity(0.7)),
          ),
        ),
        const SizedBox(width: 8),
        _AnimatedThinkingDots(color: _moodColor),
      ],
    );
  }

  // ═══════════════════════════════════════════════
  // HINT UPGRADE BAR
  // ═══════════════════════════════════════════════
  Widget _buildHintUpgradeBar(BuildContext context, HintResult hint) {
    if (!hint.canUpgrade) {
      return Padding(
        padding: const EdgeInsets.only(top: 5),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.check_circle_rounded,
                size: 13, color: AppTheme.accentGreen),
            const SizedBox(width: 5),
            Text(
              'Full hint revealed',
              style: GoogleFonts.outfit(
                color: AppTheme.accentGreen,
                fontSize: 10,
                fontWeight: FontWeight.w600,
              ),
            ),
          ],
        ),
      );
    }

    final nextEmoji = hint.currentLevel == 1 ? '🎯' : '♟️';
    final nextLabel = hint.currentLevel == 1 ? 'Direction' : 'Best Move';
    final xpCost = hint.nextLevelXpCost;

    return Padding(
      padding: const EdgeInsets.only(top: 5),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          // Level progress dots
          Row(
            mainAxisSize: MainAxisSize.min,
            children: List.generate(3, (i) {
              final level = i + 1;
              final isActive = level <= hint.currentLevel;
              final dotColor = _hintLevelColor(level);
              return Container(
                margin: const EdgeInsets.only(right: 3),
                width: isActive ? 18 : 8,
                height: 3,
                decoration: BoxDecoration(
                  color: isActive ? dotColor : dotColor.withOpacity(0.2),
                  borderRadius: BorderRadius.circular(2),
                ),
              );
            }),
          ),
          const SizedBox(height: 5),
          // Upgrade button
          GestureDetector(
            onTap: () => _showUpgradeConfirm(context, nextLabel, xpCost),
            child: Container(
              padding: const EdgeInsets.symmetric(horizontal: 9, vertical: 5),
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  colors: [
                    AppTheme.goldPrimary.withOpacity(0.18),
                    AppTheme.accentOrange.withOpacity(0.08),
                  ],
                ),
                borderRadius: BorderRadius.circular(10),
                border: Border.all(
                  color: AppTheme.goldPrimary.withOpacity(0.5),
                ),
              ),
              child: Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  const Icon(Icons.bolt_rounded,
                      color: Colors.amberAccent, size: 13),
                  const SizedBox(width: 4),
                  Text(
                    '$nextEmoji $nextLabel',
                    style: GoogleFonts.outfit(
                      color: Colors.amberAccent,
                      fontSize: 10,
                      fontWeight: FontWeight.w800,
                    ),
                  ),
                  const SizedBox(width: 6),
                  Container(
                    padding:
                        const EdgeInsets.symmetric(horizontal: 5, vertical: 1),
                    decoration: BoxDecoration(
                      color: Colors.amberAccent.withOpacity(0.18),
                      borderRadius: BorderRadius.circular(6),
                    ),
                    child: Text(
                      '-$xpCost XP',
                      style: GoogleFonts.outfit(
                        color: Colors.amberAccent,
                        fontSize: 9,
                        fontWeight: FontWeight.w900,
                      ),
                    ),
                  ),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  void _showUpgradeConfirm(
      BuildContext context, String nextLevelLabel, int xpCost) {
    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      builder: (ctx) => _HintUpgradeSheet(
        nextLevelLabel: nextLevelLabel,
        xpCost: xpCost,
        onConfirm: () {
          Navigator.of(ctx).pop();
          context.read<GameBloc>().add(const GameRequestHintEvent());
        },
        onCancel: () => Navigator.of(ctx).pop(),
      ),
    );
  }

  Color _hintLevelColor(int level) => switch (level) {
        1 => const Color(0xFF64B5F6),
        2 => Colors.amberAccent,
        3 => const Color(0xFF81C784),
        _ => Colors.amberAccent,
      };
}

// ═══════════════════════════════════════════════
// ANIMATED THINKING DOTS
// ═══════════════════════════════════════════════
class _AnimatedThinkingDots extends StatefulWidget {
  final Color color;
  const _AnimatedThinkingDots({required this.color});

  @override
  State<_AnimatedThinkingDots> createState() => _AnimatedThinkingDotsState();
}

class _AnimatedThinkingDotsState extends State<_AnimatedThinkingDots>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: 1200.ms)..repeat();
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AnimatedBuilder(
      animation: _controller,
      builder: (context, _) {
        int dots = ((_controller.value * 4).floor()) % 4;
        return SizedBox(
          width: 20,
          child: Text(
            '.' * dots,
            style: GoogleFonts.fredoka(
              color: widget.color,
              fontSize: 14,
              fontWeight: FontWeight.bold,
            ),
          ),
        );
      },
    );
  }
}

// ═══════════════════════════════════════════════
// SMILE / FROWN PAINTERS
// ═══════════════════════════════════════════════
class _SmilePainter extends CustomPainter {
  final Color color;
  _SmilePainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.2)
      ..quadraticBezierTo(
          size.width / 2, size.height * 1.2, size.width, size.height * 0.2);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

class _FrownPainter extends CustomPainter {
  final Color color;
  _FrownPainter({required this.color});

  @override
  void paint(Canvas canvas, Size size) {
    final paint = Paint()
      ..color = color
      ..style = PaintingStyle.stroke
      ..strokeWidth = 2
      ..strokeCap = StrokeCap.round;

    final path = Path()
      ..moveTo(0, size.height * 0.8)
      ..quadraticBezierTo(
          size.width / 2, -size.height * 0.2, size.width, size.height * 0.8);

    canvas.drawPath(path, paint);
  }

  @override
  bool shouldRepaint(covariant CustomPainter oldDelegate) => false;
}

// ═══════════════════════════════════════════════
// HINT UPGRADE CONFIRMATION SHEET
// ═══════════════════════════════════════════════
class _HintUpgradeSheet extends StatelessWidget {
  final String nextLevelLabel;
  final int xpCost;
  final VoidCallback onConfirm;
  final VoidCallback onCancel;

  const _HintUpgradeSheet({
    required this.nextLevelLabel,
    required this.xpCost,
    required this.onConfirm,
    required this.onCancel,
  });

  @override
  Widget build(BuildContext context) {
    final isFullReveal = nextLevelLabel == 'Best Move';
    final accentColor =
        isFullReveal ? const Color(0xFF81C784) : Colors.amberAccent;

    return Container(
      margin: const EdgeInsets.fromLTRB(16, 0, 16, 24),
      padding: const EdgeInsets.all(24),
      decoration: BoxDecoration(
        color: const Color(0xFF1A1A2E),
        borderRadius: BorderRadius.circular(28),
        border: Border.all(
          color: accentColor.withOpacity(0.4),
          width: 2,
        ),
        boxShadow: [
          BoxShadow(
            color: accentColor.withOpacity(0.1),
            blurRadius: 30,
            spreadRadius: 4,
          ),
          const BoxShadow(color: Colors.black54, blurRadius: 20),
        ],
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            children: [
              Container(
                padding: const EdgeInsets.all(10),
                decoration: BoxDecoration(
                  color: accentColor.withOpacity(0.15),
                  borderRadius: BorderRadius.circular(14),
                ),
                child: Icon(
                  isFullReveal
                      ? Icons.emoji_events_rounded
                      : Icons.lightbulb_rounded,
                  color: accentColor,
                  size: 24,
                ),
              ),
              const SizedBox(width: 14),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Reveal $nextLevelLabel?',
                      style: GoogleFonts.fredoka(
                        color: Colors.white,
                        fontSize: 20,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                    Text(
                      isFullReveal
                          ? 'Shows the exact best move from the engine'
                          : 'Shows which piece to move and where',
                      style: GoogleFonts.outfit(
                        color: Colors.white54,
                        fontSize: 13,
                      ),
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: 20),
          Container(
            width: double.infinity,
            padding: const EdgeInsets.symmetric(vertical: 14, horizontal: 16),
            decoration: BoxDecoration(
              color: accentColor.withOpacity(0.08),
              borderRadius: BorderRadius.circular(16),
              border: Border.all(color: accentColor.withOpacity(0.25)),
            ),
            child: Row(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                const Icon(Icons.bolt_rounded,
                    color: Colors.amberAccent, size: 20),
                const SizedBox(width: 8),
                Text(
                  'Costs $xpCost XP',
                  style: GoogleFonts.fredoka(
                    color: Colors.amberAccent,
                    fontSize: 22,
                    fontWeight: FontWeight.w700,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: 20),
          Row(
            children: [
              Expanded(
                child: GestureDetector(
                  onTap: onCancel,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      color: Colors.white.withOpacity(0.05),
                      borderRadius: BorderRadius.circular(16),
                      border: Border.all(color: Colors.white12),
                    ),
                    child: Text(
                      'Not now',
                      textAlign: TextAlign.center,
                      style: GoogleFonts.fredoka(
                        color: Colors.white54,
                        fontSize: 16,
                        fontWeight: FontWeight.w600,
                      ),
                    ),
                  ),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                flex: 2,
                child: GestureDetector(
                  onTap: onConfirm,
                  child: Container(
                    padding: const EdgeInsets.symmetric(vertical: 14),
                    decoration: BoxDecoration(
                      gradient: LinearGradient(
                        colors: [
                          accentColor.withOpacity(0.9),
                          accentColor.withOpacity(0.6),
                        ],
                      ),
                      borderRadius: BorderRadius.circular(16),
                      boxShadow: [
                        BoxShadow(
                          color: accentColor.withOpacity(0.3),
                          blurRadius: 12,
                          spreadRadius: 2,
                        ),
                      ],
                    ),
                    child: Row(
                      mainAxisAlignment: MainAxisAlignment.center,
                      children: [
                        const Icon(Icons.bolt_rounded,
                            color: Colors.black87, size: 18),
                        const SizedBox(width: 6),
                        Text(
                          'Yes, reveal it!',
                          style: GoogleFonts.fredoka(
                            color: Colors.black87,
                            fontSize: 16,
                            fontWeight: FontWeight.w700,
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
              ),
            ],
          ),
        ],
      ),
    )
        .animate()
        .slideY(begin: 0.3, duration: 350.ms, curve: Curves.easeOutBack)
        .fadeIn();
  }
}
