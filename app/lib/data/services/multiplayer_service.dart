import 'dart:async';
import 'dart:convert';
import 'package:web_socket_channel/web_socket_channel.dart';
import 'package:flutter_dotenv/flutter_dotenv.dart';

enum WsMessageType {
  join, move, chat, resign, drawOffer, drawAccept, drawDecline,
  playerJoined, playerLeft, gameStart, gameOver, error, ping, pong,
  matchFound, challenge, challengeAccept, challengeDecline, tournamentUpdate,
}

class WsMessage {
  final WsMessageType type;
  final Map<String, dynamic> data;

  WsMessage({required this.type, required this.data});

  factory WsMessage.fromJson(Map<String, dynamic> json) {
    return WsMessage(
      type: WsMessageType.values.firstWhere(
        (e) => e.name == json['type'],
        orElse: () => WsMessageType.error,
      ),
      data: json['data'] as Map<String, dynamic>? ?? {},
    );
  }

  Map<String, dynamic> toJson() => {
    'type': type.name,
    'data': data,
  };
}

class MultiplayerService {
  WebSocketChannel? _channel;
  final _messageController = StreamController<WsMessage>.broadcast();
  Timer? _pingTimer;
  String? _userId;
  String? _gameId;
  bool _isConnected = false;

  Stream<WsMessage> get messages => _messageController.stream;
  bool get isConnected => _isConnected;

  static final MultiplayerService _instance = MultiplayerService._internal();
  factory MultiplayerService() => _instance;
  MultiplayerService._internal();

  Future<void> connect(String userId, {String? gameId}) async {
    _userId = userId;
    _gameId = gameId;

    final wsUrl = dotenv.env['WS_URL'] ?? 'wss://chess-api.yourdomain.com';
    final uri = Uri.parse('$wsUrl/multiplayer?userId=$userId${gameId != null ? "&gameId=$gameId" : ""}');

    try {
      _channel = WebSocketChannel.connect(uri);
      _isConnected = true;

      _channel!.stream.listen(
        (message) {
          try {
            final json = jsonDecode(message as String) as Map<String, dynamic>;
            final wsMsg = WsMessage.fromJson(json);
            if (wsMsg.type == WsMessageType.ping) {
              send(WsMessage(type: WsMessageType.pong, data: {}));
            } else {
              _messageController.add(wsMsg);
            }
          } catch (_) {}
        },
        onDone: _onDisconnect,
        onError: (_) => _onDisconnect(),
      );

      _startPingTimer();
      send(WsMessage(type: WsMessageType.join, data: {'userId': userId}));
    } catch (e) {
      _isConnected = false;
      _messageController.addError(e);
    }
  }

  void send(WsMessage message) {
    if (!_isConnected || _channel == null) return;
    try {
      _channel!.sink.add(jsonEncode(message.toJson()));
    } catch (_) {}
  }

  void sendMove({required String from, required String to, String? promotion}) {
    send(WsMessage(
      type: WsMessageType.move,
      data: {
        'gameId': _gameId,
        'from': from,
        'to': to,
        if (promotion != null) 'promotion': promotion,
        'userId': _userId,
        'timestamp': DateTime.now().millisecondsSinceEpoch,
      },
    ));
  }

  void sendChat(String message) {
    send(WsMessage(
      type: WsMessageType.chat,
      data: {'message': message, 'userId': _userId, 'gameId': _gameId},
    ));
  }

  void sendResign() {
    send(WsMessage(type: WsMessageType.resign, data: {'userId': _userId, 'gameId': _gameId}));
  }

  void sendDrawOffer() {
    send(WsMessage(type: WsMessageType.drawOffer, data: {'userId': _userId, 'gameId': _gameId}));
  }

  void joinMatchmaking(String timeControl) {
    send(WsMessage(
      type: WsMessageType.join,
      data: {'mode': 'matchmaking', 'timeControl': timeControl, 'userId': _userId},
    ));
  }

  void sendChallenge({
    required String opponentId,
    required String mode,
    required String timeControl,
  }) {
    send(WsMessage(
      type: WsMessageType.challenge,
      data: {
        'userId': _userId,
        'opponentId': opponentId,
        'mode': mode,
        'timeControl': timeControl,
      },
    ));
  }

  void _startPingTimer() {
    _pingTimer?.cancel();
    _pingTimer = Timer.periodic(const Duration(seconds: 30), (_) {
      if (_isConnected) send(WsMessage(type: WsMessageType.ping, data: {}));
    });
  }

  void _onDisconnect() {
    _isConnected = false;
    _pingTimer?.cancel();
    // Auto-reconnect with backoff
    Future.delayed(const Duration(seconds: 3), () {
      if (_userId != null) connect(_userId!, gameId: _gameId);
    });
  }

  Future<void> disconnect() async {
    _pingTimer?.cancel();
    _isConnected = false;
    await _channel?.sink.close();
    _channel = null;
  }

  void dispose() {
    disconnect();
    _messageController.close();
  }
}
