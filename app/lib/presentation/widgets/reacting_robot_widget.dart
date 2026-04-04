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

part 'reacting_robot_animator.dart';
part 'reacting_robot_bubble.dart';

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
}
