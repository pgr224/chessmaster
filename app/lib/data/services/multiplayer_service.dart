import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum WsMessageType {
  // Outgoing
  FIND_MATCH, CANCEL_FIND_MATCH, MOVE, CHAT, RESIGN,
  // Incoming
  LOBBY_UPDATE, MATCH_FOUND, MOVE_UPDATE, CHAT_UPDATE, ROOM_STATE,
  PLAYER_DISCONNECTED, GAME_OVER, ERROR
}

class MultiplayerService {
  WebSocketChannel? _lobbyChannel;
  WebSocketChannel? _gameChannel;
  
  final _lobbyStream = StreamController<Map<String, dynamic>>.broadcast();
  final _gameStream = StreamController<Map<String, dynamic>>.broadcast();

  String? _userId;
  String? _username;
  int _rating = 1200;

  Stream<Map<String, dynamic>> get lobbyUpdates => _lobbyStream.stream;
  Stream<Map<String, dynamic>> get gameUpdates => _gameStream.stream;

  bool get isLobbyConnected => _lobbyChannel != null;
  bool get isGameConnected => _gameChannel != null;

  static final MultiplayerService _instance = MultiplayerService._internal();
  factory MultiplayerService() => _instance;
  MultiplayerService._internal();

  /// Connect to the global lobby
  Future<void> connectLobby(String userId, String username, {int rating = 1200}) async {
    _userId = userId;
    _username = username;
    _rating = rating;

    final baseUrl = dotenv.env['WS_URL'] ?? 'wss://chess-master-api.pp942920.workers.dev';
    final url = '$baseUrl/multiplayer/lobby?userId=$userId&username=$username&rating=$rating';
    
    _lobbyChannel = WebSocketChannel.connect(Uri.parse(url));
    _lobbyChannel!.stream.listen((msg) {
      final data = jsonDecode(msg) as Map<String, dynamic>;
      _lobbyStream.add(data);
    }, onDone: () {
      _lobbyChannel = null;
      _lobbyStream.add({'type': 'CONNECTION_LOST'});
      print('Lobby disconnected');
    }, onError: (err) {
      _lobbyChannel = null;
      _lobbyStream.add({'type': 'CONNECTION_LOST', 'error': err.toString()});
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
    
    await _gameChannel?.sink.close();
    _gameChannel = WebSocketChannel.connect(Uri.parse(url));
    _gameChannel!.stream.listen((msg) {
      final data = jsonDecode(msg) as Map<String, dynamic>;
      _gameStream.add(data);
    }, onDone: () => print('Game session ended'));
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

  void dispose() {
    _lobbyChannel?.sink.close();
    _gameChannel?.sink.close();
    _lobbyStream.close();
    _gameStream.close();
  }
}
