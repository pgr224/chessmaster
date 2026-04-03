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
          "A sneaky move for a sneaky AI! 🦊🎈",
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

  /// Get a personality-flavored reaction to the player's move quality
  String getMoveReaction(String classification) {
    final reactions = switch (this) {
      AIPersonality.aggressive => {
          'brilliant': [
            "Impossible! That was genius! 🤯🔥",
            "HOW?! A masterful strike! ⚡💀",
            "...Fine. You earned that one. 👑⚔️"
          ],
          'best': [
            "Good move... but I'll find a way! 😤",
            "Not bad, warrior! En garde! 🤺",
            "Hmph! You're smarter than I thought! 💪"
          ],
          'good': [
            "Decent. But I'm still attacking! ⚔️",
            "Okay, but watch THIS! 😈",
            "A safe move. Boring! 🔥"
          ],
          'mistake': [
            "HA! I see your weakness! 😈💥",
            "Bad move! I'll punish that! ⚡",
            "You left the door open! 🚪😤"
          ],
          'blunder': [
            "GOTCHA! That was a blunder! 🎯💀",
            "Oh no! Your King is trembling! 👑💔",
            "Time to go in for the kill! 🦁🔥"
          ],
        },
      AIPersonality.defensive => {
          'brilliant': [
            "Amazing move! My walls are shaking! 🏰😰",
            "That was inspired! I need to regroup! 🛡️✨",
            "Wow... even my fortress feels that! 💎"
          ],
          'best': [
            "Good strategy! But my defense holds! 🛡️",
            "Solid play! I'll reinforce my position! 🏰",
            "Nicely done! Let me shore up! 🧱"
          ],
          'good': [
            "Okay move! My castle stands firm! 🏠",
            "That won't break through easily! 🛡️",
            "I'm safe for now! 🔑"
          ],
          'mistake': [
            "Hmm, that left a gap... 🔍",
            "I see a crack in your formation! 🧐",
            "Your defense has a hole there! 🕳️"
          ],
          'blunder': [
            "Oh dear! That piece is in trouble! 😰",
            "You might want to watch that area! 🛡️⚠️",
            "That... wasn't your best moment! 😬"
          ],
        },
      AIPersonality.tricky => {
          'brilliant': [
            "Whoa! You saw through my tricks! 🎩😮",
            "Incredible! Can't fool YOU! 🃏✨",
            "A magician recognizes magic! 🌟🎪"
          ],
          'best': [
            "Ooh, sneaky! I like your style! 🤫",
            "Nice one! But I have more tricks! 🎩",
            "Good eye! But wait for my next trap! 🕸️"
          ],
          'good': [
            "Interesting... let me adjust my plans! 🃏",
            "Okay, but can you handle THIS? 🎪",
            "A fair move! My trick bag is deep! 🎒"
          ],
          'mistake': [
            "Hehe! Did you miss something? 🤭",
            "Oooh, I was hoping you'd do that! 🍬",
            "My trap is set... and you walked in! 🕷️"
          ],
          'blunder': [
            "SURPRISE! You fell for it! 🎉🕸️",
            "Abracadabra! That piece vanishes! 🎩💨",
            "The trick worked! Ta-da! ✨🃏"
          ],
        },
      AIPersonality.lazy => {
          'brilliant': [
            "*Yawns*... okay that was actually impressive! 😴✨",
            "Whoa, didn't see THAT coming! 🥱🤩",
            "Fine, I'll wake up for that one! ☕💫"
          ],
          'best': [
            "Not bad... *stretches* 🐱",
            "Okay, that was decent. Zzz... 😴",
            "Mmm, good move I guess! 🥱"
          ],
          'good': [
            "Meh, it's alright! 🐢",
            "Sure, that works! *yawns* 😴",
            "Average. Like my motivation! 🥱"
          ],
          'mistake': [
            "Even I could see that was wrong! 😴😬",
            "Oopsie! That was a bit off! 🐢💤",
            "Maybe think a bit more? *yawns* 🥱"
          ],
          'blunder': [
            "LOL even I wouldn't do that! 😂💤",
            "Oh no! Even on a lazy day that's bad! 🙈",
            "That piece is basically napping forever now! 😴💀"
          ],
        },
      AIPersonality.random => {
          'brilliant': [
            "SHINY move!! So pretty!! ✨🤩🌈",
            "Ooooh sparkles!! The best move!! 🎆",
            "WOWOWOWOW! AMAZING!! 🤪💫"
          ],
          'best': [
            "Ooh nice boop! 🤖✨",
            "That piece looks happy there! 🍭",
            "Beep boop! Good one! 🎈"
          ],
          'good': [
            "Okay-dokey! 🌀",
            "Wheee, chess is fun! 🎪",
            "Boop! That works! 🤖"
          ],
          'mistake': [
            "Uh oh spaghettio! 🍝😬",
            "That piece looks confused! 🧩❓",
            "Hmm... that was wobbly! 🌀"
          ],
          'blunder': [
            "OOPSIE DAISY! 🌼💥",
            "That piece went SPLAT! 🤪💀",
            "Noooo! The shiny one fell! 💎😭"
          ],
        },
      AIPersonality.coach => {
          'brilliant': [
            "OUTSTANDING! That's a grandmaster-level move! 🏆🎓",
            "Brilliant analysis! You found the key idea! 🔑✨",
            "That's exactly what the engine suggests! Perfect! 💯"
          ],
          'best': [
            "Excellent choice! That's the top move! 📈🎯",
            "Great thinking! You're reading the board well! 🎓",
            "That's a strong continuation! Well played! 👏"
          ],
          'good': [
            "Solid move! You're making progress! 📊",
            "A reasonable choice! Let's see how it unfolds! 🗺️",
            "Good thinking! Keep it up! 🐎"
          ],
          'mistake': [
            "Hmm, there might have been a better option... 🤔",
            "Consider looking at the whole board next time! 🔍",
            "That move loses some advantage. Check tactics! 📋"
          ],
          'blunder': [
            "Careful! That's a significant mistake! ⚠️📉",
            "Oops! That gives away material — look for checks and captures first! 🎓",
            "Let's learn from this — always check for threats! 🔍💡"
          ],
        },
    };

    final pool = reactions[classification] ?? reactions['good']!;
    return pool[math.Random().nextInt(pool.length)];
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
