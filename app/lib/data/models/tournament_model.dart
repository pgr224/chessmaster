class TournamentPlayer {
  final String id;
  final String username;
  final int rating;
  final double score;
  final int wins;
  final int losses;
  final int draws;
  final double accuracy;
  final int averageOpponentRating;
  final int longestWinStreak;
  final int ratingChange;

  const TournamentPlayer({
    required this.id,
    required this.username,
    required this.rating,
    required this.score,
    required this.wins,
    required this.losses,
    required this.draws,
    this.accuracy = 0,
    this.averageOpponentRating = 0,
    this.longestWinStreak = 0,
    this.ratingChange = 0,
  });

  factory TournamentPlayer.fromJson(Map<String, dynamic> json) {
    return TournamentPlayer(
      id: json['id'] as String? ?? json['user_id'] as String? ?? '',
      username: json['username'] as String? ?? 'Player',
      rating: (json['rating'] as num?)?.toInt() ?? 1200,
      score: (json['score'] as num?)?.toDouble() ??
          (json['points'] as num?)?.toDouble() ??
          0.0,
      wins: (json['wins'] as num?)?.toInt() ?? 0,
      losses: (json['losses'] as num?)?.toInt() ?? 0,
      draws: (json['draws'] as num?)?.toInt() ?? 0,
        accuracy: (json['accuracy'] as num?)?.toDouble() ?? 0,
        averageOpponentRating:
          (json['averageOpponentRating'] as num?)?.toInt() ??
            (json['average_opponent_rating'] as num?)?.toInt() ??
            0,
        longestWinStreak: (json['longestWinStreak'] as num?)?.toInt() ??
          (json['longest_win_streak'] as num?)?.toInt() ??
          0,
        ratingChange: (json['ratingChange'] as num?)?.toInt() ??
          (json['rating_change'] as num?)?.toInt() ??
          0,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'rating': rating,
        'score': score,
        'wins': wins,
        'losses': losses,
        'draws': draws,
        'accuracy': accuracy,
        'averageOpponentRating': averageOpponentRating,
        'longestWinStreak': longestWinStreak,
        'ratingChange': ratingChange,
      };
}

class TournamentMatch {
  final int roundNumber;
  final String player1Id;
  final String player2Id;
  final String? winnerId;
  final String? gameId;
  final String status; // 'pending' | 'active' | 'completed'
  final String? result; // 'player1' | 'player2' | 'draw'

  const TournamentMatch({
    required this.roundNumber,
    required this.player1Id,
    required this.player2Id,
    this.winnerId,
    this.gameId,
    required this.status,
    this.result,
  });

  factory TournamentMatch.fromJson(Map<String, dynamic> json) {
    return TournamentMatch(
      roundNumber: (json['round_number'] as num?)?.toInt() ?? 1,
      player1Id: json['player1_id'] as String? ?? json['player1']?['id'] as String? ?? '',
      player2Id: json['player2_id'] as String? ?? json['player2']?['id'] as String? ?? '',
      winnerId: json['winner_id'] as String?,
      gameId: json['game_id'] as String? ?? json['gameId'] as String?,
      status: json['status'] as String? ?? 'pending',
      result: json['result'] as String?,
    );
  }
}

class TournamentPairing {
  final String gameId;
  final TournamentPlayer player1;
  final TournamentPlayer player2;
  final String player1Color; // 'white' | 'black'
  final String player2Color;
  final int moveCount;
  final int captureCount;
  final double evalSwing;
  final double whiteAccuracy;
  final double blackAccuracy;
  final int whiteTimeUsed;
  final int blackTimeUsed;
  final String status;

  const TournamentPairing({
    required this.gameId,
    required this.player1,
    required this.player2,
    required this.player1Color,
    required this.player2Color,
    this.moveCount = 0,
    this.captureCount = 0,
    this.evalSwing = 0,
    this.whiteAccuracy = 0,
    this.blackAccuracy = 0,
    this.whiteTimeUsed = 0,
    this.blackTimeUsed = 0,
    this.status = 'pending',
  });

  factory TournamentPairing.fromJson(Map<String, dynamic> json) {
    final p1 = json['player1'] as Map<String, dynamic>? ?? {};
    final p2 = json['player2'] as Map<String, dynamic>? ?? {};
    return TournamentPairing(
      gameId: json['gameId'] as String? ?? json['game_id'] as String? ?? '',
      player1: TournamentPlayer.fromJson(p1),
      player2: TournamentPlayer.fromJson(p2),
      player1Color: p1['color'] as String? ?? 'white',
      player2Color: p2['color'] as String? ?? 'black',
        moveCount: (json['moveCount'] as num?)?.toInt() ??
          (json['move_count'] as num?)?.toInt() ??
          0,
        captureCount: (json['captureCount'] as num?)?.toInt() ??
          (json['capture_count'] as num?)?.toInt() ??
          0,
        evalSwing: (json['evalSwing'] as num?)?.toDouble() ??
          (json['eval_swing'] as num?)?.toDouble() ??
          0,
        whiteAccuracy: (json['whiteAccuracy'] as num?)?.toDouble() ??
          (json['white_accuracy'] as num?)?.toDouble() ??
          0,
        blackAccuracy: (json['blackAccuracy'] as num?)?.toDouble() ??
          (json['black_accuracy'] as num?)?.toDouble() ??
          0,
        whiteTimeUsed: (json['whiteTimeUsed'] as num?)?.toInt() ??
          (json['timeUsed']?['white'] as num?)?.toInt() ??
          0,
        blackTimeUsed: (json['blackTimeUsed'] as num?)?.toInt() ??
          (json['timeUsed']?['black'] as num?)?.toInt() ??
          0,
        status: json['status'] as String? ?? 'pending',
    );
  }
}

class TournamentModel {
  final String id;
  final String name;
  final String type; // 'public' | 'private'
  final String format; // 'swiss' | 'best_of'
  final String status; // 'waiting' | 'active' | 'finished'
  final int totalRounds;
  final int currentRound;
  final String timeControl;
  final List<TournamentPlayer> players;
  final List<TournamentPairing> currentPairings;

  const TournamentModel({
    required this.id,
    required this.name,
    required this.type,
    required this.format,
    required this.status,
    required this.totalRounds,
    required this.currentRound,
    required this.timeControl,
    required this.players,
    required this.currentPairings,
  });

  factory TournamentModel.fromJson(Map<String, dynamic> json) {
    final t = json['tournament'] as Map<String, dynamic>? ?? json;
    final playerList = (t['players'] as List<dynamic>?)
            ?.map((e) => TournamentPlayer.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    final pairings = (t['pairings'] as List<dynamic>?)
            ?.map((e) => TournamentPairing.fromJson(e as Map<String, dynamic>))
            .toList() ??
        [];
    return TournamentModel(
      id: t['id'] as String? ?? '',
      name: t['name'] as String? ?? 'Tournament',
      type: t['type'] as String? ?? 'public',
      format: t['format'] as String? ?? 'swiss',
      status: t['status'] as String? ?? 'waiting',
      totalRounds: (t['total_rounds'] as num?)?.toInt() ??
          (t['totalRounds'] as num?)?.toInt() ??
          3,
      currentRound: (t['current_round'] as num?)?.toInt() ??
          (t['currentRound'] as num?)?.toInt() ??
          0,
      timeControl: t['time_control'] as String? ??
          t['timeControl'] as String? ??
          '10+0',
      players: playerList,
      currentPairings: pairings,
    );
  }
}
