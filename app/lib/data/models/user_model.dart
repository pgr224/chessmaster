import 'game_record_model.dart';

class UserModel {
  final String id;
  final String username;
  final String? avatarUrl;
  final String? localAvatar;
  final int xp;
  final bool isOnline;
  final UserStats stats;
  final String deviceId;
  final List<GameRecord> recentGames;
  final bool isGhibli;

  const UserModel({
    required this.id,
    required this.username,
    this.avatarUrl,
    this.localAvatar,
    required this.xp,
    required this.isOnline,
    required this.stats,
    required this.deviceId,
    this.recentGames = const [],
    this.isGhibli = false,
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    bool parseBool(dynamic val, bool fallback) {
      if (val == null) return fallback;
      if (val is bool) return val;
      if (val is int) return val == 1;
      if (val is String) return val.toLowerCase() == 'true' || val == '1';
      return fallback;
    }

    return UserModel(
      id: (json['id'] ?? '').toString(),
      username: (json['username'] ?? 'User').toString(),
      avatarUrl: json['avatar_url'] as String?,
      localAvatar: json['local_avatar'] as String?,
      xp: json['xp'] as int? ?? 0,
      isOnline: parseBool(json['is_online'], false),
      stats: UserStats.fromJson(json['stats'] as Map<String, dynamic>? ?? {}),
      deviceId: (json['device_id'] ?? '').toString(),
      isGhibli: parseBool(json['is_ghibli'], false),
      recentGames: (json['recent_games'] as List? ?? [])
          .map((g) => GameRecord.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'username': username,
        'avatar_url': avatarUrl,
        'local_avatar': localAvatar,
        'xp': xp,
        'is_online': isOnline ? 1 : 0,
        'device_id': deviceId,
        'is_ghibli': isGhibli,
        'stats': {
          'games_played': stats.gamesPlayed,
          'wins': stats.wins,
          'losses': stats.losses,
          'draws': stats.draws,
          'longest_streak': stats.longestStreak,
          'current_streak': stats.currentStreak,
          'ai_games': stats.aiGames,
          'ai_wins': stats.aiWins,
          'multiplayer_games': stats.multiplayerGames,
          'multiplayer_wins': stats.multiplayerWins,
          'two_player_games': stats.twoPlayerGames,
          'two_player_wins': stats.twoPlayerWins,
          'tournament_wins': stats.tournamentWins,
          'practice_difficulty': stats.practiceDifficulty,
          'elo_rating': stats.eloRating,
          'puzzles_solved': stats.puzzlesSolved,
          'puzzle_rating': stats.puzzleRating,
        },
        'recent_games': recentGames.map((g) => g.toJson()).toList(),
      };

  UserModel copyWith({
    String? id,
    String? username,
    String? avatarUrl,
    String? localAvatar,
    int? xp,
    bool? isOnline,
    UserStats? stats,
    String? deviceId,
    List<GameRecord>? recentGames,
    bool? isGhibli,
  }) {
    return UserModel(
      id: id ?? this.id,
      username: username ?? this.username,
      avatarUrl: avatarUrl ?? this.avatarUrl,
      localAvatar: localAvatar ?? this.localAvatar,
      xp: xp ?? this.xp,
      isOnline: isOnline ?? this.isOnline,
      stats: stats ?? this.stats,
      deviceId: deviceId ?? this.deviceId,
      recentGames: recentGames ?? this.recentGames,
      isGhibli: isGhibli ?? this.isGhibli,
    );
  }
}

class UserStats {
  final int gamesPlayed;
  final int wins;
  final int losses;
  final int draws;
  final int longestStreak;
  final int currentStreak;
  final int aiGames;
  final int aiWins;
  final int multiplayerGames;
  final int multiplayerWins;
  final int twoPlayerGames;
  final int twoPlayerWins;
  final int tournamentWins;
  final double practiceDifficulty;
  final int eloRating;
  final int puzzlesSolved;
  final int puzzleRating;

  const UserStats({
    this.gamesPlayed = 0,
    this.wins = 0,
    this.losses = 0,
    this.draws = 0,
    this.longestStreak = 0,
    this.currentStreak = 0,
    this.aiGames = 0,
    this.aiWins = 0,
    this.multiplayerGames = 0,
    this.multiplayerWins = 0,
    this.twoPlayerGames = 0,
    this.twoPlayerWins = 0,
    this.tournamentWins = 0,
    this.practiceDifficulty = 1.0,
    this.eloRating = 1200,
    this.puzzlesSolved = 0,
    this.puzzleRating = 1200,
  });

  double get winRate => gamesPlayed > 0 ? wins / gamesPlayed * 100 : 0;
  double get aiWinRate => aiGames > 0 ? aiWins / aiGames * 100 : 0;
  double get mpWinRate =>
      multiplayerGames > 0 ? multiplayerWins / multiplayerGames * 100 : 0;
  double get twoPlayerWinRate =>
      twoPlayerGames > 0 ? twoPlayerWins / twoPlayerGames * 100 : 0;

  factory UserStats.fromJson(Map<String, dynamic> json) {
    return UserStats(
      gamesPlayed: json['games_played'] as int? ?? 0,
      wins: json['wins'] as int? ?? 0,
      losses: json['losses'] as int? ?? 0,
      draws: json['draws'] as int? ?? 0,
      longestStreak: json['longest_streak'] as int? ?? 0,
      currentStreak: json['current_streak'] as int? ?? 0,
      aiGames: json['ai_games'] as int? ?? 0,
      aiWins: json['ai_wins'] as int? ?? 0,
      multiplayerGames: json['multiplayer_games'] as int? ?? 0,
      multiplayerWins: json['multiplayer_wins'] as int? ?? 0,
      twoPlayerGames: json['two_player_games'] as int? ?? 0,
      twoPlayerWins: json['two_player_wins'] as int? ?? 0,
      tournamentWins: json['tournament_wins'] as int? ?? 0,
      practiceDifficulty:
          (json['practice_difficulty'] as num?)?.toDouble() ?? 1.0,
      eloRating: json['elo_rating'] as int? ?? 1200,
      puzzlesSolved: json['puzzles_solved'] as int? ?? 0,
      puzzleRating: json['puzzle_rating'] as int? ?? 1200,
    );
  }
}
