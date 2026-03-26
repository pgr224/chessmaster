import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/multiplayer_models.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../../domain/engine/chess_engine.dart';

// RE-EXPORT MODELS
export '../../../data/models/multiplayer_models.dart';

// EVENTS
abstract class MultiplayerEvent extends Equatable {
  const MultiplayerEvent();
  @override List<Object?> get props => [];
}

class MpConnectLobbyEvent extends MultiplayerEvent {
  final String userId;
  final String username;
  final int rating;
  const MpConnectLobbyEvent(this.userId, this.username, {this.rating = 1200});
  @override List<Object?> get props => [userId, username, rating];
}

class MpStartMatchmakingEvent extends MultiplayerEvent {}
class MpCancelMatchmakingEvent extends MultiplayerEvent {}

class MpGameFoundEvent extends MultiplayerEvent {
  final String gameId;
  final String color;
  final String opponentName;
  const MpGameFoundEvent(this.gameId, this.color, this.opponentName);
}

class MpMakeMoveEvent extends MultiplayerEvent {
  final String from;
  final String to;
  final String? promotion;
  const MpMakeMoveEvent(this.from, this.to, {this.promotion});
}

class MpOpponentMoveEvent extends MultiplayerEvent {
  final dynamic moveData;
  const MpOpponentMoveEvent(this.moveData);
}

class MpSendChatEvent extends MultiplayerEvent {
  final String message;
  final String? emoji;
  const MpSendChatEvent(this.message, {this.emoji});
}

class MpChatReceivedEvent extends MultiplayerEvent {
  final ChatMessage message;
  const MpChatReceivedEvent(this.message);
}

class MpGameOverEvent extends MultiplayerEvent {
  final String result;
  final String reason;
  const MpGameOverEvent(this.result, this.reason);
}

class MpLobbyUpdateEvent extends MultiplayerEvent {
  final int online;
  final int searching;
  final List<OnlineLobbyUser> availablePlayers;
  const MpLobbyUpdateEvent(this.online, this.searching, this.availablePlayers);
}

enum ChallengeMode { duel, tournament }

class MpSendChallengeEvent extends MultiplayerEvent {
  final OnlineLobbyUser opponent;
  final ChallengeMode mode;
  final String timeControl;
  const MpSendChallengeEvent({required this.opponent, required this.mode, required this.timeControl});
  @override List<Object?> get props => [opponent, mode, timeControl];
}

class MpAcceptChallengeEvent extends MultiplayerEvent {
  final String challengerId;
  const MpAcceptChallengeEvent(this.challengerId);
}
class MpClearNoticeEvent extends MultiplayerEvent {}

class MpResignEvent extends MultiplayerEvent {}
class MpLobbyNoticeEvent extends MultiplayerEvent {
  final String message;
  final String? challengerId;
  const MpLobbyNoticeEvent(this.message, {this.challengerId});
}
class MpDisconnectLobbyEvent extends MultiplayerEvent {}

// STATE
enum MultiplayerStatus { disconnected, inLobby, matchmaking, inGame, gameOver }

class MultiplayerState extends Equatable {
  final MultiplayerStatus status;
  final int onlineCount;
  final int searchingCount;
  final List<OnlineLobbyUser> availablePlayers;
  final String? gameId;
  final PieceColor? playerColor;
  final String? opponentName;
  final List<ChatMessage> chatMessages;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final String? lastMovePromotion;
  final String? gameResult;
  final String? gameReason;
  final String? lobbyNotice;
  final String? challengerId;

  const MultiplayerState({
    this.status = MultiplayerStatus.disconnected,
    this.onlineCount = 0,
    this.searchingCount = 0,
    this.availablePlayers = const [],
    this.gameId,
    this.playerColor,
    this.opponentName,
    this.chatMessages = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
    this.lastMovePromotion,
    this.gameResult,
    this.gameReason,
    this.lobbyNotice,
    this.challengerId,
  });

  MultiplayerState copyWith({
    MultiplayerStatus? status,
    int? onlineCount,
    int? searchingCount,
    List<OnlineLobbyUser>? availablePlayers,
    String? gameId,
    PieceColor? playerColor,
    String? opponentName,
    List<ChatMessage>? chatMessages,
    String? lastMoveFrom,
    String? lastMoveTo,
    String? lastMovePromotion,
    String? gameResult,
    String? gameReason,
    String? lobbyNotice,
    String? challengerId,
  }) {
    return MultiplayerState(
      status: status ?? this.status,
      onlineCount: onlineCount ?? this.onlineCount,
      searchingCount: searchingCount ?? this.searchingCount,
      availablePlayers: availablePlayers ?? this.availablePlayers,
      gameId: gameId ?? this.gameId,
      playerColor: playerColor ?? this.playerColor,
      opponentName: opponentName ?? this.opponentName,
      chatMessages: chatMessages ?? this.chatMessages,
      lastMoveFrom: lastMoveFrom ?? this.lastMoveFrom,
      lastMoveTo: lastMoveTo ?? this.lastMoveTo,
      lastMovePromotion: lastMovePromotion ?? this.lastMovePromotion,
      gameResult: gameResult ?? this.gameResult,
      gameReason: gameReason ?? this.gameReason,
      lobbyNotice: (lobbyNotice == null && challengerId == null) ? null : (lobbyNotice ?? this.lobbyNotice),
      challengerId: (lobbyNotice == null && challengerId == null) ? null : (challengerId ?? this.challengerId),
    );
  }

  @override List<Object?> get props => [
    status, onlineCount, searchingCount, availablePlayers.length, gameId, 
    playerColor, opponentName, chatMessages.length, lastMoveFrom, lastMoveTo, 
    gameResult, lobbyNotice, challengerId
  ];
}

// BLOC
class MultiplayerBloc extends Bloc<MultiplayerEvent, MultiplayerState> {
  final MultiplayerService _service;
  StreamSubscription? _lobbySub;
  StreamSubscription? _gameSub;
  String? _myUserId;

  MultiplayerBloc(this._service) : super(const MultiplayerState()) {
    on<MpConnectLobbyEvent>(_onConnectLobby);
    on<MpStartMatchmakingEvent>(_onMatchmaking);
    on<MpCancelMatchmakingEvent>(_onCancelMatchmaking);
    on<MpLobbyUpdateEvent>((event, emit) => emit(state.copyWith(
      onlineCount: event.online, 
      searchingCount: event.searching,
      availablePlayers: event.availablePlayers
    )));
    on<MpGameFoundEvent>(_onGameFound);
    on<MpMakeMoveEvent>(_onMakeMove);
    on<MpOpponentMoveEvent>(_onOpponentMove);
    on<MpSendChatEvent>(_onSendChat);
    on<MpChatReceivedEvent>(_onChatReceived);
    on<MpResignEvent>((event, emit) => _service.resign());
    on<MpSendChallengeEvent>((event, emit) {
      _service.sendChallenge(event.opponent.id, event.mode.name, event.timeControl);
      emit(state.copyWith(lobbyNotice: 'Challenge sent to ${event.opponent.name}!'));
    });
    on<MpDisconnectLobbyEvent>((event, emit) {
      _lobbySub?.cancel();
      _gameSub?.cancel();
      _service.dispose();
      emit(const MultiplayerState());
    });
    on<MpGameOverEvent>((event, emit) => emit(state.copyWith(status: MultiplayerStatus.gameOver, gameResult: event.result, gameReason: event.reason)));
    on<MpLobbyNoticeEvent>((event, emit) => emit(state.copyWith(lobbyNotice: event.message, challengerId: event.challengerId)));
    on<MpAcceptChallengeEvent>((event, emit) {
      _service.acceptChallenge(event.challengerId);
      emit(state.copyWith(lobbyNotice: null, challengerId: null));
    });
    on<MpClearNoticeEvent>((event, emit) => emit(state.copyWith(lobbyNotice: null, challengerId: null)));
  }

  Future<void> _onConnectLobby(MpConnectLobbyEvent event, Emitter<MultiplayerState> emit) async {
    _myUserId = event.userId;
    await _service.connectLobby(event.userId, event.username, rating: event.rating);
    _lobbySub?.cancel();
    _lobbySub = _service.lobbyUpdates.listen((msg) {
      if (msg['type'] == 'LOBBY_UPDATE') {
        // Handle optional player list if sent
        final list = (msg['data']['players'] as List?)
          ?.where((p) => p['id'] != _myUserId)
          .map((p) => OnlineLobbyUser(
            id: p['id'],
            name: p['name'],
            xp: p['rating'] ?? 0,
            isAvailable: p['status'] == 'idle',
            flair: p['status'] == 'searching' ? 'Searching...' : (p['status'] == 'idle' ? 'Ready!' : 'Playing'),
          )).toList() ?? [];
        add(MpLobbyUpdateEvent(msg['data']['onlinePlayers'], msg['data']['searchingPlayers'], list));
      } else if (msg['type'] == 'MATCH_FOUND') {
        add(MpGameFoundEvent(msg['data']['gameId'], msg['data']['color'], msg['data']['opponentName']));
      } else if (msg['type'] == 'CHALLENGE_RECEIVED') {
        final d = msg['data'];
        add(MpLobbyNoticeEvent(
          '${d['challengerName']} invited you to ${d['mode']} (${d['timeControl']})!',
          challengerId: d['challengerId']?.toString(),
        ));
      }
    });
    emit(state.copyWith(status: MultiplayerStatus.inLobby));
  }

  void _onMatchmaking(MpStartMatchmakingEvent event, Emitter<MultiplayerState> emit) {
    _service.findMatch();
    emit(state.copyWith(status: MultiplayerStatus.matchmaking));
  }

  void _onCancelMatchmaking(MpCancelMatchmakingEvent event, Emitter<MultiplayerState> emit) {
    _service.cancelFindMatch();
    emit(state.copyWith(status: MultiplayerStatus.inLobby));
  }

  Future<void> _onGameFound(MpGameFoundEvent event, Emitter<MultiplayerState> emit) async {
    await _service.joinRoom(event.gameId, event.color);
    _gameSub?.cancel();
    _gameSub = _service.gameUpdates.listen((msg) {
      switch (msg['type']) {
        case 'MOVE_UPDATE':
          add(MpOpponentMoveEvent(msg['data']));
          break;
        case 'CHAT':
          add(MpChatReceivedEvent(ChatMessage(
            userId: msg['data']['userId'],
            username: msg['data']['username'],
            message: '${msg['data']['message']} ${msg['data']['emoji'] ?? ''}',
            timestamp: DateTime.fromMillisecondsSinceEpoch(msg['data']['ts']),
            isMe: msg['data']['userId'] == _myUserId,
          )));
          break;
        case 'GAME_OVER':
          add(MpGameOverEvent(msg['data']['result'], msg['data']['reason']));
          break;
      }
    });
    emit(state.copyWith(
      status: MultiplayerStatus.inGame,
      gameId: event.gameId,
      playerColor: event.color == 'white' ? PieceColor.white : PieceColor.black,
      opponentName: event.opponentName,
    ));
  }

  void _onMakeMove(MpMakeMoveEvent event, Emitter<MultiplayerState> emit) {
    _service.sendMove({
      'from': event.from,
      'to': event.to,
      if (event.promotion != null) 'promotion': event.promotion,
    });
  }

  void _onOpponentMove(MpOpponentMoveEvent event, Emitter<MultiplayerState> emit) {
    emit(state.copyWith(
      lastMoveFrom: event.moveData['move']['from'],
      lastMoveTo: event.moveData['move']['to'],
      lastMovePromotion: event.moveData['move']['promotion'],
    ));
  }

  void _onSendChat(MpSendChatEvent event, Emitter<MultiplayerState> emit) {
    _service.sendChat(event.message, emoji: event.emoji);
  }

  void _onChatReceived(MpChatReceivedEvent event, Emitter<MultiplayerState> emit) {
    final history = List<ChatMessage>.from(state.chatMessages);
    history.add(event.message);
    emit(state.copyWith(chatMessages: history));
  }

  @override
  Future<void> close() {
    _lobbySub?.cancel();
    _gameSub?.cancel();
    _service.dispose();
    return super.close();
  }
}
