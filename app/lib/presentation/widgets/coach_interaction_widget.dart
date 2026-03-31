import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../blocs/game/game_bloc.dart';
import '../../blocs/game/game_state.dart';
import './animated_robot_coach.dart';

class CoachInteractionWidget extends StatelessWidget {
  final GameState state;

  const CoachInteractionWidget({Key? key, required this.state}) : super(key: key);

  @override
  Widget build(BuildContext context) {
    final isThinking = state.isAIThinking;
    final feedback = state.coachFeedback;
    final hint = state.activeHint;
    final aiMessage = state.aiMessage;

    // Priority: Thinking > Hint > Feedback
    String title = '';
    String? subtext;
    Color accentColor = Colors.blueAccent;
    bool show = false;

    if (isThinking) {
      title = aiMessage ?? 'Hmm, let me think... 🧐';
      accentColor = Colors.cyanAccent;
      show = true;
    } else if (hint != null) {
      title = 'Hint Analysis 🔍';
      subtext = hint.currentText;
      accentColor = Colors.amberAccent;
      show = true;
    } else if (feedback != null) {
      title = feedback.message;
      subtext = feedback.explanation;
      accentColor = feedback.isNegative ? Colors.orangeAccent : (feedback.classification.index <= 1 ? Colors.purpleAccent : Colors.greenAccent);
      show = true;
    }

    if (!show) return const SizedBox.shrink();

    return Row(
      mainAxisSize: MainAxisSize.min,
      crossAxisAlignment: CrossAxisAlignment.end,
      children: [
        // 🤖 ANIMATED ROBOT AVATAR
        AnimatedRobotCoach(
          isThinking: isThinking,
          isHint: hint != null,
          classification: feedback?.classification,
        ).animate().slideX(begin: -0.5, end: 0, duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
        
        const SizedBox(width: 4),

        // 💬 TALK BUBBLE
        Flexible(
          child: Container(
            padding: const EdgeInsets.all(16),
            decoration: BoxDecoration(
              color: const Color(0xFF1A1A2E).withOpacity(0.95),
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(24),
                topRight: Radius.circular(24),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(24),
              ),
              border: Border.all(
                color: accentColor.withOpacity(0.6),
                width: 2,
              ),
              boxShadow: [
                BoxShadow(
                  color: accentColor.withOpacity(0.15),
                  blurRadius: 20,
                  spreadRadius: 2,
                ),
              ],
            ),
            child: Column(
              mainAxisSize: MainAxisSize.min,
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: GoogleFonts.outfit(
                    color: Colors.white,
                    fontSize: 15,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 0.5,
                  ),
                ),
                if (subtext != null) ...[
                  const SizedBox(height: 10),
                  Text(
                    subtext,
                    style: GoogleFonts.outfit(
                      color: Colors.white.withOpacity(0.85),
                      fontSize: 13,
                      height: 1.4,
                      fontWeight: FontWeight.w500,
                    ),
                  ),
                ],
                if (hint != null && hint.currentLevel < 4) ...[
                  const SizedBox(height: 12),
                  GestureDetector(
                    onTap: () => context.read<GameBloc>().add(GameRequestHintEvent()),
                    child: Container(
                      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                      decoration: BoxDecoration(
                        color: Colors.amberAccent.withOpacity(0.15),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: Colors.amberAccent.withOpacity(0.5)),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          const Icon(Icons.flash_on_rounded, color: Colors.amberAccent, size: 14),
                          const SizedBox(width: 8),
                          Text(
                            'UPGRADE HINT',
                            style: GoogleFonts.outfit(color: Colors.amberAccent, fontSize: 11, fontWeight: FontWeight.w900),
                          ),
                        ],
                      ),
                    ),
                  ),
                ],
              ],
            ),
          ).animate().slideX(begin: 0.2, end: 0, duration: 300.ms, curve: Curves.easeOut).fadeIn(),
        ),
      ],
    );
  }
}
