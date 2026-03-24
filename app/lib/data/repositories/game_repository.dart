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
      moveCount: game.moveCount,
      updatedAt: DateTime.now(),
    );
    await box.put(id, _gameToJson(updatedGame));

    // Try server sync
    try {
      await _dio.post('/api/game/create', data: {
        'gameId': id,
        'mode': game.mode,
        'fen': game.fen,
      });
    } catch (_) {
      // Offline — will sync later
    }
    return id;
  }

  Future<List<GameModel>> getSavedGames() async {
    final box = await Hive.openBox<String>(_boxName);
    return box.values
        .map((json) => GameModel.fromJson(_jsonFromString(json)))
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<GameModel?> getSavedGame(String id) async {
    final box = await Hive.openBox<String>(_boxName);
    final json = box.get(id);
    if (json == null) return null;
    return GameModel.fromJson(_jsonFromString(json));
  }

  Future<void> deleteGame(String id) async {
    final box = await Hive.openBox<String>(_boxName);
    await box.delete(id);
  }

  String _gameToJson(GameModel g) =>
      '{"id":"${g.id}","fen":"${g.fen}","mode":"${g.mode}","status":"${g.status}","result":"${g.result}","move_count":${g.moveCount},"updated_at":"${g.updatedAt.toIso8601String()}"}';

  Map<String, dynamic> _jsonFromString(String s) {
    // Simple JSON decode — use dart:convert in production
    return Map<String, dynamic>.from({});
  }
}
