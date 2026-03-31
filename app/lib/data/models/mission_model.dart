import 'package:equatable/equatable.dart';

enum MissionType { daily, weekly }

class Mission extends Equatable {
  final String id;
  final String title;
  final String description;
  final int rewardXP;
  final int targetCount;
  final int currentCount;
  final MissionType type;
  final bool isClaimed;

  const Mission({
    required this.id,
    required this.title,
    required this.description,
    required this.rewardXP,
    required this.targetCount,
    this.currentCount = 0,
    this.type = MissionType.daily,
    this.isClaimed = false,
  });

  bool get isCompleted => currentCount >= targetCount;
  double get progress => (currentCount / targetCount).clamp(0.0, 1.0);

  Mission copyWith({
    int? currentCount,
    bool? isClaimed,
  }) {
    return Mission(
      id: id,
      title: title,
      description: description,
      rewardXP: rewardXP,
      targetCount: targetCount,
      currentCount: currentCount ?? this.currentCount,
      type: type,
      isClaimed: isClaimed ?? this.isClaimed,
    );
  }

  factory Mission.fromJson(Map<String, dynamic> json) {
    return Mission(
      id: json['id'] as String,
      title: json['title'] as String,
      description: json['description'] as String,
      rewardXP: json['reward_xp'] as int,
      targetCount: json['target_count'] as int,
      currentCount: json['current_count'] as int? ?? 0,
      type: json['type'] == 'weekly' ? MissionType.weekly : MissionType.daily,
      isClaimed: json['is_claimed'] as bool? ?? false,
    );
  }

  Map<String, dynamic> toJson() => {
        'id': id,
        'title': title,
        'description': description,
        'reward_xp': rewardXP,
        'target_count': targetCount,
        'current_count': currentCount,
        'type': type == MissionType.weekly ? 'weekly' : 'daily',
        'is_claimed': isClaimed,
      };

  @override
  List<Object?> get props => [id, currentCount, isClaimed];
}
