import 'package:flutter/material.dart';

class GameVariantPreset {
  final String id;
  final String name;
  final String subtitle;
  final String description;
  final IconData icon;
  final Color color;
  final double xpMultiplier;
  final bool ranked;

  const GameVariantPreset({
    required this.id,
    required this.name,
    required this.subtitle,
    required this.description,
    required this.icon,
    required this.color,
    required this.xpMultiplier,
    required this.ranked,
  });

  static const List<GameVariantPreset> all = [
    GameVariantPreset(
      id: 'standard',
      name: 'Standard',
      subtitle: 'Classic FIDE Rules',
      description: 'Balanced ranked play.',
      icon: Icons.shield_rounded,
      color: Color(0xFF6BCB77),
      xpMultiplier: 1.0,
      ranked: true,
    ),
    GameVariantPreset(
      id: 'kings_gambit',
      name: "King's Gambit",
      subtitle: 'Sacrifice Start',
      description: 'High-risk tactical openings.',
      icon: Icons.local_fire_department_rounded,
      color: Color(0xFFFFB347),
      xpMultiplier: 1.2,
      ranked: false,
    ),
    GameVariantPreset(
      id: 'blindfold_blitz',
      name: 'Blindfold Blitz',
      subtitle: 'Memory Challenge',
      description: 'Extreme board-vision mode.',
      icon: Icons.visibility_off_rounded,
      color: Color(0xFF74B9FF),
      xpMultiplier: 1.5,
      ranked: false,
    ),
    GameVariantPreset(
      id: 'chess_roulette',
      name: 'Chess Roulette',
      subtitle: 'Chaos Opening',
      description: 'Randomized starting pressure.',
      icon: Icons.casino_rounded,
      color: Color(0xFFFF8A5C),
      xpMultiplier: 1.1,
      ranked: false,
    ),
    GameVariantPreset(
      id: 'speed_tactics',
      name: 'Speed Tactics',
      subtitle: 'Puzzle Tempo',
      description: 'Tactical intensity spikes.',
      icon: Icons.bolt_rounded,
      color: Color(0xFFFFD93D),
      xpMultiplier: 1.3,
      ranked: false,
    ),
    GameVariantPreset(
      id: 'team_chess',
      name: 'Team Chess',
      subtitle: '2v2 Style',
      description: 'Cooperative mode profile.',
      icon: Icons.groups_rounded,
      color: Color(0xFF4ECDC4),
      xpMultiplier: 0.9,
      ranked: false,
    ),
    GameVariantPreset(
      id: 'atomic_chess',
      name: 'Atomic Chess',
      subtitle: 'Explosive Captures',
      description: 'Every capture is dangerous.',
      icon: Icons.whatshot_rounded,
      color: Color(0xFFFF6B6B),
      xpMultiplier: 1.3,
      ranked: false,
    ),
    GameVariantPreset(
      id: 'tempo_duel',
      name: 'Tempo Duel',
      subtitle: 'Speed Scoring',
      description: 'Fast and accurate wins.',
      icon: Icons.speed_rounded,
      color: Color(0xFF74B9FF),
      xpMultiplier: 1.0,
      ranked: false,
    ),
    GameVariantPreset(
      id: 'promotion_fever',
      name: 'Promotion Fever',
      subtitle: 'Pawn Race',
      description: 'Promotion-focused combat.',
      icon: Icons.star_rounded,
      color: Color(0xFFFFD93D),
      xpMultiplier: 1.25,
      ranked: false,
    ),
    GameVariantPreset(
      id: 'material_handicap',
      name: 'Material Handicap',
      subtitle: 'Skill Balance',
      description: 'Fair starts for mixed ratings.',
      icon: Icons.balance_rounded,
      color: Color(0xFF6BCB77),
      xpMultiplier: 1.0,
      ranked: false,
    ),
  ];

  static GameVariantPreset fromId(String? id) {
    if (id == null || id.isEmpty) return all.first;
    return all.firstWhere(
      (variant) => variant.id == id,
      orElse: () => all.first,
    );
  }
}
