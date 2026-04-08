import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:hive_ce/hive.dart';
import 'package:uuid/uuid.dart';
import '../models/game_model.dart';

class GameRepository {
  final Dio _dio;
  static const _boxName = 'saved_games_v3';
  static Box? _box;

  GameRepository(this._dio);

  /// Opens the Hive box, clearing it if format is incompatible
  Future<Box> _getBox() async {
    if (_box != null && _box!.isOpen) return _box!;

    try {
      _box = await Hive.openBox(_boxName);
    } catch (e) {
      print('[GameRepository] Box interaction error, recovering: $e');
      try {
        await Hive.deleteBoxFromDisk(_boxName);
      } catch (_) {}
      _box = await Hive.openBox(_boxName);
    }
    return _box!;
  }

  /// Save game locally and sync to server if online
  Future<String> saveGame(GameModel game) async {
    final box = await _getBox();
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

    // Write to Hive first
    await box.put(id, jsonEncode(updatedGame.toJson()));

    // Try server sync asynchronously
    if (_shouldSyncMode(updatedGame.mode)) {
      _syncGameCreate(id, updatedGame);
    }

    return id;
  }

  Future<void> _syncGameCreate(String id, GameModel game) async {
    try {
      await _dio.post('/api/game/create', data: {
        'gameId': id,
        'mode': _normalizeModeForServer(game.mode),
        'initialFen': game.fen,
      });
    } catch (e) {
      print('[GameRepository] Server sync failed (create): $e');
    }
  }

  String _normalizeModeForServer(String mode) {
    final value = mode.trim().toLowerCase();
    switch (value) {
      case 'singleplayer':
      case 'single_player':
      case 'singleplayermode':
        return 'singlePlayer';
      case 'twoplayer':
      case 'two_player':
      case 'local':
        return 'twoPlayer';
      case 'multiplayer':
        return 'multiplayer';
      case 'tournament':
        return 'tournament';
      case 'tutorial':
        return 'tutorial';
      case 'puzzle':
        return 'puzzle';
      case 'practice':
        return 'practice';
      default:
        return 'singlePlayer';
    }
  }

  /// Sync game completion with the server
  Future<void> completeGame(GameModel game) async {
    final box = await _getBox();
    await box.put(game.id, jsonEncode(game.toJson()));

    // 2. Push to server asynchronously
    if (_shouldSyncMode(game.mode)) {
      _syncGameComplete(game);
    }
  }

  bool _shouldSyncMode(String mode) {
    final normalized = mode.toLowerCase();
    // Puzzle is local progression; no game row is guaranteed on backend.
    return normalized != 'puzzle';
  }

  Future<void> _syncGameComplete(GameModel game) async {
    final payload = {
      'gameId': game.id,
      'result': _mapResultToWinner(game.result),
      'termination': game.termination ?? game.status,
      'pgn': game.pgn,
    };

    try {
      await _dio.post('/api/game/complete', data: payload);
    } on DioException catch (e) {
      // If game does not exist on server (e.g. create sync failed/offline),
      // create it first and retry completion once.
      if (e.response?.statusCode == 404) {
        try {
          await _syncGameCreate(game.id, game);
          await _dio.post('/api/game/complete', data: payload);
          return;
        } catch (retryError) {
          print(
              '[GameRepository] Server sync failed (complete retry): $retryError');
        }
      }

      print('[GameRepository] Server sync failed (complete): $e');
    } catch (e) {
      print('[GameRepository] Server sync failed (complete): $e');
    }
  }

  String _mapResultToWinner(String rawResult) {
    final res = rawResult.toLowerCase();
    if (res.contains('white')) return 'white';
    if (res.contains('black')) return 'black';
    return 'draw';
  }

  Future<List<GameModel>> getSavedGames() async {
    final box = await _getBox();
    return box.values
        .map((val) => val?.toString() ?? '')
        .where((val) => val.isNotEmpty)
        .map((jsonStr) {
          try {
            final Map<String, dynamic> data = jsonDecode(jsonStr);
            return GameModel.fromJson(data);
          } catch (e) {
            print('Error decoding saved game: $e');
            return null;
          }
        })
        .whereType<GameModel>()
        .toList()
      ..sort((a, b) => b.updatedAt.compareTo(a.updatedAt));
  }

  Future<GameModel?> getSavedGame(String id) async {
    final box = await _getBox();
    final val = box.get(id);
    if (val == null) return null;
    final jsonStr = val.toString();
    if (jsonStr.isEmpty) return null;
    try {
      return GameModel.fromJson(jsonDecode(jsonStr));
    } catch (e) {
      print('Error decoding specific game $id: $e');
      return null;
    }
  }

  Future<void> deleteGame(String id) async {
    final box = await _getBox();
    await box.delete(id);
  }

  static const _lastActiveKey = 'last_active_game_id';

  Future<void> setLastActiveGameId(String? id) async {
    final box = await _getBox();
    if (id == null) {
      await box.delete(_lastActiveKey);
    } else {
      await box.put(_lastActiveKey, id);
    }
  }

  Future<String?> getLastActiveGameId() async {
    final box = await _getBox();
    return box.get(_lastActiveKey)?.toString();
  }

  Future<List<GameModel>> getRecentGames(String userId,
      {int limit = 10}) async {
    try {
      final res = await _dio
          .get('/api/game/user/$userId', queryParameters: {'limit': limit});
      if (res.data is! Map<String, dynamic>) return const [];

      final rows = (res.data['games'] as List?) ?? const [];
      return rows
          .whereType<Map<String, dynamic>>()
          .map(GameModel.fromJson)
          .toList(growable: false);
    } catch (e) {
      print('Recent games fetch error: $e');
      return const [];
    }
  }
}
