import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/game_model.dart';

class GameRepository {
  final Dio _dio;
  static const _boxName = 'saved_games';

  GameRepository(this._dio);

  /// Save game locally and sync to server if online
  Future<String> saveGame(GameModel game) async {
    final box = await Hive.openBox<String>(_boxName);
    final id = game.id.isEmpty ? const Uuid().v4() : game.id;
    final updatedGame = GameModel(
      id: id,
      fen: game.fen,
      pgn: game.pgn,
      mode: game.mode,
      status: game.status,
      result: game.result,
      termination: game.termination,
      whiteUserId: game.whiteUserId,
      blackUserId: game.blackUserId,
      whiteUsername: game.whiteUsername,
      blackUsername: game.blackUsername,
      moveCount: game.moveCount,
      updatedAt: DateTime.now(),
    );
    await box.put(id, jsonEncode(updatedGame.toJson()));

    // Try server sync
    try {
      await _dio.post('/api/game/create', data: {
        'gameId': id,
        'mode': game.mode,
        'initialFen': game.fen,
      });
    } catch (_) {}

    return id;
  }

  /// Sync game completion with the server
  Future<void> completeGame(GameModel game) async {
    // 1. Update local DB
    final box = await Hive.openBox<String>(_boxName);
    await box.put(game.id, jsonEncode(game.toJson()));

    // 2. Push to server
    try {
      final res = game.result.toLowerCase();
      String winner = 'draw';
      if (res.contains('whit')) winner = 'white';
      if (res.contains('black')) winner = 'black';

      await _dio.post('/api/game/complete', data: {
        'gameId': game.id,
        'result': winner,
        'termination': game.status,
        'pgn': game.pgn,
      });
    } catch (_) {}
  }

  Future<List<GameModel>> getSavedGames() async {
    final box = await Hive.openBox<String>(_boxName);
    return box.values
        .map((json) => GameModel.fromJson(jsonDecode(json) as Map<String, dynamic>))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<GameModel?> getSavedGame(String id) async {
    final box = await Hive.openBox<String>(_boxName);
    final json = box.get(id);
    if (json == null) return null;
    return GameModel.fromJson(jsonDecode(json) as Map<String, dynamic>);
  }

  Future<void> deleteGame(String id) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.delete(id);
  }

  Future<List<GameModel>> getRecentGames(String userId, {int limit = 10}) async {
    try {
      final res = await _dio.get('/api/game/user/$userId', queryParameters: {'limit': limit});
      final rows = (res.data['games'] as List?) ?? const [];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(GameModel.fromJson)
          .toList(growable: false);
    } catch (_) {
      return const [];
    }
  }
}
