import 'package:equatable/equatable.dart';

class Puzzle extends Equatable {
  final String id;
  final String title;
  final String description;
  final String initialFEN;
  final List<PuzzleMove> moves;
  final String reward;
  final int? rating;
  final List<String>? themes;
  final String? gameId;

  const Puzzle({
    required this.id,
    required this.title,
    required this.description,
    required this.initialFEN,
    required this.moves,
    required this.reward,
    this.rating,
    this.themes,
    this.gameId,
  });

  @override
  List<Object?> get props => [id, title, description, initialFEN, moves, reward, rating, themes, gameId];
}

class PuzzleMove extends Equatable {
  final String move; // typically SAN (e.g. Nf3)
  final String uciMove; // typically UCI (e.g. g1f3)
  final String hint;
  final String dialog;
  final String successDialog;

  const PuzzleMove({
    required this.move,
    required this.uciMove,
    required this.hint,
    required this.dialog,
    required this.successDialog,
  });

  @override
  List<Object?> get props => [move, uciMove, hint, dialog, successDialog];
}
