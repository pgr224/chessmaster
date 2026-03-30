class MoveCandidate {
  final String uci;
  final int score; // Centipawns

  MoveCandidate({required this.uci, required this.score});

  @override
  String toString() => 'MoveCandidate($uci, cp: $score)';
}
