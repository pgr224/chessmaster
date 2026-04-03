import 'package:flutter/material.dart';
import 'package:chess_master/presentation/blocs/game/game_bloc.dart';
import './reacting_robot_widget.dart';

/// CoachInteractionWidget — Now delegates entirely to the unified ReactingRobotWidget.
/// Kept as a thin wrapper for backward compatibility with game_screen.dart references.
class CoachInteractionWidget extends StatelessWidget {
  final GameState state;

  const CoachInteractionWidget({super.key, required this.state});

  @override
  Widget build(BuildContext context) {
    return ReactingRobotWidget(state: state);
  }
}
