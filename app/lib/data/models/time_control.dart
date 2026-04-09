import 'package:flutter/material.dart';

enum TimeControlCategory { bullet, blitz, rapid, classical, unknown }

class TimeControlPreset {
  final String value;
  final String label;
  final String description;
  final TimeControlCategory category;
  final IconData icon;
  final Color color;

  const TimeControlPreset({
    required this.value,
    required this.label,
    required this.description,
    required this.category,
    required this.icon,
    required this.color,
  });

  static const defaultValue = '10+0';

  static const List<TimeControlPreset> all = [
    TimeControlPreset(
      value: '1/4+0',
      label: 'Ultra-Bullet',
      description: 'The fastest chess possible! 15 seconds per side.',
      category: TimeControlCategory.bullet,
      icon: Icons.electric_bolt_rounded,
      color: Colors.deepPurpleAccent,
    ),
    TimeControlPreset(
      value: '1/2+0',
      label: 'Hyper-Bullet',
      description: 'Blink and you miss it! 30 seconds per side.',
      category: TimeControlCategory.bullet,
      icon: Icons.speed_rounded,
      color: Colors.pinkAccent,
    ),
    TimeControlPreset(
      value: '1+0',
      label: 'Bullet',
      description: 'Ultra-fast games with 1 minute per side.',
      category: TimeControlCategory.bullet,
      icon: Icons.flash_on_rounded,
      color: Colors.red,
    ),
    TimeControlPreset(
      value: '2+1',
      label: 'Bullet',
      description: 'Quick games with a small increment.',
      category: TimeControlCategory.bullet,
      icon: Icons.bolt_rounded,
      color: Colors.redAccent,
    ),
    TimeControlPreset(
      value: '3+0',
      label: 'Blitz',
      description: 'Classic 3-minute blitz.',
      category: TimeControlCategory.blitz,
      icon: Icons.local_fire_department_rounded,
      color: Colors.orange,
    ),
    TimeControlPreset(
      value: '3+2',
      label: 'Blitz',
      description: 'Blitz with a small increment.',
      category: TimeControlCategory.blitz,
      icon: Icons.timer_rounded,
      color: Colors.deepOrange,
    ),
    TimeControlPreset(
      value: '5+0',
      label: 'Blitz',
      description: 'Fast 5-minute blitz games.',
      category: TimeControlCategory.blitz,
      icon: Icons.bolt_rounded,
      color: Colors.amber,
    ),
    TimeControlPreset(
      value: '5+3',
      label: 'Blitz',
      description: 'Tactical blitz with increment.',
      category: TimeControlCategory.blitz,
      icon: Icons.bolt_rounded,
      color: Colors.amberAccent,
    ),
    TimeControlPreset(
      value: '10+0',
      label: 'Rapid',
      description: 'Balanced rapid games with good tempo.',
      category: TimeControlCategory.rapid,
      icon: Icons.hourglass_top_rounded,
      color: Colors.lightBlue,
    ),
    TimeControlPreset(
      value: '10+5',
      label: 'Rapid',
      description: 'Popular rapid time control with increment.',
      category: TimeControlCategory.rapid,
      icon: Icons.hourglass_bottom_rounded,
      color: Colors.cyan,
    ),
    TimeControlPreset(
      value: '10+10',
      label: 'Rapid',
      description: 'Generous rapid time control with increment.',
      category: TimeControlCategory.rapid,
      icon: Icons.hourglass_empty_rounded,
      color: Colors.lightBlueAccent,
    ),
    TimeControlPreset(
      value: '15+10',
      label: 'Rapid',
      description: 'Deep rapid game with a comfortable increment.',
      category: TimeControlCategory.rapid,
      icon: Icons.timer_rounded,
      color: Colors.blueAccent,
    ),
    TimeControlPreset(
      value: '15+0',
      label: 'Rapid',
      description: 'Longer rapid game without increment.',
      category: TimeControlCategory.rapid,
      icon: Icons.timelapse_rounded,
      color: Colors.blue,
    ),
    TimeControlPreset(
      value: '30+0',
      label: 'Classical',
      description: 'Classic 30-minute games for thoughtful play.',
      category: TimeControlCategory.classical,
      icon: Icons.account_balance_rounded,
      color: Colors.green,
    ),
    TimeControlPreset(
      value: '30+20',
      label: 'Classical',
      description: 'Long classical games with significant increment.',
      category: TimeControlCategory.classical,
      icon: Icons.history_edu_rounded,
      color: Colors.teal,
    ),
    TimeControlPreset(
      value: '90+30',
      label: 'Tournament',
      description: 'FIDE-style tournament time control.',
      category: TimeControlCategory.classical,
      icon: Icons.emoji_events_rounded,
      color: Colors.indigo,
    ),
  ];

  static TimeControlPreset get defaultPreset => fromValue(defaultValue);

  static TimeControlPreset fromValue(String value) {
    final normalized = normalize(value);
    return all.firstWhere(
      (preset) => preset.value == normalized,
      orElse: () => all.first,
    );
  }

  static bool isValid(String value) {
    return all.any((preset) => preset.value == normalize(value));
  }

  static String normalize(String rawValue) {
    final source = rawValue.trim();
    if (source.contains('+')) {
      final parts = source.split('+').map((part) => part.trim()).toList();
      if (parts.length == 2) {
        final base = int.tryParse(parts[0]);
        final inc = int.tryParse(parts[1]);
        if (base != null && base > 0 && inc != null && inc >= 0) {
          final normalized = '$base+$inc';
          if (all.any((preset) => preset.value == normalized)) {
            return normalized;
          }
        }
      }
    }
    if (source.contains('_')) {
      final parts = source.split('_').map((part) => part.trim()).toList();
      if (parts.length >= 2) {
        final base = int.tryParse(parts[parts.length - 2]);
        final inc = int.tryParse(parts.last);
        if (base != null && base > 0 && inc != null && inc >= 0) {
          final normalized = '$base+$inc';
          if (all.any((preset) => preset.value == normalized)) {
            return normalized;
          }
        }
      }
    }
    return defaultValue;
  }

  static String friendlyCategory(String value) {
    final preset = fromValue(value);
    switch (preset.category) {
      case TimeControlCategory.bullet:
        return 'Bullet';
      case TimeControlCategory.blitz:
        return 'Blitz';
      case TimeControlCategory.rapid:
        return 'Rapid';
      case TimeControlCategory.classical:
        return 'Classical';
      default:
        return 'Standard';
    }
  }
}
