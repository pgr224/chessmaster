/// ELO Rating calculation service for ranked play.
class EloService {
  static const int defaultRating = 1200;
  static const int kFactorNew = 40;     // For players with < 30 games
  static const int kFactorEstablished = 20; // For players with 30+ games

  /// Calculate new ELO ratings for both players after a game.
  /// [score] is 1.0 for a win, 0.5 for a draw, 0.0 for a loss (from player1's perspective).
  static (int, int) calculateNewRatings({
    required int player1Rating,
    required int player2Rating,
    required double score,
    int player1Games = 0,
    int player2Games = 0,
  }) {
    final k1 = player1Games < 30 ? kFactorNew : kFactorEstablished;
    final k2 = player2Games < 30 ? kFactorNew : kFactorEstablished;

    final expected1 = _expectedScore(player1Rating, player2Rating);
    final expected2 = 1.0 - expected1;

    final newRating1 = (player1Rating + k1 * (score - expected1)).round();
    final newRating2 = (player2Rating + k2 * ((1.0 - score) - expected2)).round();

    return (newRating1.clamp(100, 3500), newRating2.clamp(100, 3500));
  }

  /// Calculate expected score based on rating difference.
  static double _expectedScore(int rating1, int rating2) {
    return 1.0 / (1.0 + _pow10((rating2 - rating1) / 400.0));
  }

  static double _pow10(double exponent) {
    double result = 1.0;
    final base = 10.0;
    // Use iterative approach for precision
    final absExp = exponent.abs();
    final intPart = absExp.floor();
    final fracPart = absExp - intPart;

    for (int i = 0; i < intPart; i++) {
      result *= base;
    }
    // Approximate fractional part using ln(10) * frac
    if (fracPart > 0) {
      result *= _expApprox(fracPart * 2.302585093); // ln(10) ≈ 2.302585093
    }

    return exponent < 0 ? 1.0 / result : result;
  }

  static double _expApprox(double x) {
    // Taylor series approximation for e^x
    double sum = 1.0;
    double term = 1.0;
    for (int i = 1; i <= 20; i++) {
      term *= x / i;
      sum += term;
    }
    return sum;
  }

  /// Get rank title based on ELO rating.
  static String getRankTitle(int rating) {
    if (rating >= 2400) return 'Super Grandmaster';
    if (rating >= 2200) return 'Grandmaster';
    if (rating >= 2000) return 'International Master';
    if (rating >= 1800) return 'FIDE Master';
    if (rating >= 1600) return 'Expert';
    if (rating >= 1400) return 'Class A';
    if (rating >= 1200) return 'Class B';
    if (rating >= 1000) return 'Class C';
    if (rating >= 800) return 'Class D';
    return 'Beginner';
  }

  /// Get rank emoji based on ELO rating.
  static String getRankEmoji(int rating) {
    if (rating >= 2400) return '👑';
    if (rating >= 2200) return '🎖️';
    if (rating >= 2000) return '🏆';
    if (rating >= 1800) return '🥇';
    if (rating >= 1600) return '🥈';
    if (rating >= 1400) return '🥉';
    if (rating >= 1200) return '⭐';
    if (rating >= 1000) return '🌟';
    if (rating >= 800) return '💫';
    return '🌱';
  }

  /// Get rank color hex based on ELO rating.
  static int getRankColorValue(int rating) {
    if (rating >= 2400) return 0xFFFFD700; // Gold
    if (rating >= 2200) return 0xFFC0C0C0; // Silver
    if (rating >= 2000) return 0xFFCD7F32; // Bronze
    if (rating >= 1800) return 0xFF9966CC; // Purple
    if (rating >= 1600) return 0xFF4169E1; // Royal Blue
    if (rating >= 1400) return 0xFF00CED1; // Teal
    if (rating >= 1200) return 0xFF32CD32; // Lime green
    if (rating >= 1000) return 0xFFFFA500; // Orange
    return 0xFF808080; // Gray
  }

  /// Calculate ELO change against AI based on difficulty.
  static (int, int) calculateVsAI({
    required int playerRating,
    required String difficulty,
    required double score,
    int playerGames = 0,
  }) {
    final aiRating = switch (difficulty) {
      'basic' => 800,
      'intermediate' => 1200,
      'advanced' => 1600,
      'impossible' => 2200,
      _ => 1200,
    };

    return calculateNewRatings(
      player1Rating: playerRating,
      player2Rating: aiRating,
      score: score,
      player1Games: playerGames,
      player2Games: 1000, // AI is "established"
    );
  }
}
