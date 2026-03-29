import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';

class ThinkingOverlayWidget extends StatefulWidget {
  const ThinkingOverlayWidget({super.key});

  @override
  State<ThinkingOverlayWidget> createState() => _ThinkingOverlayWidgetState();
}

class _ThinkingOverlayWidgetState extends State<ThinkingOverlayWidget> {
  int _messageIndex = 0;
  Timer? _timer;

  final List<String> _messages = [
    "🤔 Hmm... this is getting tricky",
    "⏳ I'm still thinking...",
    "😅 You’ve put me in a tough spot",
    "🧠 Calculating best move...",
    "♟️ This position is complex",
    "🧩 Let me find a way out...",
    "👀 Looking for the best square",
    "💭 Finding a path to victory...",
    "🤖 Search depth increasing...",
    "🛡️ Solidifying my position!"
  ];

  @override
  void initState() {
    super.initState();
    _timer = Timer.periodic(const Duration(milliseconds: 2500), (timer) {
      if (mounted) {
        setState(() {
          _messageIndex = (_messageIndex + 1) % _messages.length;
        });
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
      decoration: BoxDecoration(
        color: Colors.black.withValues(alpha: 0.7),
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.3)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.skyBlue.withValues(alpha: 0.2),
            blurRadius: 10,
            spreadRadius: 2,
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          const SizedBox(
            width: 20,
            height: 20,
            child: CircularProgressIndicator(
              strokeWidth: 2,
              valueColor: AlwaysStoppedAnimation<Color>(AppTheme.accentCyan),
            ),
          ),
          const SizedBox(width: 14),
          AnimatedSwitcher(
            duration: 400.ms,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: anim.drive(Tween<Offset>(
                  begin: const Offset(0, 0.2),
                  end: Offset.zero,
                )),
                child: child,
              ),
            ),
            child: Text(
              _messages[_messageIndex],
              key: ValueKey(_messageIndex),
              style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary,
                fontSize: 14,
                fontWeight: FontWeight.w500,
              ),
            ),
          ),
          const SizedBox(width: 8),
          _AnimatedDots(),
        ],
      ),
    ).animate().fadeIn().scale(begin: const Offset(0.9, 0.9));
  }
}

class _AnimatedDots extends StatefulWidget {
  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots> with SingleTickerProviderStateMixin {
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
          width: 24,
          child: Text(
            '.' * dots,
            style: GoogleFonts.fredoka(color: AppTheme.accentCyan, fontSize: 16, fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}
