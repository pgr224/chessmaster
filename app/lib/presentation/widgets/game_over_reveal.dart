import 'dart:async';

import 'package:flutter/material.dart';

class GameOverReveal extends StatefulWidget {
  const GameOverReveal({
    super.key,
    required this.showFinalPosition,
    required this.child,
  });

  final bool showFinalPosition;
  final Widget child;

  @override
  State<GameOverReveal> createState() => _GameOverRevealState();
}

class _GameOverRevealState extends State<GameOverReveal> {
  Timer? _timer;
  bool _ready = false;
  int _generation = 0;

  @override
  void initState() {
    super.initState();
    _startReveal();
  }

  void _startReveal() {
    final generation = ++_generation;
    if (!widget.showFinalPosition) {
      _ready = true;
      return;
    }
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!mounted || generation != _generation) return;
      _timer = Timer(const Duration(milliseconds: 1200), () {
        if (mounted && generation == _generation) {
          setState(() => _ready = true);
        }
      });
    });
  }

  @override
  void didUpdateWidget(covariant GameOverReveal oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.showFinalPosition != widget.showFinalPosition) {
      _timer?.cancel();
      _ready = false;
      _startReveal();
    }
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) =>
      _ready ? widget.child : const SizedBox.shrink();
}
