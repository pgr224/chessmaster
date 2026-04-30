import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';
import 'package:flutter/foundation.dart';

class MultiplayerService {
  WebSocketChannel? _lobbyChannel;
  WebSocketChannel? _gameChannel;

  StreamController<Map<String, dynamic>>? _lobbyStreamCtrl;
  StreamController<Map<String, dynamic>>? _gameStreamCtrl;

  String? _userId;
  String? _username;
  int _rating = 1200;
  Timer? _lobbyHeartbeat;

  // Lazy stream getters — re-create if closed
  Stream<Map<String, dynamic>> get lobbyUpdates {
    _lobbyStreamCtrl ??= StreamController<Map<String, dynamic>>.broadcast();
    return _lobbyStreamCtrl!.stream;
  }

  Stream<Map<String, dynamic>> get gameUpdates {
    _gameStreamCtrl ??= StreamController<Map<String, dynamic>>.broadcast();
    return _gameStreamCtrl!.stream;
  }

  bool get isLobbyConnected => _lobbyChannel != null;
  bool get isGameConnected => _gameChannel != null;

  String? get userId => _userId;
  String? get username => _username;
  int get rating => _rating;

  static final MultiplayerService _instance = MultiplayerService._internal();
  factory MultiplayerService() => _instance;
  MultiplayerService._internal();

  void _ensureStreams() {
    if (_lobbyStreamCtrl == null || _lobbyStreamCtrl!.isClosed) {
      _lobbyStreamCtrl = StreamController<Map<String, dynamic>>.broadcast();
    }
    if (_gameStreamCtrl == null || _gameStreamCtrl!.isClosed) {
      _gameStreamCtrl = StreamController<Map<String, dynamic>>.broadcast();
    }
  }

  /// Connect to the global lobby
  Future<void> connectLobby(String userId, String username,
      {int rating = 1200}) async {
    if (_lobbyChannel != null && _userId == userId && _username == username) {
      return;
    }

    _userId = userId;
    _username = username;
    _rating = rating;
    _ensureStreams();

    final baseUrl =
        dotenv.env['WS_URL'] ?? 'wss://chess-master-api.pp942920.workers.dev';
    final url =
        '$baseUrl/multiplayer/lobby?userId=$userId&username=$username&rating=$rating';

    // Close existing lobby connection gracefully
    _stopLobbyHeartbeat();
    try {
      await _lobbyChannel?.sink.close();
    } catch (_) {}

    try {
      _lobbyChannel = WebSocketChannel.connect(Uri.parse(url));
      _lobbyChannel!.stream.listen((msg) {
        final data = _decodeMessage(msg);
        if (data == null) return;
        if (!(_lobbyStreamCtrl?.isClosed ?? true)) {
          _lobbyStreamCtrl!.add(data);
        }
      }, onDone: () {
        _lobbyChannel = null;
        _stopLobbyHeartbeat();
        if (!(_lobbyStreamCtrl?.isClosed ?? true)) {
          _lobbyStreamCtrl!.add({'type': 'CONNECTION_LOST'});
        }
        debugPrint('Lobby WS closed');
      }, onError: (err) {
        _lobbyChannel = null;
        _stopLobbyHeartbeat();
        if (!(_lobbyStreamCtrl?.isClosed ?? true)) {
          _lobbyStreamCtrl!
              .add({'type': 'CONNECTION_LOST', 'error': err.toString()});
        }
      });

      // Start heartbeat to keep connection alive (Cloudflare DO idle timeout)
      _startLobbyHeartbeat();
    } catch (e) {
      _lobbyChannel = null;
      debugPrint('Lobby connect error: $e');
      if (!(_lobbyStreamCtrl?.isClosed ?? true)) {
        _lobbyStreamCtrl!.add({'type': 'CONNECTION_LOST', 'error': e.toString()});
      }
    }
  }

  void _startLobbyHeartbeat() {
    _lobbyHeartbeat?.cancel();
    _lobbyHeartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_lobbyChannel != null) {
        try {
          _lobbyChannel!.sink.add(jsonEncode({'type': 'PING'}));
        } catch (_) {
          _stopLobbyHeartbeat();
        }
      } else {
        _stopLobbyHeartbeat();
      }
    });
  }

  void _stopLobbyHeartbeat() {
    _lobbyHeartbeat?.cancel();
    _lobbyHeartbeat = null;
  }

  /// Start matchmaking
  void findMatch({String? timeControl, String variantId = 'standard'}) {
    _lobbyChannel?.sink.add(jsonEncode({
      'type': 'FIND_MATCH',
      'timeControl': (timeControl == null || timeControl.isEmpty)
          ? '10+0'
          : timeControl,
      'variantId': variantId,
    }));
  }

  /// Cancel matchmaking
  void cancelFindMatch() {
    _lobbyChannel?.sink.add(jsonEncode({'type': 'CANCEL_FIND_MATCH'}));
  }

  /// Connect to a specific game room
    Future<void> joinRoom(String gameId, String color,
      {String timeControl = '10+0', String variantId = 'standard'}) async {
    final baseUrl =
        dotenv.env['WS_URL'] ?? 'wss://chess-master-api.pp942920.workers.dev';
    final url =
      '$baseUrl/multiplayer/game/$gameId?userId=$_userId&username=$_username&color=$color&timeControl=${Uri.encodeComponent(timeControl)}&variantId=${Uri.encodeComponent(variantId)}&gameId=$gameId';

    try {
      await _gameChannel?.sink.close();
    } catch (_) {}
    _ensureStreams();

    _gameChannel = WebSocketChannel.connect(Uri.parse(url));
    _gameChannel!.stream.listen((msg) {
      final data = _decodeMessage(msg);
      if (data == null) return;
      if (!(_gameStreamCtrl?.isClosed ?? true)) {
        _gameStreamCtrl!.add(data);
      }
    }, onDone: () {
      _gameChannel = null;
      debugPrint('Game session ended');
    }, onError: (err) {
      _gameChannel = null;
      debugPrint('Game connection error: $err');
    });
  }

  /// Send move in game
  void sendMove(Map<String, dynamic> move) {
    _gameChannel?.sink.add(jsonEncode({
      'type': 'MOVE',
      'move': move,
    }));
  }

  /// Send chat in game
  void sendChat(String message, {String? emoji}) {
    _gameChannel?.sink.add(jsonEncode({
      'type': 'CHAT',
      'message': message,
      'emoji': emoji,
    }));
  }

  /// Send a direct challenge to another player in the lobby
  void sendChallenge(
    String opponentId,
    String mode,
    String timeControl,
    String variantId, {
    String? requestId,
    bool allowOffline = false,
    String? recipientStatus,
  }) {
    _lobbyChannel?.sink.add(jsonEncode({
      'type': 'CHALLENGE',
      'opponentId': opponentId,
      'mode': mode,
      'timeControl': timeControl,
      'variantId': variantId,
      if (requestId != null) 'requestId': requestId,
      if (allowOffline) 'allowOffline': true,
      if (recipientStatus != null) 'recipientStatus': recipientStatus,
    }));
  }

  /// Accept a direct challenge from another player
  void acceptChallenge(
    String challengerId,
    String mode,
    String timeControl,
    String variantId, {
    String? requestId,
    bool isQueued = false,
  }) {
    _lobbyChannel?.sink.add(jsonEncode({
      'type': 'CHALLENGE_ACCEPTED',
      'challengerId': challengerId,
      'mode': mode,
      'timeControl': timeControl,
      'variantId': variantId,
      if (requestId != null) 'requestId': requestId,
      if (isQueued) 'queued': true,
    }));
  }

  void declineChallenge(String challengerId, {String? requestId}) {
    _lobbyChannel?.sink.add(jsonEncode({
      'type': 'CHALLENGE_DECLINED',
      'challengerId': challengerId,
      if (requestId != null) 'requestId': requestId,
    }));
  }

  void sendPresence(String status, {String? gameId, String? context}) {
    _lobbyChannel?.sink.add(jsonEncode({
      'type': 'PRESENCE_UPDATE',
      'status': status,
      if (gameId != null) 'gameId': gameId,
      if (context != null) 'context': context,
    }));
  }

  /// Send XP broadcast to all online players
  void sendXpBroadcast(int amount) {
    _lobbyChannel?.sink.add(jsonEncode({
      'type': 'XP_BROADCAST',
      'amount': amount,
    }));
  }

  /// Resign game
  void resign() {
    _gameChannel?.sink.add(jsonEncode({'type': 'RESIGN'}));
  }

  /// Send draw offer to opponent
  void sendDrawOffer() {
    _gameChannel?.sink.add(jsonEncode({'type': 'DRAW_OFFER'}));
  }

  /// Accept draw offer
  void sendDrawAccept() {
    _gameChannel?.sink.add(jsonEncode({'type': 'DRAW_ACCEPT'}));
  }

  /// Decline draw offer
  void sendDrawDecline() {
    _gameChannel?.sink.add(jsonEncode({'type': 'DRAW_DECLINE'}));
  }

  /// Send undo request (notify opponent)
  void sendUndo() {
    _gameChannel?.sink.add(jsonEncode({'type': 'UNDO'}));
  }

  /// Request to save and quit game
  void sendSaveRequest() {
    _gameChannel?.sink.add(jsonEncode({'type': 'SAVE_REQUEST'}));
  }

  /// Accept save request
  void sendSaveAccept() {
    _gameChannel?.sink.add(jsonEncode({'type': 'SAVE_ACCEPT'}));
  }

  /// Decline save request
  void sendSaveDecline() {
    _gameChannel?.sink.add(jsonEncode({'type': 'SAVE_DECLINE'}));
  }

  /// Send rematch request
  void sendRematchRequest() {
    _gameChannel?.sink.add(jsonEncode({'type': 'REMATCH_REQUEST'}));
  }

  /// Accept rematch
  void sendRematchAccept() {
    _gameChannel?.sink.add(jsonEncode({'type': 'REMATCH_ACCEPT'}));
  }

  /// Disconnect lobby only — keeps streams alive for reconnection
  void disconnectLobby() {
    _stopLobbyHeartbeat();
    try {
      _lobbyChannel?.sink.close();
    } catch (_) {}
    _lobbyChannel = null;
  }

  /// Disconnect game only
  void disconnectGame() {
    try {
      _gameChannel?.sink.close();
    } catch (_) {}
    _gameChannel = null;
  }

  // ─── Tournament WebSocket ───────────────────────────────────────

  WebSocketChannel? _tournamentChannel;
  StreamController<Map<String, dynamic>>? _tournamentStreamCtrl;

  Stream<Map<String, dynamic>> get tournamentUpdates {
    _tournamentStreamCtrl ??=
        StreamController<Map<String, dynamic>>.broadcast();
    return _tournamentStreamCtrl!.stream;
  }

  bool get isTournamentConnected => _tournamentChannel != null;

  /// Connect to a TournamentRoom Durable Object
  Future<void> connectTournament(
    String tournamentId,
    String userId,
    String username, {
    int rating = 1200,
    int totalRounds = 3,
    String timeControl = '10+0',
    String type = 'private',
  }) async {
    if (_tournamentStreamCtrl == null || _tournamentStreamCtrl!.isClosed) {
      _tournamentStreamCtrl =
          StreamController<Map<String, dynamic>>.broadcast();
    }

    final baseUrl =
        dotenv.env['WS_URL'] ?? 'wss://chess-master-api.pp942920.workers.dev';
    final uri = Uri.parse(
      '$baseUrl/multiplayer/tournament/$tournamentId'
      '?userId=$userId&username=$username&rating=$rating'
      '&totalRounds=$totalRounds&timeControl=${Uri.encodeComponent(timeControl)}&type=$type',
    );

    try {
      await _tournamentChannel?.sink.close();
    } catch (_) {}

    _tournamentChannel = WebSocketChannel.connect(uri);
    _tournamentChannel!.stream.listen(
      (msg) {
        final data = _decodeMessage(msg);
        if (data == null) return;
        if (!(_tournamentStreamCtrl?.isClosed ?? true)) {
          _tournamentStreamCtrl!.add(data);
        }
      },
      onDone: () {
        _tournamentChannel = null;
        if (!(_tournamentStreamCtrl?.isClosed ?? true)) {
          _tournamentStreamCtrl!.add({'type': 'TOURNAMENT_CONNECTION_LOST'});
        }
      },
      onError: (err) {
        _tournamentChannel = null;
        debugPrint('Tournament WS error: $err');
      },
    );
  }

  /// Signal ready to start (triggers auto-start for 2-player private)
  void sendTournamentReady() {
    _tournamentChannel?.sink.add(jsonEncode({'type': 'READY'}));
  }

  /// Report a match result to the TournamentRoom DO
  void sendTournamentResult(String gameId, String result) {
    _tournamentChannel?.sink.add(jsonEncode({
      'type': 'MATCH_RESULT',
      'gameId': gameId,
      'result': result,
    }));
  }

  /// Send a tournament challenge via the lobby
  void sendTournamentChallenge({
    required String opponentId,
    required String tournamentId,
    required int totalRounds,
    required String timeControl,
  }) {
    _lobbyChannel?.sink.add(jsonEncode({
      'type': 'TOURNAMENT_CHALLENGE',
      'opponentId': opponentId,
      'tournamentId': tournamentId,
      'totalRounds': totalRounds,
      'timeControl': timeControl,
    }));
  }

  /// Accept a tournament challenge received via lobby
  void acceptTournamentChallenge(String challengerId, String tournamentId) {
    _lobbyChannel?.sink.add(jsonEncode({
      'type': 'TOURNAMENT_CHALLENGE_ACCEPTED',
      'challengerId': challengerId,
      'tournamentId': tournamentId,
    }));
  }

  /// Disconnect tournament WebSocket
  void disconnectTournament() {
    try {
      _tournamentChannel?.sink.close();
    } catch (_) {}
    _tournamentChannel = null;
  }

  /// Full dispose — closes everything, streams can be re-created on next connect
  void dispose() {
    _stopLobbyHeartbeat();
    try {
      _lobbyChannel?.sink.close();
    } catch (_) {}
    try {
      _gameChannel?.sink.close();
    } catch (_) {}
    try {
      _tournamentChannel?.sink.close();
    } catch (_) {}
    _lobbyChannel = null;
    _gameChannel = null;
    _tournamentChannel = null;
    // Close stream controllers — they'll be lazily re-created
    _lobbyStreamCtrl?.close();
    _gameStreamCtrl?.close();
    _tournamentStreamCtrl?.close();
    _lobbyStreamCtrl = null;
    _gameStreamCtrl = null;
    _tournamentStreamCtrl = null;
  }

  Map<String, dynamic>? _decodeMessage(dynamic msg) {
    try {
      final decoded = jsonDecode(msg.toString());
      if (decoded is Map<String, dynamic>) return decoded;
      if (decoded is Map) {
        return decoded.map((k, v) => MapEntry(k.toString(), v));
      }
      return null;
    } catch (_) {
      return null;
    }
  }
}
