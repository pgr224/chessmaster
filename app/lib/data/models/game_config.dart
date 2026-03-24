enum GameMode { tutorial, singlePlayer, twoPlayer, multiplayer, tournament }
enum AIDifficulty { basic, intermediate, advanced, impossible }

class GameConfig {
  final GameMode mode;
  final AIDifficulty? difficulty;
  final String? playerColor;
  final String? boardTheme;
  final bool hintsEnabled;
  final int? timeControl;

  const GameConfig({
    required this.mode,
    this.difficulty,
    this.playerColor,
    this.boardTheme,
    this.hintsEnabled = false,
    this.timeControl,
  });
}
