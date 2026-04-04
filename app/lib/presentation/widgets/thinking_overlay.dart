import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../../core/theme/app_theme.dart';

class ThinkingOverlayWidget extends StatefulWidget {
  final bool compact;
  final String? message;
  const ThinkingOverlayWidget({super.key, this.compact = false, this.message});

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
    if (widget.compact) {
      return _buildCompact(context);
    }

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
              widget.message ?? _messages[_messageIndex],
              key: ValueKey(widget.message ?? _messageIndex.toString()),
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

  Widget _buildCompact(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: AppTheme.midnight.withValues(alpha: 0.8),
        borderRadius: BorderRadius.circular(12),
        border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.2)),
        boxShadow: [
          BoxShadow(
            color: AppTheme.goldPrimary.withValues(alpha: 0.1),
            blurRadius: 4,
          )
        ],
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          AnimatedSwitcher(
            duration: 400.ms,
            transitionBuilder: (child, anim) => FadeTransition(
              opacity: anim,
              child: SlideTransition(
                position: anim.drive(Tween<Offset>(
                  begin: const Offset(0, 0.4),
                  end: Offset.zero,
                )),
                child: child,
              ),
            ),
            child: Text(
              widget.message ?? _messages[_messageIndex],
              key: ValueKey(widget.message ?? _messageIndex.toString()),
              style: GoogleFonts.fredoka(
                color: AppTheme.goldPrimary,
                fontSize: 11,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
          const SizedBox(width: 4),
          _AnimatedDots(size: 10),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.2);
  }
}

class _AnimatedDots extends StatefulWidget {
  final double size;
  const _AnimatedDots({this.size = 16});

  @override
  State<_AnimatedDots> createState() => _AnimatedDotsState();
}

class _AnimatedDotsState extends State<_AnimatedDots>
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
          width: widget.size * 1.5,
          child: Text(
            '.' * dots,
            style: GoogleFonts.fredoka(
                color: AppTheme.accentCyan,
                fontSize: widget.size,
                fontWeight: FontWeight.bold),
          ),
        );
      },
    );
  }
}
