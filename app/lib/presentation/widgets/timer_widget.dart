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
    // Sync with server authoritative time
    _currentTime = widget.timeInSeconds;

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
    if (seconds < 5) return AppTheme.accentRed;
    if (seconds < 15) return Colors.orangeAccent;
    return widget.isActive ? AppTheme.goldPrimary : AppTheme.textMuted;
  }

  @override
  Widget build(BuildContext context) {
    final timeStr = _formatTime(_currentTime);
    final color = _getTimerColor(_currentTime);
    final isCritical = _currentTime < 5 && widget.isActive;
    final isWarning = _currentTime < 10 && widget.isActive;

    Widget content = Container(
      padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 8),
      decoration: BoxDecoration(
        color: widget.isActive
            ? AppTheme.navyCard.withValues(alpha: 0.95)
            : Colors.black.withValues(alpha: 0.2),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: widget.isActive
              ? color.withValues(alpha: 0.6)
              : Colors.transparent,
          width: 2,
        ),
        boxShadow: widget.isActive
            ? [
                BoxShadow(
                  color: color.withValues(alpha: 0.3),
                  blurRadius: 12,
                  spreadRadius: 2,
                )
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          Icon(
            Icons.timer_outlined,
            size: 14,
            color: color.withValues(alpha: 0.7),
          ),
          const SizedBox(width: 10),
          Text(
            timeStr,
            style: GoogleFonts.shareTechMono(
              color: color,
              fontSize: 24,
              fontWeight: FontWeight.bold,
              letterSpacing: 1.5,
            ),
          ),
          if (isWarning) ...[
            const SizedBox(width: 8),
            Text("⚡", style: const TextStyle(fontSize: 16))
                .animate(onPlay: (c) => c.repeat())
                .shake(hz: 3, curve: Curves.easeInOut),
          ]
        ],
      ),
    );

    if (isCritical) {
      return content
          .animate(onPlay: (c) => c.repeat())
          .scaleXY(
              begin: 1.0, end: 1.05, duration: 400.ms, curve: Curves.easeInOut)
          .then()
          .scaleXY(
              begin: 1.05, end: 1.0, duration: 400.ms, curve: Curves.easeInOut)
          .shimmer(color: Colors.white24);
    }

    return content;
  }
}
