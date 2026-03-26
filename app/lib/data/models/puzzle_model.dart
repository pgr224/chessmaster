import 'package:equatable/equatable.dart';

class Puzzle extends Equatable {
  final String id;
  final String title;
  final String description;
  final String initialFEN;
  final List<PuzzleMove> moves;
  final String reward;

  const Puzzle({
    required this.id,
    required this.title,
    required this.description,
    required this.initialFEN,
    required this.moves,
    required this.reward,
  });

  @override
  List<Object?> get props => [id, title, description, initialFEN, moves, reward];
}

class PuzzleMove extends Equatable {
  final String move; // SAN or UCI, typically UCI here for simplicity e2e4
  final String hint;
  final String dialog;
  final String successDialog;

  const PuzzleMove({
    required this.move,
    required this.hint,
    required this.dialog,
    required this.successDialog,
  });

  @override
  List<Object?> get props => [move, hint, dialog, successDialog];
}
