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
  Future<void> connectLobby(String userId, String username, {int rating = 1200}) async {
    _userId = userId;
    _username = username;
    _rating = rating;
    _ensureStreams();

    final baseUrl = dotenv.env['WS_URL'] ?? 'wss://chess-master-api.pp942920.workers.dev';
    final url = '$baseUrl/multiplayer/lobby?userId=$userId&username=$username&rating=$rating';
    
    // Close existing lobby connection gracefully
    try { await _lobbyChannel?.sink.close(); } catch (_) {}
    
    _lobbyChannel = WebSocketChannel.connect(Uri.parse(url));
    _lobbyChannel!.stream.listen((msg) {
      final data = jsonDecode(msg) as Map<String, dynamic>;
      if (!(_lobbyStreamCtrl?.isClosed ?? true)) {
        _lobbyStreamCtrl!.add(data);
      }
    }, onDone: () {
      _lobbyChannel = null;
      if (!(_lobbyStreamCtrl?.isClosed ?? true)) {
        _lobbyStreamCtrl!.add({'type': 'CONNECTION_LOST'});
      }
      debugPrint('Lobby disconnected');
    }, onError: (err) {
      _lobbyChannel = null;
      if (!(_lobbyStreamCtrl?.isClosed ?? true)) {
        _lobbyStreamCtrl!.add({'type': 'CONNECTION_LOST', 'error': err.toString()});
      }
    });
  }

  /// Start matchmaking
  void findMatch() {
    _lobbyChannel?.sink.add(jsonEncode({'type': 'FIND_MATCH'}));
  }

  /// Cancel matchmaking
  void cancelFindMatch() {
    _lobbyChannel?.sink.add(jsonEncode({'type': 'CANCEL_FIND_MATCH'}));
  }

  /// Connect to a specific game room
  Future<void> joinRoom(String gameId, String color) async {
    final baseUrl = dotenv.env['WS_URL'] ?? 'wss://chess-master-api.pp942920.workers.dev';
    final url = '$baseUrl/multiplayer/game/$gameId?userId=$_userId&username=$_username&color=$color&gameId=$gameId';
    
    try { await _gameChannel?.sink.close(); } catch (_) {}
    _ensureStreams();
    
    _gameChannel = WebSocketChannel.connect(Uri.parse(url));
    _gameChannel!.stream.listen((msg) {
      final data = jsonDecode(msg) as Map<String, dynamic>;
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
  void sendChallenge(String opponentId, String mode, String timeControl) {
    _lobbyChannel?.sink.add(jsonEncode({
      'type': 'CHALLENGE',
      'opponentId': opponentId,
      'mode': mode,
      'timeControl': timeControl,
    }));
  }

  /// Accept a direct challenge from another player
  void acceptChallenge(String challengerId, String mode, String timeControl) {
    _lobbyChannel?.sink.add(jsonEncode({
      'type': 'CHALLENGE_ACCEPTED',
      'challengerId': challengerId,
      'mode': mode,
      'timeControl': timeControl,
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
    try { _lobbyChannel?.sink.close(); } catch (_) {}
    _lobbyChannel = null;
  }

  /// Disconnect game only
  void disconnectGame() {
    try { _gameChannel?.sink.close(); } catch (_) {}
    _gameChannel = null;
  }

  /// Full dispose — closes everything, streams can be re-created on next connect
  void dispose() {
    try { _lobbyChannel?.sink.close(); } catch (_) {}
    try { _gameChannel?.sink.close(); } catch (_) {}
    _lobbyChannel = null;
    _gameChannel = null;
    // Close stream controllers — they'll be lazily re-created
    _lobbyStreamCtrl?.close();
    _gameStreamCtrl?.close();
    _lobbyStreamCtrl = null;
    _gameStreamCtrl = null;
  }
}
