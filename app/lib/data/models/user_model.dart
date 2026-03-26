import 'game_record_model.dart';

class UserModel {
  final String id;
  final String username;
  final String? avatarUrl;
  final int xp;
  final bool isOnline;
  final UserStats stats;
  final String deviceId;
  final List<GameRecord> recentGames;

  const UserModel({
    required this.id,
    required this.username,
    this.avatarUrl,
    required this.xp,
    required this.isOnline,
    required this.stats,
    required this.deviceId,
    this.recentGames = const [],
  });

  factory UserModel.fromJson(Map<String, dynamic> json) {
    return UserModel(
      id: json['id'] as String,
      username: json['username'] as String,
      avatarUrl: json['avatar_url'] as String?,
      xp: json['xp'] as int? ?? 0,
      isOnline: (json['is_online'] as int? ?? 0) == 1,
      stats: UserStats.fromJson(json['stats'] as Map<String, dynamic>? ?? {}),
      deviceId: json['device_id'] as String? ?? '',
      recentGames: (json['recent_games'] as List? ?? [])
          .map((g) => GameRecord.fromJson(g as Map<String, dynamic>))
          .toList(),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'username': username,
    'avatar_url': avatarUrl,
    'xp': xp,
    'is_online': isOnline ? 1 : 0,
    'device_id': deviceId,
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
      'tournament_wins': stats.tournamentWins,
    },
    'recent_games': recentGames.map((g) => g.toJson()).toList(),
  };
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
  final int tournamentWins;

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
    this.tournamentWins = 0,
  });

  double get winRate => gamesPlayed > 0 ? wins / gamesPlayed * 100 : 0;

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
      tournamentWins: json['tournament_wins'] as int? ?? 0,
    );
  }
}
