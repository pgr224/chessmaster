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
class MpDrawOfferEvent extends MultiplayerEvent {}
class MpDrawReceivedEvent extends MultiplayerEvent {}
class MpDrawAcceptEvent extends MultiplayerEvent {}
class MpDrawDeclineEvent extends MultiplayerEvent {}
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
  final bool drawOfferPending;

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
    this.drawOfferPending = false,
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
    bool? drawOfferPending,
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
      drawOfferPending: drawOfferPending ?? this.drawOfferPending,
    );
  }

  @override List<Object?> get props => [
    status, onlineCount, searchingCount, availablePlayers.length, gameId, 
    playerColor, opponentName, chatMessages.length, lastMoveFrom, lastMoveTo, 
    gameResult, lobbyNotice, challengerId, drawOfferPending
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
    on<MpDrawOfferEvent>((event, emit) {
      _service.sendDrawOffer();
      emit(state.copyWith(lobbyNotice: 'Draw offer sent...'));
    });
    on<MpDrawReceivedEvent>((event, emit) {
      emit(state.copyWith(drawOfferPending: true, lobbyNotice: 'Opponent offers a draw!'));
    });
    on<MpDrawAcceptEvent>((event, emit) {
      _service.sendDrawAccept();
      emit(state.copyWith(drawOfferPending: false));
    });
    on<MpDrawDeclineEvent>((event, emit) {
      _service.sendDrawDecline();
      emit(state.copyWith(drawOfferPending: false, lobbyNotice: 'Draw declined'));
    });
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
        final playersRaw = msg['data']['players'] as List?;
        final list = playersRaw
          ?.where((p) => (p as Map)['id'] != _myUserId)
          .map((p) {
            final player = p as Map;
            return OnlineLobbyUser(
              id: player['id']?.toString() ?? '',
              name: player['name']?.toString() ?? 'Unknown',
              xp: (player['rating'] is int) ? player['rating'] as int : int.tryParse(player['rating']?.toString() ?? '0') ?? 0,
              isAvailable: player['status'] == 'idle',
              flair: player['status'] == 'searching' ? 'Searching...' : (player['status'] == 'idle' ? 'Ready!' : 'Playing'),
            );
          }).toList() ?? <OnlineLobbyUser>[];
        add(MpLobbyUpdateEvent(
          msg['data']['onlinePlayers'] as int? ?? 0,
          msg['data']['searchingPlayers'] as int? ?? 0,
          list,
        ));
      } else if (msg['type'] == 'MATCH_FOUND') {
        final data = msg['data'] as Map;
        add(MpGameFoundEvent(
          data['gameId']?.toString() ?? '',
          data['color']?.toString() ?? 'white',
          data['opponentName']?.toString() ?? 'Unknown',
        ));
      } else if (msg['type'] == 'CHALLENGE_RECEIVED') {
        final d = msg['data'] as Map;
        add(MpLobbyNoticeEvent(
          '${d['challengerName']?.toString() ?? 'Someone'} invited you to ${d['mode']?.toString() ?? 'a game'} (${d['timeControl']?.toString() ?? '5+3'})!',
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
      final msgType = msg['type']?.toString();
      switch (msgType) {
        case 'MOVE_UPDATE':
          add(MpOpponentMoveEvent(msg['data'] as Map<String, dynamic>? ?? {}));
          break;
        case 'CHAT':
          final chatData = msg['data'] as Map?;
          if (chatData != null) {
            add(MpChatReceivedEvent(ChatMessage(
              userId: chatData['userId']?.toString() ?? '',
              username: chatData['username']?.toString() ?? 'Unknown',
              message: '${chatData['message']?.toString() ?? ''} ${chatData['emoji']?.toString() ?? ''}',
              timestamp: DateTime.fromMillisecondsSinceEpoch(chatData['ts'] as int? ?? DateTime.now().millisecondsSinceEpoch),
              isMe: chatData['userId']?.toString() == _myUserId,
            )));
          }
          break;
        case 'GAME_OVER':
          final gameOverData = msg['data'] as Map?;
          add(MpGameOverEvent(
            gameOverData?['result']?.toString() ?? 'draw',
            gameOverData?['reason']?.toString() ?? 'unknown',
          ));
          break;
        case 'DRAW_OFFER':
          add(MpDrawReceivedEvent());
          break;
        case 'DRAW_ACCEPT':
          add(MpGameOverEvent('draw', 'agreement'));
          break;
        case 'DRAW_DECLINE':
          add(MpClearNoticeEvent());
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
