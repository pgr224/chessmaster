import 'package:equatable/equatable.dart';

enum AchievementCategory {
  beginner,
  combat,
  strategy,
  endgame,
  speed,
  social,
  mastery,
  collection,
  special,
}

class Achievement extends Equatable {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int points;
  final bool isUnlocked;
  final DateTime? unlockedAt;
  final AchievementCategory category;
  final int? requiredCount; // For progressive achievements
  final int currentProgress;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.points,
    this.isUnlocked = false,
    this.unlockedAt,
    this.category = AchievementCategory.beginner,
    this.requiredCount,
    this.currentProgress = 0,
  });

  double get progressPercent {
    if (requiredCount == null || requiredCount == 0)
      return isUnlocked ? 1.0 : 0.0;
    return (currentProgress / requiredCount!).clamp(0.0, 1.0);
  }

  Achievement copyWith({
    bool? isUnlocked,
    DateTime? unlockedAt,
    int? currentProgress,
  }) {
    return Achievement(
      id: id,
      title: title,
      description: description,
      icon: icon,
      points: points,
      isUnlocked: isUnlocked ?? this.isUnlocked,
      unlockedAt: unlockedAt ?? this.unlockedAt,
      category: category,
      requiredCount: requiredCount,
      currentProgress: currentProgress ?? this.currentProgress,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'isUnlocked': isUnlocked,
        'unlockedAt': unlockedAt?.toIso8601String(),
        'currentProgress': currentProgress,
      };

  factory Achievement.fromSavedJson(
      Map<String, dynamic> json, Achievement template) {
    return template.copyWith(
      isUnlocked: json['isUnlocked'] as bool? ?? false,
      unlockedAt: json['unlockedAt'] != null
          ? DateTime.tryParse(json['unlockedAt'] as String)
          : null,
      currentProgress: json['currentProgress'] as int? ?? 0,
    );
  }

  @override
  List<Object?> get props => [id, isUnlocked, currentProgress];
}

// ═══════════════════════════════════════════
// 55 ACHIEVEMENT BADGES
// ═══════════════════════════════════════════
final List<Achievement> allAchievements = [
  // ── BEGINNER (10) ──
  const Achievement(
      id: 'first_move',
      title: 'Baby Steps',
      description: 'Make your very first move in a chess game.',
      icon: '👶',
      points: 5,
      category: AchievementCategory.beginner),
  const Achievement(
      id: 'first_win',
      title: 'First Blood',
      description: 'Win your first game against AI or a player.',
      icon: '🏆',
      points: 10,
      category: AchievementCategory.beginner),
  const Achievement(
      id: 'first_capture',
      title: 'Piece Collector',
      description: 'Capture your first enemy piece.',
      icon: '🥊',
      points: 5,
      category: AchievementCategory.beginner),
  const Achievement(
      id: 'first_check',
      title: 'King Hunter',
      description: 'Put the opponent king in check for the first time.',
      icon: '👑',
      points: 10,
      category: AchievementCategory.beginner),
  const Achievement(
      id: 'first_castle',
      title: 'Castle Builder',
      description: 'Perform your first castling move.',
      icon: '🏰',
      points: 10,
      category: AchievementCategory.beginner),
  const Achievement(
      id: 'complete_tutorial',
      title: 'Star Student',
      description: 'Complete any tutorial lesson.',
      icon: '📚',
      points: 15,
      category: AchievementCategory.beginner),
  const Achievement(
      id: 'play_5_games',
      title: 'Getting Started',
      description: 'Play 5 games in any mode.',
      icon: '🎮',
      points: 15,
      category: AchievementCategory.beginner,
      requiredCount: 5),
  const Achievement(
      id: 'play_all_modes',
      title: 'Explorer',
      description: 'Play at least one game in every game mode.',
      icon: '🗺️',
      points: 25,
      category: AchievementCategory.beginner),
  const Achievement(
      id: 'use_hint',
      title: 'Wise Owl',
      description: 'Use a hint during a game.',
      icon: '🦉',
      points: 5,
      category: AchievementCategory.beginner),
  const Achievement(
      id: 'first_undo',
      title: 'Time Traveler',
      description: 'Use undo for the first time.',
      icon: '⏪',
      points: 5,
      category: AchievementCategory.beginner),

  // ── COMBAT (10) ──
  const Achievement(
      id: 'win_10',
      title: 'Seasoned Fighter',
      description: 'Win 10 games total.',
      icon: '⚔️',
      points: 30,
      category: AchievementCategory.combat,
      requiredCount: 10),
  const Achievement(
      id: 'win_50',
      title: 'Veteran Warrior',
      description: 'Win 50 games total.',
      icon: '🛡️',
      points: 75,
      category: AchievementCategory.combat,
      requiredCount: 50),
  const Achievement(
      id: 'win_100',
      title: 'Centurion',
      description: 'Win 100 games total.',
      icon: '💯',
      points: 150,
      category: AchievementCategory.combat,
      requiredCount: 100),
  const Achievement(
      id: 'win_streak_3',
      title: 'Hot Streak',
      description: 'Win 3 games in a row.',
      icon: '🔥',
      points: 25,
      category: AchievementCategory.combat,
      requiredCount: 3),
  const Achievement(
      id: 'win_streak_5',
      title: 'On Fire',
      description: 'Win 5 games in a row.',
      icon: '🌋',
      points: 50,
      category: AchievementCategory.combat,
      requiredCount: 5),
  const Achievement(
      id: 'win_streak_10',
      title: 'Unstoppable',
      description: 'Win 10 games in a row.',
      icon: '💥',
      points: 100,
      category: AchievementCategory.combat,
      requiredCount: 10),
  const Achievement(
      id: 'beat_ai_basic',
      title: 'Robot Beater',
      description: 'Beat the Basic AI.',
      icon: '🤖',
      points: 10,
      category: AchievementCategory.combat),
  const Achievement(
      id: 'beat_ai_intermediate',
      title: 'Machine Breaker',
      description: 'Beat the Intermediate AI.',
      icon: '⚙️',
      points: 25,
      category: AchievementCategory.combat),
  const Achievement(
      id: 'beat_ai_advanced',
      title: 'Terminator',
      description: 'Beat the Advanced AI.',
      icon: '🦾',
      points: 50,
      category: AchievementCategory.combat),
  const Achievement(
      id: 'beat_ai_impossible',
      title: 'Godlike',
      description: 'Beat the Impossible AI.',
      icon: '👼',
      points: 200,
      category: AchievementCategory.combat),

  // ── STRATEGY (8) ──
  const Achievement(
      id: 'pawn_promotion',
      title: 'Pawn Star',
      description: 'Promote a pawn to a Queen.',
      icon: '👸',
      points: 20,
      category: AchievementCategory.strategy),
  const Achievement(
      id: 'promote_knight',
      title: 'Knight Rider',
      description: 'Underpromote a pawn to a Knight.',
      icon: '🐴',
      points: 30,
      category: AchievementCategory.strategy),
  const Achievement(
      id: 'en_passant',
      title: 'Sneaky Move',
      description: 'Capture a pawn using en passant.',
      icon: '🥷',
      points: 25,
      category: AchievementCategory.strategy),
  const Achievement(
      id: 'fork_master',
      title: 'Fork Master',
      description: 'Win a game after performing a fork.',
      icon: '🍴',
      points: 30,
      category: AchievementCategory.strategy),
  const Achievement(
      id: 'no_pieces_lost',
      title: 'Untouchable',
      description: 'Win without losing a single piece.',
      icon: '🛡️',
      points: 100,
      category: AchievementCategory.strategy),
  const Achievement(
      id: 'accuracy_90',
      title: 'Precision Player',
      description: 'Finish a game with 90%+ accuracy.',
      icon: '🎯',
      points: 50,
      category: AchievementCategory.strategy),
  const Achievement(
      id: 'accuracy_95',
      title: 'Near Perfect',
      description: 'Finish a game with 95%+ accuracy.',
      icon: '💎',
      points: 100,
      category: AchievementCategory.strategy),
  const Achievement(
      id: 'zero_blunders',
      title: 'Clean Sheet',
      description: 'Win a game with zero blunders.',
      icon: '✨',
      points: 40,
      category: AchievementCategory.strategy),

  // ── ENDGAME (7) ──
  const Achievement(
      id: 'checkmate_fast',
      title: 'Speed Demon',
      description: 'Checkmate in under 20 moves.',
      icon: '⚡',
      points: 50,
      category: AchievementCategory.endgame),
  const Achievement(
      id: 'scholars_mate',
      title: "Scholar's Mate",
      description: 'Win with a checkmate in 4 moves or less.',
      icon: '🎓',
      points: 75,
      category: AchievementCategory.endgame),
  const Achievement(
      id: 'back_rank_mate',
      title: 'Back Rank Assassin',
      description: 'Deliver a back rank checkmate.',
      icon: '🗡️',
      points: 30,
      category: AchievementCategory.endgame),
  const Achievement(
      id: 'queen_sacrifice',
      title: 'Queen Sacrifice',
      description: 'Sacrifice your queen and still win.',
      icon: '💀',
      points: 75,
      category: AchievementCategory.endgame),
  const Achievement(
      id: 'comeback_win',
      title: 'Comeback King',
      description: 'Win after being down in material by 5+ points.',
      icon: '🦅',
      points: 60,
      category: AchievementCategory.endgame),
  const Achievement(
      id: 'stalemate_save',
      title: 'Escape Artist',
      description: 'Force a stalemate when losing.',
      icon: '🏃',
      points: 40,
      category: AchievementCategory.endgame),
  const Achievement(
      id: 'long_game',
      title: 'Marathon Runner',
      description: 'Play a game lasting 100+ moves.',
      icon: '🏃‍♂️',
      points: 25,
      category: AchievementCategory.endgame),

  // ── SPEED (5) ──
  const Achievement(
      id: 'bullet_win',
      title: 'Bullet Proof',
      description: 'Win a game with 1 minute time control.',
      icon: '🔫',
      points: 40,
      category: AchievementCategory.speed),
  const Achievement(
      id: 'blitz_win',
      title: 'Lightning Bolt',
      description: 'Win a blitz game (3-5 min).',
      icon: '⚡',
      points: 25,
      category: AchievementCategory.speed),
  const Achievement(
      id: 'rapid_win',
      title: 'Rapid Fire',
      description: 'Win a rapid game (10+ min).',
      icon: '🏹',
      points: 20,
      category: AchievementCategory.speed),
  const Achievement(
      id: 'win_on_time',
      title: 'Clock Master',
      description: 'Win a game on time (opponent runs out).',
      icon: '⏱️',
      points: 20,
      category: AchievementCategory.speed),
  const Achievement(
      id: 'survive_low_time',
      title: 'Clutch Player',
      description: 'Win with less than 10 seconds remaining.',
      icon: '😰',
      points: 50,
      category: AchievementCategory.speed),

  // ── SOCIAL (5) ──
  const Achievement(
      id: 'mp_first_win',
      title: 'World Beater',
      description: 'Win your first online multiplayer game.',
      icon: '🌍',
      points: 30,
      category: AchievementCategory.social),
  const Achievement(
      id: 'mp_win_10',
      title: 'Online Champion',
      description: 'Win 10 online multiplayer games.',
      icon: '🏅',
      points: 75,
      category: AchievementCategory.social,
      requiredCount: 10),
  const Achievement(
      id: 'mp_win_50',
      title: 'Internet Legend',
      description: 'Win 50 online multiplayer games.',
      icon: '🌟',
      points: 200,
      category: AchievementCategory.social,
      requiredCount: 50),
  const Achievement(
      id: 'donate_xp',
      title: 'Generous Soul',
      description: 'Donate XP to another player.',
      icon: '🎁',
      points: 15,
      category: AchievementCategory.social),
  const Achievement(
      id: 'chat_game',
      title: 'Social Butterfly',
      description: 'Send a chat message during an online game.',
      icon: '💬',
      points: 5,
      category: AchievementCategory.social),

  // ── MASTERY (5) ──
  const Achievement(
      id: 'elo_1200',
      title: 'Rising Star',
      description: 'Reach an ELO rating of 1200.',
      icon: '⭐',
      points: 50,
      category: AchievementCategory.mastery),
  const Achievement(
      id: 'elo_1500',
      title: 'Expert',
      description: 'Reach an ELO rating of 1500.',
      icon: '🌟',
      points: 100,
      category: AchievementCategory.mastery),
  const Achievement(
      id: 'elo_1800',
      title: 'Master',
      description: 'Reach an ELO rating of 1800.',
      icon: '🏆',
      points: 200,
      category: AchievementCategory.mastery),
  const Achievement(
      id: 'elo_2000',
      title: 'Grandmaster',
      description: 'Reach an ELO rating of 2000.',
      icon: '🎖️',
      points: 500,
      category: AchievementCategory.mastery),
  const Achievement(
      id: 'elo_2200',
      title: 'Super GM',
      description: 'Reach an ELO rating of 2200.',
      icon: '👑',
      points: 1000,
      category: AchievementCategory.mastery),

  // ── COLLECTION & SPECIAL (5) ──
  const Achievement(
      id: 'puzzle_10',
      title: 'Puzzle Addict',
      description: 'Solve 10 puzzles.',
      icon: '🧩',
      points: 25,
      category: AchievementCategory.collection,
      requiredCount: 10),
  const Achievement(
      id: 'puzzle_50',
      title: 'Puzzle Master',
      description: 'Solve 50 puzzles.',
      icon: '🧠',
      points: 75,
      category: AchievementCategory.collection,
      requiredCount: 50),
  const Achievement(
      id: 'puzzle_rush_survive',
      title: 'Rush Survivor',
      description: 'Survive a full Puzzle Rush session.',
      icon: '🏃',
      points: 30,
      category: AchievementCategory.special),
  const Achievement(
      id: 'play_100_games',
      title: 'Century Club',
      description: 'Play 100 games in any mode.',
      icon: '🎉',
      points: 100,
      category: AchievementCategory.collection,
      requiredCount: 100),
  const Achievement(
      id: 'daily_player',
      title: 'Dedicated',
      description: 'Play at least one game for 7 days in a row.',
      icon: '📅',
      points: 50,
      category: AchievementCategory.special,
      requiredCount: 7),

  // ═════════════════════════════════════════
  // 25 NEW MULTIPLAYER & ONLINE BADGES
  // ═════════════════════════════════════════

  // ── MULTIPLAYER EXCELLENCE (8) ──
  const Achievement(
      id: 'mp_matchmaker',
      title: 'Matchmaker',
      description: 'Win 5 online multiplayer games.',
      icon: '🎲',
      points: 30,
      category: AchievementCategory.social,
      requiredCount: 5),
  const Achievement(
      id: 'mp_ladder_climber',
      title: 'Ladder Climber',
      description: 'Reach 1500+ rating in multiplayer.',
      icon: '📈',
      points: 50,
      category: AchievementCategory.mastery),
  const Achievement(
      id: 'mp_unstoppable_online',
      title: 'Unstoppable Online',
      description: 'Win 10 games in a row in multiplayer.',
      icon: '🔥',
      points: 100,
      category: AchievementCategory.combat,
      requiredCount: 10),
  const Achievement(
      id: 'mp_blitz_king',
      title: 'Blitz King',
      description: 'Reach 1600+ rating in blitz time control.',
      icon: '👑',
      points: 75,
      category: AchievementCategory.speed),
  const Achievement(
      id: 'mp_rapid_master',
      title: 'Rapid Master',
      description: 'Reach 1700+ rating in rapid time control.',
      icon: '⚜️',
      points: 75,
      category: AchievementCategory.mastery),
  const Achievement(
      id: 'mp_classical_scholar',
      title: 'Classical Scholar',
      description: 'Play and complete 5 classical games (30+ min).',
      icon: '📖',
      points: 60,
      category: AchievementCategory.mastery,
      requiredCount: 5),
  const Achievement(
      id: 'mp_tournament_victor',
      title: 'Tournament Victor',
      description: 'Win any online tournament.',
      icon: '🏅',
      points: 100,
      category: AchievementCategory.social),
  const Achievement(
      id: 'mp_comeback_king',
      title: 'Comeback King',
      description: 'Win after being down 2+ points of material.',
      icon: '💪',
      points: 50,
      category: AchievementCategory.combat),

  // ── TIME CONTROL MASTERY (6) ──
  const Achievement(
      id: 'tc_bullet_fiend',
      title: 'Bullet Fiend',
      description: 'Win 20 bullet games.',
      icon: '⚡',
      points: 40,
      category: AchievementCategory.speed,
      requiredCount: 20),
  const Achievement(
      id: 'tc_blitz_warrior',
      title: 'Blitz Warrior',
      description: 'Win 30 blitz games.',
      icon: '⚔️',
      points: 50,
      category: AchievementCategory.combat,
      requiredCount: 30),
  const Achievement(
      id: 'tc_rapid_aficionado',
      title: 'Rapid Aficionado',
      description: 'Win 20 rapid games.',
      icon: '🎯',
      points: 50,
      category: AchievementCategory.mastery,
      requiredCount: 20),
  const Achievement(
      id: 'tc_rapid_specialist',
      title: 'Rapid Specialist',
      description: 'Win 50 rapid games.',
      icon: '🎖️',
      points: 100,
      category: AchievementCategory.mastery,
      requiredCount: 50),
  const Achievement(
      id: 'tc_time_management',
      title: 'Time Management',
      description: 'Win without using more than 60% of your time.',
      icon: '⏱️',
      points: 40,
      category: AchievementCategory.strategy),
  const Achievement(
      id: 'tc_depth_over_speed',
      title: 'Depth Over Speed',
      description: 'Win a game with 50+ moves.',
      icon: '♖',
      points: 45,
      category: AchievementCategory.endgame),

  // ── CLUTCH PERFORMANCES (6) ──
  const Achievement(
      id: 'cp_fortress_defender',
      title: 'Fortress Defender',
      description: 'Win despite opponent having 2+ point advantage.',
      icon: '🛡️',
      points: 60,
      category: AchievementCategory.strategy),
  const Achievement(
      id: 'cp_escape_artist',
      title: 'Escape Artist',
      description: 'Force a draw when facing certain defeat.',
      icon: '🆘',
      points: 50,
      category: AchievementCategory.strategy),
  const Achievement(
      id: 'cp_finisher',
      title: 'Finisher',
      description: 'Win 5 games with checkmate (not on time).',
      icon: '🎪',
      points: 55,
      category: AchievementCategory.combat,
      requiredCount: 5),
  const Achievement(
      id: 'cp_precision_pressure',
      title: 'Precision Under Pressure',
      description: 'Maintain 80%+ accuracy while in time trouble.',
      icon: '💎',
      points: 70,
      category: AchievementCategory.strategy),
  const Achievement(
      id: 'cp_sacrifice_master',
      title: 'Sacrifice Master',
      description: 'Win a game after intentional material sacrifice.',
      icon: '💣',
      points: 65,
      category: AchievementCategory.combat),
  const Achievement(
      id: 'cp_promotion_victory',
      title: 'Promotion Victory',
      description: 'Win by promoting a pawn in multiplayer game.',
      icon: '👸',
      points: 55,
      category: AchievementCategory.strategy),

  // ── SOCIAL DOMINANCE (5) ──
  const Achievement(
      id: 'sd_rising_star',
      title: 'Rising Star',
      description: 'Win 3 games against rated higher players.',
      icon: '⭐',
      points: 50,
      category: AchievementCategory.social,
      requiredCount: 3),
  const Achievement(
      id: 'sd_humble_victor',
      title: 'Humble Victor',
      description: 'Beat 5 different opponents.',
      icon: '🤝',
      points: 40,
      category: AchievementCategory.social,
      requiredCount: 5),
  const Achievement(
      id: 'sd_revenge_master',
      title: 'Revenge Master',
      description: 'Beat same opponent twice in a row.',
      icon: '🎯',
      points: 35,
      category: AchievementCategory.combat),
  const Achievement(
      id: 'sd_tournament_dominator',
      title: 'Tournament Dominator',
      description: 'Win tournament with 100% score (no draws).',
      icon: '🏆',
      points: 150,
      category: AchievementCategory.social),
  const Achievement(
      id: 'sd_legendary_status',
      title: 'Legendary Status',
      description: 'Accumulate 500+ achievement points.',
      icon: '🌟',
      points: 200,
      category: AchievementCategory.special),
  // ── NEW ENGAGING BADGES (5) ──
  const Achievement(
      id: 'daily_warrior',
      title: 'Daily Warrior',
      description: 'Play 5 multiplayer games in a single day.',
      icon: '🗓️',
      points: 50,
      category: AchievementCategory.social,
      requiredCount: 5),
  const Achievement(
      id: 'gg_champion',
      title: 'GG Champion',
      description: 'Send "Good Game" or a friendly chat 10 times.',
      icon: '🤝',
      points: 30,
      category: AchievementCategory.social,
      requiredCount: 10),
  const Achievement(
      id: 'bounty_hunter',
      title: 'Bounty Hunter',
      description: 'Capture the opponent\'s Queen in 5 different multiplayer games.',
      icon: '🎯',
      points: 60,
      category: AchievementCategory.combat,
      requiredCount: 5),
  const Achievement(
      id: 'speed_demon_mp',
      title: 'Speed Demon',
      description: 'Win a Bullet game in under 2 minutes.',
      icon: '⚡',
      points: 45,
      category: AchievementCategory.speed),
  const Achievement(
      id: 'tournament_star',
      title: 'Tournament Star',
      description: 'Participate in your first online tournament.',
      icon: '✨',
      points: 25,
      category: AchievementCategory.special),
];

// Helper to get achievements by category
List<Achievement> getAchievementsByCategory(AchievementCategory category) {
  return allAchievements.where((a) => a.category == category).toList();
}

// Category display info
String categoryName(AchievementCategory cat) => switch (cat) {
      AchievementCategory.beginner => '🌱 Beginner',
      AchievementCategory.combat => '⚔️ Combat',
      AchievementCategory.strategy => '♟️ Strategy',
      AchievementCategory.endgame => '🏁 Endgame',
      AchievementCategory.speed => '⏱️ Speed',
      AchievementCategory.social => '🌍 Social',
      AchievementCategory.mastery => '🎖️ Mastery',
      AchievementCategory.collection => '📦 Collection',
      AchievementCategory.special => '✨ Special',
    };
