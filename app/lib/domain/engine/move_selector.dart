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
      {double errorChance = 0.05, int maxCentipawnLoss = 80}) {
    if (candidates.isEmpty) return MoveCandidate(uci: 'none', score: 0);

    final bestScore = candidates.first.score;
    final playable = candidates
        .where((candidate) => candidate.score >= bestScore - maxCentipawnLoss)
        .toList(growable: false);
    final pool = playable.isEmpty ? candidates : playable;

    // Apply "Human Error" system
    final rand = math.Random();
    if (rand.nextDouble() < errorChance) {
      // Pick a safe off-best move to match the player without hanging the game.
      return pool[rand.nextInt(pool.length)];
    }

    // Advanced: Score each candidate according to personality
    final scoredCandidates = pool.map((m) {
      double score = m.score.toDouble();
      final traits = _uciTraits(m.uci);

      // Personality Bonuses
      if (personality == AIPersonality.aggressive) {
        if (m.score > bestScore - 50) score += 140;
        if (traits.isCentral) score += 28;
        if (traits.isForward) score += 24;
        if (traits.isPromotion) score += 60;
      } else if (personality == AIPersonality.defensive) {
        if (m.score > bestScore - 70) score += 95;
        if (traits.isCastle) score += 70;
        if (traits.isRetreat) score += 22;
        if (traits.isEdgePawn) score -= 25;
      } else if (personality == AIPersonality.tricky) {
        final candidateIndex = candidates.indexOf(m);
        if (candidateIndex >= 1 && candidateIndex <= 3) score += 85;
        if (traits.isCentral || traits.isForward) score += 18;
        score += rand.nextInt(120);
      } else if (personality == AIPersonality.coach) {
        if (m.score > bestScore - 40) score += 80;
      }

      // Add small individual randomness to every move score
      score += rand.nextDouble() * 50;

      return (move: m, adjustedScore: score);
    }).toList();

    // Sort by adjusted score and return the best one
    scoredCandidates.sort((a, b) => b.adjustedScore.compareTo(a.adjustedScore));
    return scoredCandidates.first.move;
  }

  _MoveTraits _uciTraits(String uci) {
    if (uci.length < 4) return const _MoveTraits();

    final fromFile = uci.codeUnitAt(0) - 97;
    final fromRank = int.tryParse(uci[1]) ?? 1;
    final toFile = uci.codeUnitAt(2) - 97;
    final toRank = int.tryParse(uci[3]) ?? 1;
    final rankDelta = toRank - fromRank;

    return _MoveTraits(
      isCastle: (uci.startsWith('e1') || uci.startsWith('e8')) &&
          (toFile - fromFile).abs() == 2,
      isCentral: toFile >= 2 && toFile <= 5 && toRank >= 3 && toRank <= 6,
      isForward: rankDelta.abs() >= 2 || toRank == 7 || toRank == 2,
      isRetreat: rankDelta.abs() == 1 && (toRank == 1 || toRank == 8),
      isEdgePawn: fromFile == 0 || fromFile == 7,
      isPromotion: uci.length == 5,
    );
  }
}

class _MoveTraits {
  final bool isCastle;
  final bool isCentral;
  final bool isForward;
  final bool isRetreat;
  final bool isEdgePawn;
  final bool isPromotion;

  const _MoveTraits({
    this.isCastle = false,
    this.isCentral = false,
    this.isForward = false,
    this.isRetreat = false,
    this.isEdgePawn = false,
    this.isPromotion = false,
  });
}
