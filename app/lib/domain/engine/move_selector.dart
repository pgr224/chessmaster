import 'dart:math' as math;
import 'candidate_model.dart';
import 'personality_engine.dart';

class MoveSelector {
  static final MoveSelector _instance = MoveSelector._internal();
  factory MoveSelector() => _instance;
  MoveSelector._internal();

  /// Select a move from candidates based on active personality and random variance.
  /// Each candidate has its Stockfish CP score.
  MoveCandidate select(
      List<MoveCandidate> candidates, AIPersonality personality,
      {double errorChance = 0.05}) {
    if (candidates.isEmpty) return MoveCandidate(uci: 'none', score: 0);

    // Apply "Human Error" system
    final rand = math.Random();
    if (rand.nextDouble() < errorChance) {
      // Pick a random move among top candidates (some "clumsiness")
      return candidates[rand.nextInt(candidates.length)];
    }

    // Advanced: Score each candidate according to personality
    final scoredCandidates = candidates.map((m) {
      double score = m.score.toDouble();

      // Personality Bonuses
      if (personality == AIPersonality.aggressive) {
        // Simple heuristic: bonuses for checks or piece captures are best handled by engine cp.
        // But we can add extra "bias" for higher-score (more likely tactical) moves.
        if (m.score > candidates.first.score - 50)
          score += 200; // Prefer best aggressive lines
      } else if (personality == AIPersonality.defensive) {
        // Defensive often picks very solid, lower-variance moves.
        // If it's a "blunder-less" move (within 80cp of best), it's good.
        if (m.score > candidates.first.score - 100) score += 100;
      } else if (personality == AIPersonality.tricky) {
        // Tricky might pick the 3rd or 4th move to set a "trap".
        // Often these are lines with high variance.
        score += math.Random().nextInt(150); // Adds noise
      }

      // Add small individual randomness to every move score
      score += rand.nextDouble() * 50;

      return (move: m, adjustedScore: score);
    }).toList();

    // Sort by adjusted score and return the best one
    scoredCandidates.sort((a, b) => b.adjustedScore.compareTo(a.adjustedScore));
    return scoredCandidates.first.move;
  }
}
