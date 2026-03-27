import 'package:flutter/material.dart';

import '../models/puzzle_model.dart';

enum GameMode { tutorial, singlePlayer, twoPlayer, multiplayer, puzzle }
enum AIDifficulty { basic, intermediate, advanced, impossible }

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
  final int? timeControl;
  final String? activeGameId;

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
    this.activeGameId,
  });
}
