import 'dart:async';
import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';

class TimerWidget extends StatefulWidget {
  final double timeInSeconds;
  final bool isActive;
  final String label;

  const TimerWidget({
    super.key,
    required this.timeInSeconds,
    required this.isActive,
    this.label = '',
  });

  @override
  State<TimerWidget> createState() => _TimerWidgetState();
}

class _TimerWidgetState extends State<TimerWidget> {
  late double _currentTime;
  Timer? _localTimer;

  @override
  void initState() {
    super.initState();
    _currentTime = widget.timeInSeconds;
    if (widget.isActive) _startLocalCountdown();
  }

  @override
  void didUpdateWidget(TimerWidget oldWidget) {
    super.didUpdateWidget(oldWidget);
    // Sync with server authoritative time only if the value differs significantly,
    // to prevent jitter and loops during active countdowns.
    if (widget.timeInSeconds != oldWidget.timeInSeconds) {
      if (!widget.isActive ||
          (_currentTime - widget.timeInSeconds).abs() > 0.5) {
        _currentTime = widget.timeInSeconds;
      }
    }

    if (widget.isActive != oldWidget.isActive) {
      if (widget.isActive) {
        _startLocalCountdown();
      } else {
        _stopLocalCountdown();
      }
    }
  }

  void _startLocalCountdown() {
    _localTimer?.cancel();
    _localTimer = Timer.periodic(const Duration(milliseconds: 100), (timer) {
      if (mounted) {
        setState(() {
          _currentTime = (_currentTime - 0.1).clamp(0, double.infinity);
        });
      }
    });
  }

  void _stopLocalCountdown() {
    _localTimer?.cancel();
    _localTimer = null;
  }

  @override
  void dispose() {
    _localTimer?.cancel();
    super.dispose();
  }

  String _formatTime(double seconds) {
    if (seconds <= 0) return '00:00.0';
    final int mins = (seconds / 60).floor();
    final int secs = (seconds % 60).floor();
    final int ms = ((seconds % 1) * 10).floor();

    if (seconds < 10) {
      return '$secs.$ms';
    }
    return '${mins.toString().padLeft(2, '0')}:${secs.toString().padLeft(2, '0')}';
  }

  Color _getTimerColor(double seconds) {
    if (!widget.isActive) return AppTheme.textMuted;
    if (seconds < 5) return AppTheme.accentRed;
    if (seconds < 10) return Colors.deepOrangeAccent;
    if (seconds < 20) return AppTheme.accentCyan;
    return AppTheme.accentGreen;
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(_currentTime);
    final color = _getTimerColor(_currentTime);
    final isCritical = _currentTime < 5 && widget.isActive;
    final isWarning = _currentTime < 10 && widget.isActive;
    final isUrgent = _currentTime < 20 && widget.isActive;

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
      decoration: BoxDecoration(
        color: widget.isActive
            ? AppTheme.navyCard.withValues(alpha: 0.95)
            : Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(18),
        border: Border.all(
          color: widget.isActive ? color.withValues(alpha: 0.75) : Colors.transparent,
          width: 2,
        ),
        boxShadow: widget.isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: isUrgent ? 0.25 : 0.15),
                  blurRadius: isUrgent ? 18 : 10,
                  spreadRadius: isUrgent ? 3 : 1,
                )
              ]
            : null,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          if (widget.label.isNotEmpty)
            Padding(
              padding: const EdgeInsets.only(bottom: 4),
              child: Text(
                widget.label.toUpperCase(),
                style: GoogleFonts.baloo2(
                  color: AppTheme.textMuted,
                  fontSize: 11,
                  fontWeight: FontWeight.w700,
                  letterSpacing: 1.2,
                ),
              ),
            ),
          Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                Icons.timer_outlined,
                size: 16,
                color: color.withValues(alpha: 0.85),
              ),
              const SizedBox(width: 10),
              Text(
                timeStr,
                style: GoogleFonts.shareTechMono(
                  color: color,
                  fontSize: 26,
                  fontWeight: FontWeight.w800,
                  letterSpacing: 1.5,
                ),
              ),
              if (isWarning) ...[
                const SizedBox(width: 8),
                Text('⚡', style: const TextStyle(fontSize: 18))
                    .animate(onPlay: (c) => c.repeat())
                    .shake(hz: 3, curve: Curves.easeInOut),
              ]
            ],
          ),
        ],
      ),
    );

    if (isCritical) {
      return content
          .animate(onPlay: (c) => c.repeat())
          .scaleXY(
              begin: 1.0, end: 1.06, duration: 350.ms, curve: Curves.easeInOut)
          .then()
          .scaleXY(
              begin: 1.06, end: 1.0, duration: 350.ms, curve: Curves.easeInOut)
          .shimmer(color: Colors.white24);
    }

    return content;
  }
}

