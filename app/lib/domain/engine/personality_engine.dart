import 'dart:math' as math;

enum AIPersonality {
  aggressive, // Focuses on checks and captures
  defensive,  // Avoids threats, prioritizes king safety
  tricky,     // Plays slightly suboptimal moves to set traps
  lazy,       // Makes occasional random moves
  random      // Purely random (used as fallback or for extreme blunders)
}

extension AIPersonalityInfo on AIPersonality {
  String get message => switch (this) {
    AIPersonality.aggressive => "I'm coming for your King! 😈🔥",
    AIPersonality.defensive => "My defense is unbreakable! 🏰🛡️",
    AIPersonality.tricky => "Hehe, can you spot my trap? 🃏✨",
    AIPersonality.lazy => "Ho hum, just an ordinary move... 🥱☕",
    AIPersonality.random => "Wait, what's a chess? 🤪🌀",
  };

  String get label => name[0].toUpperCase() + name.substring(1);
}

class PersonalityEngine {
  static final PersonalityEngine _instance = PersonalityEngine._internal();
  factory PersonalityEngine() => _instance;
  PersonalityEngine._internal();

  AIPersonality _currentPersonality = AIPersonality.aggressive;
  AIPersonality get currentPersonality => _currentPersonality;

  /// Adapt personality based on user's playstyle analysis
  /// analysisResult is a map from Leela or a simple heuristic:
  /// { 'pressure': double, 'solidity': double, 'entropy': double }
  void adapt(Map<String, double> analysis) {
    final pressure = analysis['pressure'] ?? 0.5; // 0.0 to 1.0
    final solidity = analysis['solidity'] ?? 0.5;

    if (pressure > 0.8) {
      // User is extremely aggressive -> AI becomes Defensive
      _currentPersonality = AIPersonality.defensive;
    } else if (solidity > 0.8) {
      // User is very solid -> AI becomes Aggressive to break them
      _currentPersonality = AIPersonality.aggressive;
    } else if (pressure < 0.3 && solidity < 0.3) {
      // User is "lazy" or weak -> AI becomes Tricky to teach them
      _currentPersonality = AIPersonality.tricky;
    } else {
      // Balanced -> mix it up
      final rand = math.Random().nextDouble();
      if (rand > 0.7) {
        _currentPersonality = AIPersonality.aggressive;
      } else if (rand > 0.4) {
        _currentPersonality = AIPersonality.defensive;
      } else {
        _currentPersonality = AIPersonality.tricky;
      }
    }
  }

  void forcePersonality(AIPersonality p) {
    _currentPersonality = p;
  }
}
