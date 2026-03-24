import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../../domain/engine/chess_engine.dart';

// ═══════════════════════════════════════════
// EVENTS
// ═══════════════════════════════════════════
abstract class MultiplayerEvent extends Equatable {
  const MultiplayerEvent();
  @override List<Object?> get props => [];
}

class MpConnectEvent extends MultiplayerEvent {
  final String userId;
  const MpConnectEvent(this.userId);
  @override List<Object?> get props => [userId];
}

class MpJoinMatchmakingEvent extends MultiplayerEvent {
  final String timeControl;
  const MpJoinMatchmakingEvent({this.timeControl = '10+0'});
  @override List<Object?> get props => [timeControl];
}

class MpCancelMatchmakingEvent extends MultiplayerEvent {}

class MpGameFoundEvent extends MultiplayerEvent {
  final String gameId;
  final String opponentName;
  final String opponentAvatar;
  final PieceColor playerColor;
  const MpGameFoundEvent({
    required this.gameId,
    required this.opponentName,
    required this.opponentAvatar,
    required this.playerColor,
  });
  @override List<Object?> get props => [gameId, opponentName, playerColor];
}

class MpMakeMoveEvent extends MultiplayerEvent {
  final String from;
  final String to;
  final String? promotion;
  const MpMakeMoveEvent(this.from, this.to, {this.promotion});
  @override List<Object?> get props => [from, to, promotion];
}

class MpOpponentMoveEvent extends MultiplayerEvent {
  final String from;
  final String to;
  final String? promotion;
  const MpOpponentMoveEvent(this.from, this.to, {this.promotion});
}

class MpSendChatEvent extends MultiplayerEvent {
  final String message;
  const MpSendChatEvent(this.message);
  @override List<Object?> get props => [message];
}

class MpChatReceivedEvent extends MultiplayerEvent {
  final ChatMessage message;
  const MpChatReceivedEvent(this.message);
}

class MpResignEvent extends MultiplayerEvent {}
class MpDrawOfferEvent extends MultiplayerEvent {}
class MpDrawAcceptEvent extends MultiplayerEvent {}
class MpDrawDeclineEvent extends MultiplayerEvent {}
class MpOpponentLeftEvent extends MultiplayerEvent {}
class MpDisconnectEvent extends MultiplayerEvent {}

// ═══════════════════════════════════════════
// MODELS
// ═══════════════════════════════════════════
class ChatMessage {
  final String userId;
  final String username;
  final String message;
  final DateTime timestamp;
  final bool isMe;

  const ChatMessage({
    required this.userId,
    required this.username,
    required this.message,
    required this.timestamp,
    required this.isMe,
  });
}

enum MultiplayerStatus {
  disconnected, connecting, inLobby, matchmaking,
  gameFound, inGame, gameOver,
}

class MoveDetail extends Equatable {
  final String from;
  final String to;
  final String? promotion;

  const MoveDetail({required this.from, required this.to, this.promotion});

  @override
  List<Object?> get props => [from, to, promotion];
}

// ═══════════════════════════════════════════
// STATE
// ═══════════════════════════════════════════
class MultiplayerState extends Equatable {
  final MultiplayerStatus status;
  final String? gameId;
  final String? opponentName;
  final String? opponentAvatar;
  final PieceColor? playerColor;
  final List<ChatMessage> chatMessages;
  final bool drawOffered;
  final bool opponentLeft;
  final String? errorMessage;
  final Duration? matchmakingTime;
  final int onlineCount;
  final MoveDetail? lastOpponentMove;

  const MultiplayerState({
    this.status = MultiplayerStatus.disconnected,
    this.gameId,
    this.opponentName,
    this.opponentAvatar,
    this.playerColor,
    this.chatMessages = const [],
    this.drawOffered = false,
    this.opponentLeft = false,
    this.errorMessage,
    this.matchmakingTime,
    this.onlineCount = 0,
    this.lastOpponentMove,
  });

  MultiplayerState copyWith({
    MultiplayerStatus? status,
    String? gameId,
    String? opponentName,
    String? opponentAvatar,
    PieceColor? playerColor,
    List<ChatMessage>? chatMessages,
    bool? drawOffered,
    bool? opponentLeft,
    String? errorMessage,
    Duration? matchmakingTime,
    int? onlineCount,
    MoveDetail? lastOpponentMove,
    bool clearLastMove = false,
  }) {
    return MultiplayerState(
      status: status ?? this.status,
      gameId: gameId ?? this.gameId,
      opponentName: opponentName ?? this.opponentName,
      opponentAvatar: opponentAvatar ?? this.opponentAvatar,
      playerColor: playerColor ?? this.playerColor,
      chatMessages: chatMessages ?? this.chatMessages,
      drawOffered: drawOffered ?? this.drawOffered,
      opponentLeft: opponentLeft ?? this.opponentLeft,
      errorMessage: errorMessage ?? this.errorMessage,
      matchmakingTime: matchmakingTime ?? this.matchmakingTime,
      onlineCount: onlineCount ?? this.onlineCount,
      lastOpponentMove: clearLastMove ? null : (lastOpponentMove ?? this.lastOpponentMove),
    );
  }

  @override
  List<Object?> get props => [
    status, gameId, opponentName, chatMessages, drawOffered, opponentLeft, lastOpponentMove
  ];
}

// ═══════════════════════════════════════════
// BLOC
// ═══════════════════════════════════════════
class MultiplayerBloc extends Bloc<MultiplayerEvent, MultiplayerState> {
  final MultiplayerService _service;

  MultiplayerBloc(this._service) : super(const MultiplayerState()) {
    on<MpConnectEvent>(_onConnect);
    on<MpJoinMatchmakingEvent>(_onJoinMatchmaking);
    on<MpCancelMatchmakingEvent>(_onCancelMatchmaking);
    on<MpGameFoundEvent>(_onGameFound);
    on<MpMakeMoveEvent>(_onMakeMove);
    on<MpOpponentMoveEvent>(_onOpponentMove);
    on<MpSendChatEvent>(_onSendChat);
    on<MpChatReceivedEvent>(_onChatReceived);
    on<MpResignEvent>(_onResign);
    on<MpDrawOfferEvent>(_onDrawOffer);
    on<MpDrawAcceptEvent>(_onDrawAccept);
    on<MpDrawDeclineEvent>(_onDrawDecline);
    on<MpOpponentLeftEvent>(_onOpponentLeft);
    on<MpDisconnectEvent>(_onDisconnect);
  }

  Future<void> _onConnect(MpConnectEvent event, Emitter<MultiplayerState> emit) async {
    emit(state.copyWith(status: MultiplayerStatus.connecting));
    await _service.connect(event.userId);

    // Listen to incoming WS messages
    _service.messages.listen((msg) {
      switch (msg.type) {
        case WsMessageType.matchFound:
          add(MpGameFoundEvent(
            gameId: msg.data['gameId'],
            opponentName: msg.data['opponentName'],
            opponentAvatar: msg.data['opponentAvatar'] ?? '',
            playerColor: msg.data['color'] == 'white' ? PieceColor.white : PieceColor.black,
          ));
          break;
        case WsMessageType.move:
          add(MpOpponentMoveEvent(msg.data['from'], msg.data['to'], promotion: msg.data['promotion']));
          break;
        case WsMessageType.chat:
          add(MpChatReceivedEvent(ChatMessage(
            userId: msg.data['userId'],
            username: msg.data['username'] ?? 'Opponent',
            message: msg.data['message'],
            timestamp: DateTime.fromMillisecondsSinceEpoch(msg.data['timestamp'] ?? 0),
            isMe: false,
          )));
          break;
        case WsMessageType.playerLeft:
          add(MpOpponentLeftEvent());
          break;
        default:
          break;
      }
    });

    emit(state.copyWith(status: MultiplayerStatus.inLobby));
  }

  void _onJoinMatchmaking(MpJoinMatchmakingEvent event, Emitter<MultiplayerState> emit) {
    _service.joinMatchmaking(event.timeControl);
    emit(state.copyWith(status: MultiplayerStatus.matchmaking));
  }

  void _onCancelMatchmaking(MpCancelMatchmakingEvent event, Emitter<MultiplayerState> emit) {
    emit(state.copyWith(status: MultiplayerStatus.inLobby));
  }

  void _onGameFound(MpGameFoundEvent event, Emitter<MultiplayerState> emit) {
    emit(state.copyWith(
      status: MultiplayerStatus.inGame,
      gameId: event.gameId,
      opponentName: event.opponentName,
      opponentAvatar: event.opponentAvatar,
      playerColor: event.playerColor,
    ));
  }

  void _onMakeMove(MpMakeMoveEvent event, Emitter<MultiplayerState> emit) {
    _service.sendMove(from: event.from, to: event.to, promotion: event.promotion);
    emit(state.copyWith(clearLastMove: true)); // Clear opponent move when we move
  }

  void _onOpponentMove(MpOpponentMoveEvent event, Emitter<MultiplayerState> emit) {
    emit(state.copyWith(
      lastOpponentMove: MoveDetail(from: event.from, to: event.to, promotion: event.promotion),
    ));
  }

  void _onSendChat(MpSendChatEvent event, Emitter<MultiplayerState> emit) {
    _service.sendChat(event.message);
    final msg = ChatMessage(
      userId: 'me',
      username: 'You',
      message: event.message,
      timestamp: DateTime.now(),
      isMe: true,
    );
    emit(state.copyWith(chatMessages: [...state.chatMessages, msg]));
  }

  void _onChatReceived(MpChatReceivedEvent event, Emitter<MultiplayerState> emit) {
    emit(state.copyWith(chatMessages: [...state.chatMessages, event.message]));
  }

  void _onResign(MpResignEvent event, Emitter<MultiplayerState> emit) {
    _service.sendResign();
    emit(state.copyWith(status: MultiplayerStatus.gameOver));
  }

  void _onDrawOffer(MpDrawOfferEvent event, Emitter<MultiplayerState> emit) {
    _service.sendDrawOffer();
  }

  void _onDrawAccept(MpDrawAcceptEvent event, Emitter<MultiplayerState> emit) {
    _service.send(WsMessage(type: WsMessageType.drawAccept, data: {}));
    emit(state.copyWith(status: MultiplayerStatus.gameOver, drawOffered: false));
  }

  void _onDrawDecline(MpDrawDeclineEvent event, Emitter<MultiplayerState> emit) {
    _service.send(WsMessage(type: WsMessageType.drawDecline, data: {}));
    emit(state.copyWith(drawOffered: false));
  }

  void _onOpponentLeft(MpOpponentLeftEvent event, Emitter<MultiplayerState> emit) {
    emit(state.copyWith(opponentLeft: true, status: MultiplayerStatus.gameOver));
  }

  void _onDisconnect(MpDisconnectEvent event, Emitter<MultiplayerState> emit) {
    _service.disconnect();
    emit(const MultiplayerState());
  }
}
