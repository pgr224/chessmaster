import 'dart:math' as math;

enum AIPersonality {
  aggressive, // Focuses on checks and captures
  defensive, // Avoids threats, prioritizes king safety
  tricky, // Plays slightly suboptimal moves to set traps
  lazy, // Makes occasional random moves
  random, // Purely random (used as fallback or for extreme blunders)
  coach // Balanced, gives advice on moves
}

extension AIPersonalityInfo on AIPersonality {
  String getRandomMessage(String? lastMessage) {
    final messages = switch (this) {
      AIPersonality.aggressive => [
          "I'm coming for your King! 😈🔥",
          "Rawr! Watch out for my attack! 🦁⚔️",
          "Prepare for some fireworks! 🎆💥",
          "I see a weakness! En garde! 🤺🛡️",
          "No mercy for that King! 😤🔥",
        ],
      AIPersonality.defensive => [
          "My defense is unbreakable! 🏰🛡️",
          "Safe and sound in my castle! 🏠🔑",
          "You shall not pass! 🧙‍♂️🛡️",
          "Solid as a rock! 💎🧱",
          "Priority one: Keep the King safe! 👑🛡️",
        ],
      AIPersonality.tricky => [
          "Hehe, can you spot my trap? 🃏✨",
          "Now you see it, now you don't! 🎩🐇",
          "I have a secret plan... 🤫✨",
          "A sneaky move for a sneaky AI!  foxes🎈",
          "Oops! Did you fall for that? 🍬🕸️",
        ],
      AIPersonality.lazy => [
          "Ho hum, just an ordinary move... 🥱☕",
          "Is it nap time yet? 😴☁️",
          "Maybe I'll just move this one... 🐢♟️",
          "Too much thinking for today... 💤☕",
          "Let's just keep it simple. 🥱🥛",
        ],
      AIPersonality.random => [
          "Wait, what's a chess? 🤪🌀",
          "Boop! Moving a piece! 🤖🍭",
          "Does this piece go here? 🧩❓",
          "Wobble wobble! 🍮🌀",
          "I like the shiny ones! ✨💎",
        ],
      AIPersonality.coach => [
          "Let's look at that move... 🎓",
          "A steady hand wins the race! 🐎",
          "Interesting choice, but consider the center! 🏗️",
          "You're improving with every turn! 📈",
          "Let's find the best path together. 🗺️",
        ],
    };

    final filtered = messages.where((m) => m != lastMessage).toList();
    if (filtered.isEmpty) return "Let's have some coffee break! ☕🍪";
    
    // Choose one randomly
    final next = filtered[math.Random().nextInt(filtered.length)];
    return next;
  }

  String get label => name[0].toUpperCase() + name.substring(1);

  double get timeMultiplier => switch (this) {
        AIPersonality.aggressive => 0.7,
        AIPersonality.defensive => 1.0,
        AIPersonality.tricky => 0.85,
        AIPersonality.lazy => 0.6,
        AIPersonality.random => 0.5,
        AIPersonality.coach => 0.9,
      };
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

  String? _lastMessage;
  String get lastMessage => _lastMessage ?? '';

  String generateNewMessage() {
    final msg = _currentPersonality.getRandomMessage(_lastMessage);
    _lastMessage = msg;
    return msg;
  }

  void forcePersonality(AIPersonality p) {
    _currentPersonality = p;
  }
}
