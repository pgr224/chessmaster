import 'package:dio/dio.dart';
import '../models/tournament_model.dart';

class TournamentRepository {
  final Dio _dio;
  TournamentRepository(this._dio);

  Future<List<TournamentModel>> fetchTournaments() async {
    final response = await _dio.get('/api/tournament');
    final list = response.data['tournaments'] as List<dynamic>? ?? [];
    return list
        .map((e) => TournamentModel.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<TournamentModel> fetchTournament(String id) async {
    final response = await _dio.get('/api/tournament/$id');
    return TournamentModel.fromJson(response.data as Map<String, dynamic>);
  }

  Future<String> createTournament({
    required String name,
    required String type,
    required int totalRounds,
    required String timeControl,
    String format = 'swiss',
    List<String> invitedPlayers = const [],
  }) async {
    final response = await _dio.post('/api/tournament', data: {
      'name': name,
      'type': type,
      'total_rounds': totalRounds,
      'time_control': timeControl,
      'format': format,
      'invited_players': invitedPlayers,
    });
    return response.data['id'] as String;
  }

  Future<void> joinTournament(String id) async {
    await _dio.post('/api/tournament/$id/join');
  }

  Future<void> startTournament(String id) async {
    await _dio.post('/api/tournament/$id/start');
  }

  Future<void> reportResult(String tournamentId, String gameId, String result) async {
    await _dio.post('/api/tournament/$tournamentId/result', data: {
      'game_id': gameId,
      'result': result,
    });
  }

  Future<List<TournamentPlayer>> getStandings(String id) async {
    final response = await _dio.get('/api/tournament/$id/standings');
    final list = response.data['standings'] as List<dynamic>? ?? [];
    return list
        .map((e) => TournamentPlayer.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> invitePlayer(String tournamentId, String userId) async {
    await _dio.post('/api/tournament/$tournamentId/invite', data: {
      'invited_user_id': userId,
    });
  }

  Future<void> acceptInvite(String tournamentId) async {
    await _dio.post('/api/tournament/$tournamentId/accept-invite');
  }
}
