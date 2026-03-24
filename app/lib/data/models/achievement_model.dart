import 'package:equatable/equatable.dart';

class Achievement extends Equatable {
  final String id;
  final String title;
  final String description;
  final String icon;
  final int points;
  final bool isUnlocked;
  final DateTime? unlockedAt;

  const Achievement({
    required this.id,
    required this.title,
    required this.description,
    required this.icon,
    required this.points,
    this.isUnlocked = false,
    this.unlockedAt,
  });

  @override
  List<Object?> get props => [id, isUnlocked];
}

final List<Achievement> sampleAchievements = [
  const Achievement(
    id: 'first_win',
    title: 'First Blood',
    description: 'Win your first game against an AI or player.',
    icon: '🏆',
    points: 10,
    isUnlocked: true,
  ),
  const Achievement(
    id: 'pawn_star',
    title: 'Pawn Star',
    description: 'Promote a pawn to a Queen.',
    icon: '👸',
    points: 20,
  ),
  const Achievement(
    id: 'checkmate_fast',
    title: 'Speed Demon',
    description: 'Checkmate in less than 20 moves.',
    icon: '⚡',
    points: 50,
  ),
  const Achievement(
    id: 'grandmaster',
    title: 'Grandmaster',
    description: 'Reach a rating of 2000.',
    icon: '🎖️',
    points: 100,
  ),
];
