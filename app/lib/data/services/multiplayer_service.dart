import 'dart:async';
import 'dart:convert';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:web_socket_channel/web_socket_channel.dart';

import '../../core/config/app_config.dart';

import 'reconnecting_socket.dart';

class MultiplayerService {
  WebSocketChannel? get _lobbyChannel => _lobbySocket.channel;
  String? _gameId;
  late final _lobbySocket = ReconnectingSocket(
    connect: WebSocketChannel.connect,
    onMessage: (message) => _forward(_lobbyStreamCtrl, message),
    onStatus: (connected, retrying, error) {
      if (connected)
        _startLobbyHeartbeat();
      else
        _stopLobbyHeartbeat();
      _lobbyStreamCtrl?.add({
        'type': 'CONNECTION_STATUS',
        'data': {
          'connected': connected,
          'retrying': retrying,
          'error': error,
        }
      });
    },
  );
  late final _gameSocket = ReconnectingSocket(
    connect: WebSocketChannel.connect,
    onMessage: (message) => _forward(_gameStreamCtrl, message),
    onStatus: (connected, retrying, error) => _gameStreamCtrl?.add({
      'type': 'CONNECTION_STATUS',
      'data': {
        'connected': connected,
        'gameId': _gameId,
        'retrying': retrying,
        'error': error,
      },
    }),
  );

  StreamController<Map<String, dynamic>>? _lobbyStreamCtrl;
  StreamController<Map<String, dynamic>>? _gameStreamCtrl;

  String? _userId;
  String? _username;
  int _rating = 1200;
  Timer? _lobbyHeartbeat;

  Future<void> _requireOnlineSession() async {
    if ((await SharedPreferences.getInstance())
            .getBool('guest_session_active') ==
        true) throw StateError('Sign in to play online');
  }

  // Lazy stream getters — re-create if closed
  Stream<Map<String, dynamic>> get lobbyUpdates {
    _lobbyStreamCtrl ??= StreamController<Map<String, dynamic>>.broadcast();
    return _lobbyStreamCtrl!.stream;
  }

  Stream<Map<String, dynamic>> get gameUpdates {
    _gameStreamCtrl ??= StreamController<Map<String, dynamic>>.broadcast();
    return _gameStreamCtrl!.stream;
  }

  bool get isLobbyConnected => _lobbySocket.connected;
  bool get isGameConnected => _gameSocket.connected;

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
  Future<void> connectLobby(
    String userId,
    String username, {
    int rating = 1200,
  }) async {
    await _requireOnlineSession();
    if (_lobbySocket.connected && _userId == userId && _username == username)
      return;
    _userId = userId;
    _username = username;
    _rating = rating;
    _ensureStreams();
    await _lobbySocket.open(() async {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('guest_session_active') == true)
        throw StateError('Sign in to play online');
      final token = prefs.getString('auth_token');
      if (token == null) throw StateError('Sign in to play online');
      return Uri.parse('${AppConfig.wsUrl}/multiplayer/lobby')
          .replace(queryParameters: {
        'userId': userId,
        'username': username,
        'token': token,
      });
    });
  }

  /// Manual retry after the bounded automatic retry budget has been exhausted.
  Future<void> reconnect() async {
    await Future.wait([
      _lobbySocket.reconnect(),
      _gameSocket.reconnect(),
      _tournamentSocket.reconnect()
    ]);
  }

  void _forward(
      StreamController<Map<String, dynamic>>? stream, dynamic message) {
    final data = _decodeMessage(message);
    if (data != null && stream != null && !stream.isClosed) stream.add(data);
  }

  void _startLobbyHeartbeat() {
    _lobbyHeartbeat?.cancel();
    _lobbyHeartbeat = Timer.periodic(const Duration(seconds: 25), (_) {
      if (_lobbyChannel != null) {
        try {
          _lobbySocket.send(jsonEncode({'type': 'PING'}));
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
    _lobbySocket.send(
      jsonEncode({
        'type': 'FIND_MATCH',
        'timeControl':
            (timeControl == null || timeControl.isEmpty) ? '10+0' : timeControl,
        'variantId': variantId,
      }),
    );
  }

  /// Cancel matchmaking
  void cancelFindMatch() {
    _lobbySocket.send(jsonEncode({'type': 'CANCEL_FIND_MATCH'}));
  }

  /// Connect to a specific game room
  Future<void> joinRoom(
    String gameId,
    String color, {
    String timeControl = '10+0',
    String variantId = 'standard',
  }) async {
    await _requireOnlineSession();
    if (_gameId == gameId && _gameSocket.connected) return;
    _gameId = gameId;
    _ensureStreams();
    await _gameSocket.open(() async {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('guest_session_active') == true)
        throw StateError('Sign in to play online');
      final token = prefs.getString('auth_token');
      if (token == null) throw StateError('Sign in to play online');
      return Uri.parse('${AppConfig.wsUrl}/multiplayer/game/$gameId')
          .replace(queryParameters: {'token': token});
    });
  }

  /// Send move in game
  void sendMove(Map<String, dynamic> move) {
    _gameSocket.send(jsonEncode({'type': 'MOVE', 'move': move}));
  }

  /// Send chat in game
  void sendChat(String message, {String? emoji}) {
    _gameSocket.send(
      jsonEncode({'type': 'CHAT', 'message': message, 'emoji': emoji}),
    );
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
    _lobbySocket.send(
      jsonEncode({
        'type': 'CHALLENGE',
        'opponentId': opponentId,
        'mode': mode,
        'timeControl': timeControl,
        'variantId': variantId,
        if (requestId != null) 'requestId': requestId,
        if (allowOffline) 'allowOffline': true,
        if (recipientStatus != null) 'recipientStatus': recipientStatus,
      }),
    );
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
    _lobbySocket.send(
      jsonEncode({
        'type': 'CHALLENGE_ACCEPTED',
        'challengerId': challengerId,
        'mode': mode,
        'timeControl': timeControl,
        'variantId': variantId,
        if (requestId != null) 'requestId': requestId,
        if (isQueued) 'queued': true,
      }),
    );
  }

  void declineChallenge(String challengerId, {String? requestId}) {
    _lobbySocket.send(
      jsonEncode({
        'type': 'CHALLENGE_DECLINED',
        'challengerId': challengerId,
        if (requestId != null) 'requestId': requestId,
      }),
    );
  }

  void sendPresence(String status, {String? gameId, String? context}) {
    _lobbySocket.send(
      jsonEncode({
        'type': 'PRESENCE_UPDATE',
        'status': status,
        if (gameId != null) 'gameId': gameId,
        if (context != null) 'context': context,
      }),
    );
  }

  /// Send XP broadcast to all online players
  void sendXpBroadcast(int amount) {
    _lobbySocket.send(
      jsonEncode({'type': 'XP_BROADCAST', 'amount': amount}),
    );
  }

  /// Resign game
  void resign() {
    _gameSocket.send(jsonEncode({'type': 'RESIGN'}));
  }

  /// Send draw offer to opponent
  void sendDrawOffer() {
    _gameSocket.send(jsonEncode({'type': 'DRAW_OFFER'}));
  }

  /// Accept draw offer
  void sendDrawAccept() {
    _gameSocket.send(jsonEncode({'type': 'DRAW_ACCEPT'}));
  }

  /// Decline draw offer
  void sendDrawDecline() {
    _gameSocket.send(jsonEncode({'type': 'DRAW_DECLINE'}));
  }

  /// Send undo request (notify opponent)
  void requestGameSync() {
    _gameSocket.send(jsonEncode({'type': 'SYNC'}));
  }

  void sendUndo() {
    _gameSocket.send(jsonEncode({'type': 'UNDO'}));
  }

  /// Request to save and quit game
  void sendSaveRequest() {
    _gameSocket.send(jsonEncode({'type': 'SAVE_REQUEST'}));
  }

  /// Accept save request
  void sendSaveAccept() {
    _gameSocket.send(jsonEncode({'type': 'SAVE_ACCEPT'}));
  }

  /// Decline save request
  void sendSaveDecline() {
    _gameSocket.send(jsonEncode({'type': 'SAVE_DECLINE'}));
  }

  /// Send rematch request
  void sendRematchRequest() {
    _gameSocket.send(jsonEncode({'type': 'REMATCH_REQUEST'}));
  }

  /// Accept rematch
  void sendRematchAccept() {
    _gameSocket.send(jsonEncode({'type': 'REMATCH_ACCEPT'}));
  }

  /// Disconnect lobby only — keeps streams alive for reconnection
  void disconnectLobby() {
    _stopLobbyHeartbeat();
    _lobbySocket.disconnect();
  }

  /// Explicit leave sends resignation once, then cancels all room retries.
  void leaveGame() {
    try {
      _gameSocket.send(jsonEncode({'type': 'LEAVE_GAME'}));
    } catch (_) {}
    disconnectGame();
  }

  void disconnectGame() {
    _gameSocket.disconnect();
    _gameId = null;
  }

  // ─── Tournament WebSocket ───────────────────────────────────────

  String? _tournamentId;
  late final _tournamentSocket = ReconnectingSocket(
    connect: WebSocketChannel.connect,
    onMessage: (message) => _forward(_tournamentStreamCtrl, message),
    onStatus: (connected, retrying, error) => _tournamentStreamCtrl?.add({
      'type': connected
          ? 'TOURNAMENT_CONNECTION_RESTORED'
          : 'TOURNAMENT_CONNECTION_LOST',
      'data': {'connected': connected, 'retrying': retrying, 'error': error},
    }),
  );
  StreamController<Map<String, dynamic>>? _tournamentStreamCtrl;

  Stream<Map<String, dynamic>> get tournamentUpdates {
    _tournamentStreamCtrl ??=
        StreamController<Map<String, dynamic>>.broadcast();
    return _tournamentStreamCtrl!.stream;
  }

  bool get isTournamentConnected => _tournamentSocket.connected;

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
    await _requireOnlineSession();
    if (_tournamentStreamCtrl == null || _tournamentStreamCtrl!.isClosed) {
      _tournamentStreamCtrl =
          StreamController<Map<String, dynamic>>.broadcast();
    }

    if (_tournamentId == tournamentId && _tournamentSocket.connected) return;
    _tournamentId = tournamentId;
    await _tournamentSocket.open(() async {
      final prefs = await SharedPreferences.getInstance();
      if (prefs.getBool('guest_session_active') == true)
        throw StateError('Sign in to play online');
      final token = prefs.getString('auth_token');
      if (token == null) throw StateError('Sign in to enter a tournament');
      return Uri.parse(
              '${AppConfig.wsUrl}/multiplayer/tournament/$tournamentId')
          .replace(queryParameters: {'token': token});
    });
  }

  /// Signal ready to start (triggers auto-start for 2-player private)
  void sendTournamentReady() {
    _tournamentSocket.send(jsonEncode({'type': 'READY'}));
  }

  /// Report a match result to the TournamentRoom DO
  void sendTournamentResult(String gameId, String result) {
    _tournamentSocket.send(
      jsonEncode({'type': 'MATCH_RESULT', 'gameId': gameId, 'result': result}),
    );
  }

  /// Send a tournament challenge via the lobby
  void sendTournamentChallenge({
    required String opponentId,
    required String tournamentId,
    required int totalRounds,
    required String timeControl,
  }) {
    _lobbySocket.send(
      jsonEncode({
        'type': 'TOURNAMENT_CHALLENGE',
        'opponentId': opponentId,
        'tournamentId': tournamentId,
        'totalRounds': totalRounds,
        'timeControl': timeControl,
      }),
    );
  }

  /// Accept a tournament challenge received via lobby
  void acceptTournamentChallenge(String challengerId, String tournamentId) {
    _lobbySocket.send(
      jsonEncode({
        'type': 'TOURNAMENT_CHALLENGE_ACCEPTED',
        'challengerId': challengerId,
        'tournamentId': tournamentId,
      }),
    );
  }

  /// Disconnect tournament WebSocket
  void disconnectTournament() {
    _tournamentSocket.disconnect();
    _tournamentId = null;
  }

  /// Full dispose — closes everything, streams can be re-created on next connect
  void dispose() {
    disconnectLobby();
    disconnectGame();
    disconnectTournament();
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
