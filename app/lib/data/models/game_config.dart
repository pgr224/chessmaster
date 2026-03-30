import 'package:flutter/material.dart';

import '../models/puzzle_model.dart';

enum GameMode {
  tutorial,
  singlePlayer,
  twoPlayer,
  multiplayer,
  tournament,
  puzzle,
  practice
}

enum AIDifficulty { basic, intermediate, advanced, impossible, aiMode }

class GameConfig {
  final GameMode mode;
  final Puzzle? puzzle;
  final AIDifficulty? difficulty;
  final String? playerColor;
  final String? boardTheme;
  final String? pieceShape;
  final String? pieceStyle;
  final Color? whitePieceColor;
  final Color? blackPieceColor;
  final bool hintsEnabled;
  final int? timeControl; // total seconds per player (e.g. 600 for 10min)
  final int incrementSeconds; // seconds added per move (e.g. 5 for 10+5)
  final String? activeGameId;
  final bool isPuzzleRush;

  const GameConfig({
    required this.mode,
    this.puzzle,
    this.difficulty,
    this.playerColor,
    this.boardTheme,
    this.pieceShape,
    this.pieceStyle,
    this.whitePieceColor,
    this.blackPieceColor,
    this.hintsEnabled = false,
    this.timeControl,
    this.incrementSeconds = 0,
    this.activeGameId,
    this.isPuzzleRush = false,
  });

  /// Parse a time control string like "10+5" into (baseSeconds, incrementSeconds)
  static (int, int) parseTimeControl(String tc) {
    final parts = tc.split('+');
    final baseMinutes = int.tryParse(parts[0].trim()) ?? 10;
    final increment =
        parts.length > 1 ? (int.tryParse(parts[1].trim()) ?? 0) : 0;
    return (baseMinutes * 60, increment);
  }
}
