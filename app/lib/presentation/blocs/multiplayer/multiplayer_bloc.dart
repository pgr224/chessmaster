import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/multiplayer_models.dart';
import '../../../data/models/xp_rules.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../../domain/engine/chess_engine.dart';

// RE-EXPORT MODELS
export '../../../data/models/multiplayer_models.dart';

// EVENTS
abstract class MultiplayerEvent extends Equatable {
  const MultiplayerEvent();
  @override
  List<Object?> get props => [];
}

class MpConnectLobbyEvent extends MultiplayerEvent {
  final String userId;
  final String username;
  final int rating;
  const MpConnectLobbyEvent(this.userId, this.username, {this.rating = 1200});
  @override
  List<Object?> get props => [userId, username, rating];
}

class MpStartMatchmakingEvent extends MultiplayerEvent {}

class MpCancelMatchmakingEvent extends MultiplayerEvent {}

class MpGameFoundEvent extends MultiplayerEvent {
  final String gameId;
  final PieceColor color;
  final String opponentName;
  final String? mode;
  final String? timeControl;
  final String? variantId;
  final String? opponentAvatarUrl;
  final String? opponentLocalAvatar;

  const MpGameFoundEvent(
    this.gameId,
    this.color,
    this.opponentName, {
    this.mode,
    this.timeControl,
    this.variantId,
    this.opponentAvatarUrl,
    this.opponentLocalAvatar,
  });
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
  final int? xpDelta;
  const MpGameOverEvent(this.result, this.reason, {this.xpDelta});

  @override
  List<Object?> get props => [result, reason, xpDelta];
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
  final String variantId;
  const MpSendChallengeEvent(
      {
      required this.opponent,
      required this.mode,
      required this.timeControl,
      required this.variantId,
      });
  @override
  List<Object?> get props => [opponent, mode, timeControl, variantId];
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
  final String? mode;
  final String? timeControl;
  final String? variantId;
  const MpLobbyNoticeEvent(this.message,
      {this.challengerId, this.mode, this.timeControl, this.variantId});
}

class MpUndoEvent extends MultiplayerEvent {}

class MpOpponentUndoEvent extends MultiplayerEvent {}

class MpDisconnectLobbyEvent extends MultiplayerEvent {}

class MpReconnectEvent extends MultiplayerEvent {}

class MpSaveRequestEvent extends MultiplayerEvent {}

class MpSaveAcceptEvent extends MultiplayerEvent {}

class MpSaveDeclineEvent extends MultiplayerEvent {}

class MpGameSavedEvent extends MultiplayerEvent {}

class MpChangeSelectedTimeEvent extends MultiplayerEvent {
  final String timeControl;
  const MpChangeSelectedTimeEvent(this.timeControl);
}

class MpChangeSelectedVariantEvent extends MultiplayerEvent {
  final String variantId;
  const MpChangeSelectedVariantEvent(this.variantId);
}

class MpXpBroadcastRequestEvent extends MultiplayerEvent {
  final String userId;
  final String username;
  final int amount;
  const MpXpBroadcastRequestEvent(this.userId, this.username, this.amount);
}

class MpSendXpBroadcastEvent extends MultiplayerEvent {
  final int amount;
  const MpSendXpBroadcastEvent(this.amount);
}

class MpSetXpBroadcastRequestsEvent extends MultiplayerEvent {
  final List<Map<String, dynamic>> requests;
  const MpSetXpBroadcastRequestsEvent(this.requests);
}

class MpSendTournamentInviteEvent extends MultiplayerEvent {
  final OnlineLobbyUser opponent;
  final String tournamentId;
  final int totalRounds;
  final String timeControl;
  const MpSendTournamentInviteEvent({
    required this.opponent,
    required this.tournamentId,
    required this.totalRounds,
    required this.timeControl,
  });
  @override
  List<Object?> get props => [opponent, tournamentId, totalRounds, timeControl];
}

class MpTournamentChallengeReceivedEvent extends MultiplayerEvent {
  final String challengerId;
  final String challengerName;
  final String tournamentId;
  final int totalRounds;
  final String timeControl;
  const MpTournamentChallengeReceivedEvent({
    required this.challengerId,
    required this.challengerName,
    required this.tournamentId,
    required this.totalRounds,
    required this.timeControl,
  });
  @override
  List<Object?> get props =>
      [challengerId, challengerName, tournamentId, totalRounds, timeControl];
}

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
  final String? mode;
  final String? timeControl;
  final String? variantId;
  final List<ChatMessage> chatMessages;
  final String? lastMoveFrom;
  final String? lastMoveTo;
  final String? lastMovePromotion;
  final String? gameResult;
  final String? gameReason;
  final String? challengerTimeControl;
  final String selectedVariantId;
  final String? challengerVariantId;
  final String? opponentAvatarUrl;
  final String? opponentLocalAvatar;
  final String selectedTimeControl;
  final bool drawOfferPending;
  final bool saveOfferPending;
  final String? connectionError;
  final double whiteTime;
  final double blackTime;
  final int xpGained;
  final int opponentUndoCount;
  final List<Map<String, dynamic>> xpBroadcastRequests;
  final String? lobbyNotice;
  final String? challengerId;
  final String? challengerMode;
  // Tournament challenge fields
  final String? pendingTournamentId;
  final String? pendingTournamentChallengerId;
  final String? pendingTournamentChallengerName;
  final int pendingTournamentRounds;
  final String? pendingTournamentTimeControl;

  const MultiplayerState({
    this.status = MultiplayerStatus.disconnected,
    this.onlineCount = 0,
    this.searchingCount = 0,
    this.availablePlayers = const [],
    this.gameId,
    this.playerColor,
    this.opponentName,
    this.mode,
    this.timeControl,
    this.variantId,
    this.chatMessages = const [],
    this.lastMoveFrom,
    this.lastMoveTo,
    this.lastMovePromotion,
    this.gameResult,
    this.gameReason,
    this.lobbyNotice,
    this.challengerId,
    this.challengerMode,
    this.challengerTimeControl,
    this.selectedVariantId = 'standard',
    this.challengerVariantId,
    this.selectedTimeControl = '30+0',
    this.drawOfferPending = false,
    this.saveOfferPending = false,
    this.connectionError,
    this.whiteTime = 0,
    this.blackTime = 0,
    this.xpGained = 0,
    this.opponentUndoCount = 0,
    this.xpBroadcastRequests = const [],
    this.opponentAvatarUrl,
    this.opponentLocalAvatar,
    this.pendingTournamentId,
    this.pendingTournamentChallengerId,
    this.pendingTournamentChallengerName,
    this.pendingTournamentRounds = 3,
    this.pendingTournamentTimeControl,
  });

  MultiplayerState copyWith({
    MultiplayerStatus? status,
    int? onlineCount,
    int? searchingCount,
    List<OnlineLobbyUser>? availablePlayers,
    String? gameId,
    PieceColor? playerColor,
    String? opponentName,
    String? mode,
    String? timeControl,
    String? variantId,
    List<ChatMessage>? chatMessages,
    String? lastMoveFrom,
    String? lastMoveTo,
    String? lastMovePromotion,
    String? gameResult,
    String? gameReason,
    String? lobbyNotice,
    String? challengerId,
    String? challengerMode,
    String? challengerTimeControl,
    String? selectedVariantId,
    String? challengerVariantId,
    String? selectedTimeControl,
    bool? drawOfferPending,
    bool? saveOfferPending,
    String? connectionError,
    double? whiteTime,
    double? blackTime,
    int? xpGained,
    int? opponentUndoCount,
    List<Map<String, dynamic>>? xpBroadcastRequests,
    String? opponentAvatarUrl,
    String? opponentLocalAvatar,
    String? pendingTournamentId,
    String? pendingTournamentChallengerId,
    String? pendingTournamentChallengerName,
    int? pendingTournamentRounds,
    String? pendingTournamentTimeControl,
  }) {
    return MultiplayerState(
      status: status ?? this.status,
      onlineCount: onlineCount ?? this.onlineCount,
      searchingCount: searchingCount ?? this.searchingCount,
      availablePlayers: availablePlayers ?? this.availablePlayers,
      gameId: gameId ?? this.gameId,
      playerColor: playerColor ?? this.playerColor,
      opponentName: opponentName ?? this.opponentName,
      mode: mode ?? this.mode,
      timeControl: timeControl ?? this.timeControl,
      variantId: variantId ?? this.variantId,
      chatMessages: chatMessages ?? this.chatMessages,
      lastMoveFrom: lastMoveFrom ?? this.lastMoveFrom,
      lastMoveTo: lastMoveTo ?? this.lastMoveTo,
      lastMovePromotion: lastMovePromotion ?? this.lastMovePromotion,
      gameResult: gameResult ?? this.gameResult,
      gameReason: gameReason ?? this.gameReason,
      lobbyNotice: (lobbyNotice == null && challengerId == null)
          ? null
          : (lobbyNotice ?? this.lobbyNotice),
      challengerId: (lobbyNotice == null && challengerId == null)
          ? null
          : (challengerId ?? this.challengerId),
      challengerMode: challengerMode ?? this.challengerMode,
      challengerTimeControl:
          challengerTimeControl ?? this.challengerTimeControl,
        selectedVariantId: selectedVariantId ?? this.selectedVariantId,
        challengerVariantId: challengerVariantId ?? this.challengerVariantId,
      selectedTimeControl: selectedTimeControl ?? this.selectedTimeControl,
      drawOfferPending: drawOfferPending ?? this.drawOfferPending,
      saveOfferPending: saveOfferPending ?? this.saveOfferPending,
      connectionError: connectionError ?? this.connectionError,
      whiteTime: whiteTime ?? this.whiteTime,
      blackTime: blackTime ?? this.blackTime,
      xpGained: xpGained ?? this.xpGained,
      opponentUndoCount: opponentUndoCount ?? this.opponentUndoCount,
      xpBroadcastRequests: xpBroadcastRequests ?? this.xpBroadcastRequests,
      opponentAvatarUrl: opponentAvatarUrl ?? this.opponentAvatarUrl,
      opponentLocalAvatar: opponentLocalAvatar ?? this.opponentLocalAvatar,
      pendingTournamentId: pendingTournamentId ?? this.pendingTournamentId,
      pendingTournamentChallengerId:
          pendingTournamentChallengerId ?? this.pendingTournamentChallengerId,
      pendingTournamentChallengerName: pendingTournamentChallengerName ??
          this.pendingTournamentChallengerName,
      pendingTournamentRounds:
          pendingTournamentRounds ?? this.pendingTournamentRounds,
      pendingTournamentTimeControl:
          pendingTournamentTimeControl ?? this.pendingTournamentTimeControl,
    );
  }

  @override
  List<Object?> get props => [
        status,
        onlineCount,
        searchingCount,
        availablePlayers.length,
        gameId,
        playerColor,
        opponentName,
        chatMessages.length,
        lastMoveFrom,
        lastMoveTo,
        gameResult,
        variantId,
        selectedTimeControl,
        lobbyNotice,
        challengerId,
        challengerVariantId,
        selectedVariantId,
        drawOfferPending,
        saveOfferPending,
        connectionError,
        whiteTime,
        blackTime,
        xpGained,
        opponentUndoCount,
        opponentAvatarUrl,
        opponentLocalAvatar
      ];
}

class MpTimerSyncEvent extends MultiplayerEvent {
  final double whiteTime;
  final double blackTime;
  const MpTimerSyncEvent(this.whiteTime, this.blackTime);
}

// BLOC
class MultiplayerBloc extends Bloc<MultiplayerEvent, MultiplayerState> {
  final MultiplayerService _service;
  StreamSubscription? _lobbySub;
  StreamSubscription? _gameSub;
  String? _myUserId;

  /// Exposed so screens can call service methods not wrapped in events.
  MultiplayerService get mpService => _service;

  MultiplayerBloc(this._service) : super(const MultiplayerState()) {
    on<MpConnectLobbyEvent>(_onConnectLobby);
    on<MpReconnectEvent>((event, emit) {
      if (_service.isLobbyConnected) return;
      // Reconnect will be triggered by MpConnectLobbyEvent from the UI
      emit(state.copyWith(connectionError: 'Reconnecting...'));
    });
    on<MpDrawReceivedEvent>(
        (event, emit) => emit(state.copyWith(drawOfferPending: true)));
    on<MpStartMatchmakingEvent>(_onMatchmaking);
    on<MpCancelMatchmakingEvent>(_onCancelMatchmaking);
    on<MpLobbyUpdateEvent>((event, emit) => emit(state.copyWith(
        onlineCount: event.online,
        searchingCount: event.searching,
        availablePlayers: event.availablePlayers)));
    on<MpGameFoundEvent>(_onGameFound);
    on<MpMakeMoveEvent>(_onMakeMove);
    on<MpOpponentMoveEvent>(_onOpponentMove);
    on<MpUndoEvent>((event, emit) => _service.sendUndo());
    on<MpOpponentUndoEvent>((event, emit) => emit(state.copyWith(
          opponentUndoCount: state.opponentUndoCount + 1,
        )));
    on<MpSendChatEvent>(_onSendChat);
    on<MpChatReceivedEvent>(_onChatReceived);
    on<MpResignEvent>((event, emit) => _service.resign());
    on<MpDrawOfferEvent>((event, emit) => _service.sendDrawOffer());
    on<MpDrawAcceptEvent>((event, emit) => _service.sendDrawAccept());
    on<MpDrawDeclineEvent>((event, emit) => _service.sendDrawDecline());

    on<MpTimerSyncEvent>((event, emit) => emit(state.copyWith(
        whiteTime: event.whiteTime, blackTime: event.blackTime)));

    // Save & Quit
    on<MpSaveRequestEvent>((event, emit) => _service.sendSaveRequest());
    on<MpSaveAcceptEvent>((event, emit) => _service.sendSaveAccept());
    on<MpSaveDeclineEvent>((event, emit) => _service.sendSaveDecline());
    on<MpGameSavedEvent>((event, emit) => emit(state.copyWith(
        status: MultiplayerStatus.gameOver, gameReason: 'manual_save')));

    on<MpSendChallengeEvent>((event, emit) {
      _service.sendChallenge(
        event.opponent.id, event.mode.name, event.timeControl, event.variantId);
      emit(state.copyWith(
          lobbyNotice: 'Challenge sent to ${event.opponent.name}!'));
    });
    on<MpDisconnectLobbyEvent>((event, emit) {
      _lobbySub?.cancel();
      _gameSub?.cancel();
      _service.dispose();
      emit(const MultiplayerState());
    });
    on<MpGameOverEvent>((event, emit) {
      final normalizedResult = _normalizeGameResult(event.result);

      final isWin = normalizedResult == 'win' ||
          (normalizedResult == 'white' &&
              state.playerColor == PieceColor.white) ||
          (normalizedResult == 'black' && state.playerColor == PieceColor.black);
      final isLoss = normalizedResult == 'loss' ||
          (normalizedResult == 'white' &&
              state.playerColor == PieceColor.black) ||
          (normalizedResult == 'black' && state.playerColor == PieceColor.white);
      final isDraw = normalizedResult == 'draw';

      final xp = event.xpDelta ??
          (isWin
              ? calculateMultiplayerXP('win')
              : (isLoss
                  ? calculateMultiplayerXP('loss')
                  : (isDraw ? calculateMultiplayerXP('draw') : 0)));

      emit(state.copyWith(
        status: MultiplayerStatus.gameOver,
        gameResult: normalizedResult,
        gameReason: event.reason,
        xpGained: xp,
      ));
    });
    on<MpLobbyNoticeEvent>((event, emit) => emit(state.copyWith(
          lobbyNotice: event.message,
          challengerId: event.challengerId,
          challengerMode: event.mode,
          challengerTimeControl: event.timeControl,
          challengerVariantId: event.variantId,
        )));
    on<MpAcceptChallengeEvent>((event, emit) {
      if (state.challengerId != null) {
        _service.acceptChallenge(
            state.challengerId!,
            state.challengerMode ?? 'duel',
            state.challengerTimeControl ?? '10+0',
            state.challengerVariantId ?? 'standard');
      } else {
        _service.acceptChallenge(event.challengerId, 'duel', '10+0', 'standard');
      }
      emit(state.copyWith(
        lobbyNotice: null,
        challengerId: null,
        challengerVariantId: '',
      ));
    });
    on<MpChangeSelectedTimeEvent>((event, emit) =>
        emit(state.copyWith(selectedTimeControl: event.timeControl)));
    on<MpChangeSelectedVariantEvent>((event, emit) =>
        emit(state.copyWith(selectedVariantId: event.variantId)));
    on<MpClearNoticeEvent>((event, emit) => emit(state.copyWith(
        lobbyNotice: null,
        challengerId: null,
        challengerVariantId: '',
      )));

    on<MpXpBroadcastRequestEvent>((event, emit) {
      final requests =
          List<Map<String, dynamic>>.from(state.xpBroadcastRequests);
      requests.add({
        'userId': event.userId,
        'username': event.username,
        'amount': event.amount,
        'ts': DateTime.now().millisecondsSinceEpoch,
      });
      emit(state.copyWith(xpBroadcastRequests: requests));
    });

    on<MpSendTournamentInviteEvent>((event, emit) {
      _service.sendTournamentChallenge(
        opponentId: event.opponent.id,
        tournamentId: event.tournamentId,
        totalRounds: event.totalRounds,
        timeControl: event.timeControl,
      );
      emit(state.copyWith(
          lobbyNotice: '🏆 Tournament invite sent to ${event.opponent.name}!'));
    });
    on<MpTournamentChallengeReceivedEvent>((event, emit) {
      emit(state.copyWith(
        pendingTournamentId: event.tournamentId,
        pendingTournamentChallengerId: event.challengerId,
        pendingTournamentChallengerName: event.challengerName,
        pendingTournamentRounds: event.totalRounds,
        pendingTournamentTimeControl: event.timeControl,
        lobbyNotice:
            '🏆 ${event.challengerName} invited you to a ${event.totalRounds}-round tournament!',
      ));
    });
    on<MpSendXpBroadcastEvent>((event, emit) {
      _service.sendXpBroadcast(event.amount);
    });
    on<MpSetXpBroadcastRequestsEvent>((event, emit) {
      emit(state.copyWith(xpBroadcastRequests: event.requests));
    });
    // MpTimerSyncEvent already registered above at line ~287
  }

  Future<void> _onConnectLobby(
      MpConnectLobbyEvent event, Emitter<MultiplayerState> emit) async {
    _myUserId = event.userId;
    await _service.connectLobby(event.userId, event.username,
        rating: event.rating);
    _lobbySub?.cancel();
    _lobbySub = _service.lobbyUpdates.listen((msg) {
      final msgType = msg['type']?.toString();
      final data = _asMap(msg['data']);

      if (msgType == 'LOBBY_UPDATE') {
        final playersRaw = (data['players'] is List) ? data['players'] as List : null;
        final list = playersRaw
                ?.whereType<Map>()
                .where((player) => player['id']?.toString() != _myUserId)
                .map((player) {
                  return OnlineLobbyUser(
                    id: player['id']?.toString() ?? '',
                    name: player['name']?.toString() ?? 'Unknown',
                    xp: (player['rating'] is int)
                        ? player['rating'] as int
                        : int.tryParse(player['rating']?.toString() ?? '0') ??
                            1200,
                    isAvailable: player['status'] == 'idle',
                    flair: player['status'] == 'searching'
                        ? 'Searching...'
                        : (player['status'] == 'idle' ? 'Ready!' : 'Playing'),
                  );
                }).toList() ??
              <OnlineLobbyUser>[];
        add(MpLobbyUpdateEvent(
          _toInt(data['onlinePlayers']),
          _toInt(data['searchingPlayers']),
          list,
        ));
      } else if (msgType == 'MATCH_FOUND') {
        add(MpGameFoundEvent(
          data['gameId']?.toString() ?? '',
          (data['color']?.toString() == 'black')
              ? PieceColor.black
              : PieceColor.white,
          data['opponentName']?.toString() ?? 'Unknown',
          mode: data['mode']?.toString(),
          timeControl: data['timeControl']?.toString(),
          variantId: data['variantId']?.toString() ?? data['variant']?.toString(),
          opponentAvatarUrl: data['opponentAvatarUrl']?.toString(),
          opponentLocalAvatar: data['opponentLocalAvatar']?.toString(),
        ));
      } else if (msgType == 'CHALLENGE_RECEIVED') {
        final d = data;
        add(MpLobbyNoticeEvent(
          '${d['challengerName']?.toString() ?? 'Someone'} invited you to ${d['mode']?.toString() ?? 'a game'} (${d['timeControl']?.toString() ?? '5+0'}) • ${(d['variantId']?.toString() ?? d['variant']?.toString() ?? 'standard')}',
          challengerId: d['challengerId']?.toString(),
          mode: d['mode']?.toString(),
          timeControl: d['timeControl']?.toString(),
          variantId: d['variantId']?.toString() ?? d['variant']?.toString(),
        ));
      } else if (msgType == 'TOURNAMENT_CHALLENGE_RECEIVED') {
        final d = data;
        add(MpTournamentChallengeReceivedEvent(
          challengerId: d['challengerId']?.toString() ?? '',
          challengerName: d['challengerName']?.toString() ?? 'Someone',
          tournamentId: d['tournamentId']?.toString() ?? '',
          totalRounds: _toInt(d['totalRounds'], fallback: 3),
          timeControl: d['timeControl']?.toString() ?? '10+0',
        ));
      } else if (msgType == 'XP_BROADCAST') {
        final d = data;
        add(MpXpBroadcastRequestEvent(
          d['userId']?.toString() ?? '',
          d['username']?.toString() ?? 'Someone',
          _toInt(d['amount']),
        ));
      } else if (msgType == 'CONNECTION_LOST') {
        add(MpLobbyNoticeEvent('Connection lost. Please check your internet.'));
      }
    }, onError: (err) {
      add(MpLobbyNoticeEvent('Network error: ${err.toString()}'));
    }, onDone: () {
      add(MpLobbyNoticeEvent('Disconnected from lobby.'));
    });
    emit(state.copyWith(
        status: MultiplayerStatus.inLobby, connectionError: null));
  }

  void _onMatchmaking(
      MpStartMatchmakingEvent event, Emitter<MultiplayerState> emit) {
    _service.findMatch(
      timeControl: state.selectedTimeControl,
      variantId: state.selectedVariantId,
    );
    emit(state.copyWith(status: MultiplayerStatus.matchmaking));
  }

  void _onCancelMatchmaking(
      MpCancelMatchmakingEvent event, Emitter<MultiplayerState> emit) {
    _service.cancelFindMatch();
    emit(state.copyWith(status: MultiplayerStatus.inLobby));
  }

  Future<void> _onGameFound(
      MpGameFoundEvent event, Emitter<MultiplayerState> emit) async {
    await _service.joinRoom(
      event.gameId,
      event.color.name,
      timeControl: event.timeControl ?? state.selectedTimeControl,
      variantId: event.variantId ?? state.selectedVariantId,
    );
    _gameSub?.cancel();
    _gameSub = _service.gameUpdates.listen((msg) {
      final msgType = msg['type']?.toString();
      final data = _asMap(msg['data']);
      switch (msgType) {
        case 'MOVE_UPDATE':
          if (data['undo'] == true) {
            add(MpOpponentUndoEvent());
          } else {
            final senderId = data['userId']?.toString();
            if (senderId != null && senderId == _myUserId) {
              break;
            }
            add(MpOpponentMoveEvent(data));
            // Update timers immediately from move update to prevent visual skip
            if (data['whiteTime'] != null) {
              add(MpTimerSyncEvent(
                _toDouble(data['whiteTime']),
                _toDouble(data['blackTime']),
              ));
            }
          }
          break;
        case 'TIMER_SYNC':
          add(MpTimerSyncEvent(
            _toDouble(data['whiteTime']),
            _toDouble(data['blackTime']),
          ));
          break;
        case 'CHAT':
          final chatData = data;
          add(MpChatReceivedEvent(ChatMessage(
            userId: chatData['userId']?.toString() ?? '',
            username: chatData['username']?.toString() ?? 'Unknown',
            message:
                '${chatData['message']?.toString() ?? ''} ${chatData['emoji']?.toString() ?? ''}',
            timestamp: DateTime.fromMillisecondsSinceEpoch(
                _toInt(chatData['ts'],
                    fallback: DateTime.now().millisecondsSinceEpoch)),
            isMe: chatData['userId']?.toString() == _myUserId,
          )));
          break;
        case 'GAME_OVER':
          final gameOverData = data;
          add(MpGameOverEvent(
            gameOverData['result']?.toString() ?? 'draw',
            gameOverData['reason']?.toString() ?? 'unknown',
            xpDelta: _toIntOrNull(gameOverData['xpDelta']) ??
                _toIntOrNull(gameOverData['xp']) ??
                _toIntOrNull(gameOverData['xpChange']),
          ));
          break;
        case 'DRAW_OFFER':
          add(MpDrawReceivedEvent());
          break;
        case 'DRAW_ACCEPT':
          add(MpGameOverEvent('draw', 'agreement'));
          break;
        case 'DRAW_DECLINE':
          emit(state.copyWith(drawOfferPending: false));
          break;
        case 'SAVE_REQUEST':
          emit(state.copyWith(saveOfferPending: true));
          break;
        case 'SAVE_DECLINE':
          emit(state.copyWith(saveOfferPending: false));
          break;
        case 'GAME_SAVED':
          add(MpGameSavedEvent());
          break;
      }
    });
    emit(state.copyWith(
      status: MultiplayerStatus.inGame,
      gameId: event.gameId,
      playerColor: event.color,
      opponentName: event.opponentName,
      opponentAvatarUrl: event.opponentAvatarUrl,
      opponentLocalAvatar: event.opponentLocalAvatar,
      mode: event.mode,
      timeControl: event.timeControl,
      variantId: event.variantId,
    ));
  }

  void _onMakeMove(MpMakeMoveEvent event, Emitter<MultiplayerState> emit) {
    _service.sendMove({
      'from': event.from,
      'to': event.to,
      if (event.promotion != null) 'promotion': event.promotion,
    });
  }

  void _onOpponentMove(
      MpOpponentMoveEvent event, Emitter<MultiplayerState> emit) {
    emit(state.copyWith(
      lastMoveFrom: event.moveData['move']['from'],
      lastMoveTo: event.moveData['move']['to'],
      lastMovePromotion: event.moveData['move']['promotion'],
    ));
  }

  void _onSendChat(MpSendChatEvent event, Emitter<MultiplayerState> emit) {
    _service.sendChat(event.message, emoji: event.emoji);
  }

  void _onChatReceived(
      MpChatReceivedEvent event, Emitter<MultiplayerState> emit) {
    final history = List<ChatMessage>.from(state.chatMessages);
    // On the backend, data includes userId
    // Ensure we tag correctly for the UI
    final msg = ChatMessage(
      userId: event.message.userId,
      username: event.message.username,
      message: event.message.message,
      timestamp: event.message.timestamp,
      isMe: event.message.userId == _myUserId,
    );
    history.add(msg);
    emit(state.copyWith(chatMessages: history));
  }

  @override
  Future<void> close() {
    _lobbySub?.cancel();
    _gameSub?.cancel();
    _service.dispose();
    return super.close();
  }

  Map<String, dynamic> _asMap(dynamic value) {
    if (value is Map<String, dynamic>) return value;
    if (value is Map) {
      return value.map((k, v) => MapEntry(k.toString(), v));
    }
    return const <String, dynamic>{};
  }

  int _toInt(dynamic value, {int fallback = 0}) {
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value?.toString() ?? '') ?? fallback;
  }

  double _toDouble(dynamic value, {double fallback = 0}) {
    if (value is double) return value;
    if (value is num) return value.toDouble();
    return double.tryParse(value?.toString() ?? '') ?? fallback;
  }

  int? _toIntOrNull(dynamic value) {
    if (value == null) return null;
    if (value is int) return value;
    if (value is num) return value.toInt();
    return int.tryParse(value.toString());
  }

  String _normalizeGameResult(String rawResult) {
    final value = rawResult.trim().toLowerCase();
    if (value == 'white' || value == 'black' || value == 'draw') {
      return value;
    }
    if (value == 'win' || value == 'won' || value == 'victory') {
      return 'win';
    }
    if (value == 'loss' || value == 'lose' || value == 'lost' || value == 'defeat') {
      return 'loss';
    }
    if (value == 'tie') {
      return 'draw';
    }
    return value;
  }
}
