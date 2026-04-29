import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../auth/auth_bloc.dart';
import '../../../data/models/multiplayer_models.dart';
import '../../../data/models/xp_rules.dart';
import '../../../data/services/multiplayer_service.dart';
import '../../../domain/engine/chess_engine.dart';

// RE-EXPORT MODELS
export '../../../data/models/multiplayer_models.dart';

/// Normalize promotion piece code to single lowercase letter (matches backend logic)
String? normalizePromotionCode(String? code) {
  if (code == null || code.isEmpty) return null;
  final value = code.toLowerCase();
  if (value == 'q' || value == 'queen') return 'q';
  if (value == 'r' || value == 'rook') return 'r';
  if (value == 'b' || value == 'bishop') return 'b';
  if (value == 'n' || value == 'knight') return 'n';
  return null;
}

// EVENTS
abstract class MultiplayerEvent extends Equatable {
  const MultiplayerEvent();
  @override
  List<Object?> get props => [];
}

class MpOpponentJoinedEvent extends MultiplayerEvent {}

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
  final String? requestId;

  const MpGameFoundEvent(
    this.gameId,
    this.color,
    this.opponentName, {
    this.mode,
    this.timeControl,
    this.variantId,
    this.opponentAvatarUrl,
    this.opponentLocalAvatar,
    this.requestId,
  });

  @override
  List<Object?> get props =>
      [
        gameId,
        color,
        opponentName,
        mode,
        timeControl,
        variantId,
        opponentAvatarUrl,
        opponentLocalAvatar,
        requestId,
      ];
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
  final bool allowOffline;
  const MpSendChallengeEvent(
      {
      required this.opponent,
      required this.mode,
      required this.timeControl,
      required this.variantId,
      this.allowOffline = false,
      });
  @override
  List<Object?> get props =>
      [opponent, mode, timeControl, variantId, allowOffline];
}

class MpAcceptChallengeEvent extends MultiplayerEvent {
  final String challengerId;
  final String? requestId;
  final String? mode;
  final String? timeControl;
  final String? variantId;
  final bool isQueued;
  const MpAcceptChallengeEvent(
    this.challengerId, {
    this.requestId,
    this.mode,
    this.timeControl,
    this.variantId,
    this.isQueued = false,
  });

  @override
  List<Object?> get props =>
      [challengerId, requestId, mode, timeControl, variantId, isQueued];
}

class MpDeclineChallengeEvent extends MultiplayerEvent {
  final String challengerId;
  final String? requestId;
  const MpDeclineChallengeEvent(this.challengerId, {this.requestId});

  @override
  List<Object?> get props => [challengerId, requestId];
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

class MpSetPresenceEvent extends MultiplayerEvent {
  final String presence;
  final String? gameId;
  final String? context;
  const MpSetPresenceEvent(this.presence, {this.gameId, this.context});

  @override
  List<Object?> get props => [presence, gameId, context];
}

class MpIncomingChallengeReceivedEvent extends MultiplayerEvent {
  final ChallengeRequest request;
  const MpIncomingChallengeReceivedEvent(this.request);

  @override
  List<Object?> get props => [request];
}

class MpOutgoingChallengeTrackedEvent extends MultiplayerEvent {
  final ChallengeRequest request;
  const MpOutgoingChallengeTrackedEvent(this.request);

  @override
  List<Object?> get props => [request];
}

class MpResolveChallengeEvent extends MultiplayerEvent {
  final String requestId;
  final bool isIncoming;
  final String status;
  final String? notice;
  const MpResolveChallengeEvent({
    required this.requestId,
    required this.isIncoming,
    required this.status,
    this.notice,
  });

  @override
  List<Object?> get props => [requestId, isIncoming, status, notice];
}

class MpSaveRequestEvent extends MultiplayerEvent {}

class MpSaveAcceptEvent extends MultiplayerEvent {}

class MpSaveDeclineEvent extends MultiplayerEvent {}

class MpGameSavedEvent extends MultiplayerEvent {}

class MpLeaveGameEvent extends MultiplayerEvent {
  const MpLeaveGameEvent();
}

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

class MpXpTransferUpdateEvent extends MultiplayerEvent {
  final String donorId;
  final String donorName;
  final int donorXp;
  final String recipientId;
  final String recipientName;
  final int recipientXp;
  final int amount;

  const MpXpTransferUpdateEvent({
    required this.donorId,
    required this.donorName,
    required this.donorXp,
    required this.recipientId,
    required this.recipientName,
    required this.recipientXp,
    required this.amount,
  });

  @override
  List<Object?> get props => [
        donorId,
        donorName,
        donorXp,
        recipientId,
        recipientName,
        recipientXp,
        amount,
      ];
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
  final List<ChallengeRequest> incomingChallenges;
  final List<ChallengeRequest> outgoingChallenges;
  final String myPresence;
  final String? lobbyNotice;
  final String? challengerId;
  final String? challengerMode;
  // Tournament challenge fields
  final String? pendingTournamentId;
  final String? pendingTournamentChallengerId;
  final String? pendingTournamentChallengerName;
  final int pendingTournamentRounds;
  final String? pendingTournamentTimeControl;
  final bool opponentConnected;

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
    this.incomingChallenges = const [],
    this.outgoingChallenges = const [],
    this.myPresence = LobbyPresence.online,
    this.opponentAvatarUrl,
    this.opponentLocalAvatar,
    this.pendingTournamentId,
    this.pendingTournamentChallengerId,
    this.pendingTournamentChallengerName,
    this.pendingTournamentRounds = 3,
    this.pendingTournamentTimeControl,
    this.opponentConnected = false,
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
    List<ChallengeRequest>? incomingChallenges,
    List<ChallengeRequest>? outgoingChallenges,
    String? myPresence,
    String? opponentAvatarUrl,
    String? opponentLocalAvatar,
    String? pendingTournamentId,
    String? pendingTournamentChallengerId,
    String? pendingTournamentChallengerName,
    int? pendingTournamentRounds,
    String? pendingTournamentTimeControl,
    bool? opponentConnected,
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
      incomingChallenges: incomingChallenges ?? this.incomingChallenges,
      outgoingChallenges: outgoingChallenges ?? this.outgoingChallenges,
      myPresence: myPresence ?? this.myPresence,
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
      opponentConnected: opponentConnected ?? this.opponentConnected,
    );
  }

  @override
  List<Object?> get props => [
        status,
        onlineCount,
        searchingCount,
        availablePlayers,
        gameId,
        playerColor,
        opponentName,
        chatMessages,
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
        incomingChallenges,
        outgoingChallenges,
        myPresence,
        opponentAvatarUrl,
        opponentLocalAvatar,
        opponentConnected,
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
  final AuthBloc _authBloc;
  StreamSubscription? _lobbySub;
  StreamSubscription? _gameSub;
  String? _myUserId;
  Timer? _joinTimer;
  Timer? _reconnectTimer;

  /// Exposed so screens can call service methods not wrapped in events.
  MultiplayerService get mpService => _service;

  MultiplayerBloc(this._service, this._authBloc) : super(const MultiplayerState()) {
    on<MpConnectLobbyEvent>(_onConnectLobby);
    on<MpReconnectEvent>((event, emit) {
      if (_service.isLobbyConnected) return;
      
      final authState = _authBloc.state;
      if (authState is AuthAuthenticatedState) {
        add(MpConnectLobbyEvent(
          authState.user.id,
          authState.user.username,
          rating: authState.user.stats.eloRating,
        ));
      } else {
        emit(state.copyWith(connectionError: 'Unable to reconnect: User not authenticated'));
      }
    });
    on<MpDrawReceivedEvent>(
        (event, emit) => emit(state.copyWith(drawOfferPending: true)));
    on<MpSetPresenceEvent>(_onSetPresence);
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
    on<MpOpponentJoinedEvent>((event, emit) {
      _joinTimer?.cancel();
      emit(state.copyWith(opponentConnected: true));
    });
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

    on<MpLeaveGameEvent>((event, emit) {
      _service.disconnectGame();
      _gameSub?.cancel();
      emit(state.copyWith(
        status: MultiplayerStatus.inLobby,
        gameId: null,
        playerColor: null,
        opponentName: null,
        opponentConnected: false,
        myPresence: LobbyPresence.online,
      ));
    });

    on<MpSendChallengeEvent>((event, emit) {
      // Cancel any existing outgoing challenge to the same player
      final existingOutgoings = state.outgoingChallenges
          .where((r) => r.playerId == event.opponent.id && (r.status == 'pending' || r.status == 'queued'));
      ChallengeRequest? existingOutgoing;
      if (existingOutgoings.isNotEmpty) {
        existingOutgoing = existingOutgoings.first;
        _service.declineChallenge(existingOutgoing.playerId, requestId: existingOutgoing.id);
      }
      final updatedOutgoingChallenges = existingOutgoing != null
          ? _markChallengeResolved(state.outgoingChallenges, existingOutgoing.id, 'cancelled')
          : state.outgoingChallenges;

      final request = ChallengeRequest(
        id: _buildChallengeRequestId(event.opponent.id),
        playerId: event.opponent.id,
        playerName: event.opponent.name,
        mode: event.mode.name,
        timeControl: event.timeControl,
        variantId: event.variantId,
        isIncoming: false,
        isQueued: event.allowOffline,
        status: event.allowOffline ? 'queued' : 'pending',
        message: event.allowOffline
            ? 'Request will be delivered when ${event.opponent.name} is free.'
            : null,
        createdAt: DateTime.now(),
      );
      _service.sendChallenge(
        event.opponent.id,
        event.mode.name,
        event.timeControl,
        event.variantId,
        requestId: request.id,
        allowOffline: event.allowOffline,
        recipientStatus: event.opponent.presence,
      );
      emit(state.copyWith(
        outgoingChallenges: _upsertChallenge(
          updatedOutgoingChallenges,
          request,
        ),
        lobbyNotice: event.allowOffline
            ? '${event.opponent.name} is busy. Your request was queued.'
            : 'Challenge sent to ${event.opponent.name}!',
      ));
    });

    on<MpSendTournamentInviteEvent>((event, emit) {
      final requestId = _buildChallengeRequestId(event.opponent.id);
      final request = ChallengeRequest(
        id: requestId,
        playerId: event.opponent.id,
        playerName: event.opponent.name,
        mode: 'tournament',
        timeControl: event.timeControl,
        variantId: 'standard',
        isIncoming: false,
        status: 'pending',
        createdAt: DateTime.now(),
      );

      _service.sendTournamentChallenge(
        opponentId: event.opponent.id,
        tournamentId: event.tournamentId,
        totalRounds: event.totalRounds,
        timeControl: event.timeControl,
      );
      emit(state.copyWith(
        outgoingChallenges: _upsertChallenge(
          state.outgoingChallenges,
          request,
        ),
        lobbyNotice: '🏆 Tournament invite sent to ${event.opponent.name}!',
      ));
    });
    on<MpIncomingChallengeReceivedEvent>((event, emit) {
      emit(state.copyWith(
        incomingChallenges: _upsertChallenge(
          state.incomingChallenges,
          event.request,
        ),
        lobbyNotice: event.request.message ??
            '${event.request.playerName} sent you a ${event.request.mode} request.',
        challengerId: event.request.playerId,
        challengerMode: event.request.mode,
        challengerTimeControl: event.request.timeControl,
        challengerVariantId: event.request.variantId,
      ));
    });
    on<MpOutgoingChallengeTrackedEvent>((event, emit) {
      emit(state.copyWith(
        outgoingChallenges: _upsertChallenge(
          state.outgoingChallenges,
          event.request,
        ),
      ));
    });
    on<MpResolveChallengeEvent>((event, emit) {
      final targetList = event.isIncoming
          ? state.incomingChallenges
          : state.outgoingChallenges;
      final updated = _markChallengeResolved(
        targetList,
        event.requestId,
        event.status,
      );
      emit(state.copyWith(
        incomingChallenges:
            event.isIncoming ? updated : state.incomingChallenges,
        outgoingChallenges:
            event.isIncoming ? state.outgoingChallenges : updated,
        lobbyNotice: event.notice ?? state.lobbyNotice,
      ));
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
        myPresence: LobbyPresence.online,
      ));
      _service.sendPresence(LobbyPresence.online, context: 'post_game');
    });
    on<MpLobbyNoticeEvent>((event, emit) => emit(state.copyWith(
          lobbyNotice: event.message,
          challengerId: event.challengerId,
          challengerMode: event.mode,
          challengerTimeControl: event.timeControl,
          challengerVariantId: event.variantId,
        )));
    on<MpAcceptChallengeEvent>((event, emit) {
      _service.acceptChallenge(
        state.challengerId ?? event.challengerId,
        event.mode ?? state.challengerMode ?? 'duel',
        event.timeControl ?? state.challengerTimeControl ?? '10+0',
        event.variantId ?? state.challengerVariantId ?? 'standard',
        requestId: event.requestId,
        isQueued: event.isQueued,
      );
      emit(state.copyWith(
        lobbyNotice: null,
        challengerId: null,
        challengerVariantId: '',
        incomingChallenges: _markChallengeResolved(
          state.incomingChallenges,
          event.requestId ?? event.challengerId,
          'accepted',
        ),
      ));
    });
    on<MpDeclineChallengeEvent>((event, emit) {
      final resolvedId = event.requestId ?? event.challengerId;
      final isOutgoing = state.outgoingChallenges
          .any((request) => request.id == resolvedId);
      _service.declineChallenge(event.challengerId, requestId: event.requestId);
      emit(state.copyWith(
        incomingChallenges: isOutgoing
            ? state.incomingChallenges
            : _markChallengeResolved(
                state.incomingChallenges,
                resolvedId,
                'declined',
              ),
        outgoingChallenges: isOutgoing
            ? _markChallengeResolved(
                state.outgoingChallenges,
                resolvedId,
                'cancelled',
              )
            : state.outgoingChallenges,
        lobbyNotice: isOutgoing
            ? 'Your request to ${event.challengerId} has been cancelled.'
            : null,
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
          pendingTournamentId: null,
          pendingTournamentChallengerId: null,
          pendingTournamentChallengerName: null,
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
    on<MpXpTransferUpdateEvent>((event, emit) {
      final updatedPlayers = state.availablePlayers.map((player) {
        if (player.id == event.donorId) {
          return player.copyWith(xp: event.donorXp);
        }
        if (player.id == event.recipientId) {
          return player.copyWith(xp: event.recipientXp);
        }
        return player;
      }).toList();

      final updatedRequests = state.xpBroadcastRequests
          .where((req) => req['userId']?.toString() != event.recipientId)
          .toList();

      final amIRecipient = _myUserId != null && _myUserId == event.recipientId;
      final amIDonor = _myUserId != null && _myUserId == event.donorId;

      if (amIRecipient || amIDonor) {
        _authBloc.add(AuthCheckStatusEvent());
      }

      final notice = amIRecipient
          ? '${event.donorName} donated ${event.amount} XP to you.'
          : (amIDonor
              ? 'You donated ${event.amount} XP to ${event.recipientName}.'
              : '${event.donorName} donated ${event.amount} XP to ${event.recipientName}.');

      emit(state.copyWith(
        availablePlayers: updatedPlayers,
        xpBroadcastRequests: updatedRequests,
        lobbyNotice: notice,
      ));
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
                  final presence = LobbyPresence.normalize(
                    player['presence']?.toString() ?? player['status']?.toString(),
                  );
                  return OnlineLobbyUser(
                    id: player['id']?.toString() ?? '',
                    name: player['name']?.toString() ?? 'Unknown',
                    xp: (player['rating'] is int)
                        ? player['rating'] as int
                        : int.tryParse(player['rating']?.toString() ?? '0') ??
                            1200,
                    presence: presence,
                    flair: _buildPresenceFlair(
                      presence,
                      player['flair']?.toString(),
                    ),
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
          requestId: data['requestId']?.toString(),
        ));
      } else if (msgType == 'CHALLENGE_RECEIVED') {
        final d = data;
        add(MpIncomingChallengeReceivedEvent(
          ChallengeRequest(
            id: d['requestId']?.toString() ??
                _buildChallengeRequestId(d['challengerId']?.toString() ?? ''),
            playerId: d['challengerId']?.toString() ?? '',
            playerName: d['challengerName']?.toString() ?? 'Someone',
            mode: d['mode']?.toString() ?? 'duel',
            timeControl: d['timeControl']?.toString() ?? '10+0',
            variantId:
                d['variantId']?.toString() ?? d['variant']?.toString() ?? 'standard',
            isIncoming: true,
            isQueued: d['queued'] == true || d['isOffline'] == true,
            message:
                '${d['challengerName']?.toString() ?? 'Someone'} invited you to ${d['mode']?.toString() ?? 'a game'} (${d['timeControl']?.toString() ?? '5+0'}) • ${(d['variantId']?.toString() ?? d['variant']?.toString() ?? 'standard')}',
            createdAt: DateTime.fromMillisecondsSinceEpoch(
              _toInt(d['ts'], fallback: DateTime.now().millisecondsSinceEpoch),
            ),
          ),
        ));
      } else if (msgType == 'PENDING_CHALLENGES_SYNC') {
        final requests = (data['requests'] as List?) ?? const [];
        for (final request in requests.whereType<Map>()) {
          final requestMap = _asMap(request);
          add(MpIncomingChallengeReceivedEvent(
            ChallengeRequest(
              id: requestMap['requestId']?.toString() ??
                  _buildChallengeRequestId(
                    requestMap['challengerId']?.toString() ?? '',
                  ),
              playerId: requestMap['challengerId']?.toString() ?? '',
              playerName: requestMap['challengerName']?.toString() ?? 'Someone',
              mode: requestMap['mode']?.toString() ?? 'duel',
              timeControl: requestMap['timeControl']?.toString() ?? '10+0',
              variantId: requestMap['variantId']?.toString() ?? 'standard',
              isIncoming: true,
              isQueued:
                  requestMap['queued'] == true || requestMap['isOffline'] == true,
              createdAt: DateTime.fromMillisecondsSinceEpoch(
                _toInt(requestMap['ts'],
                    fallback: DateTime.now().millisecondsSinceEpoch),
              ),
            ),
          ));
        }
      } else if (msgType == 'CHALLENGE_SENT') {
        final requestId = data['requestId']?.toString() ??
            _buildChallengeRequestId(data['opponentId']?.toString() ?? '');
        add(MpResolveChallengeEvent(
          requestId: requestId,
          isIncoming: false,
          status: 'pending',
          notice: 'Challenge sent successfully.',
        ));
      } else if (msgType == 'CHALLENGE_QUEUED' ||
          msgType == 'CHALLENGE_BUSY' ||
          msgType == 'CHALLENGE_DELIVERED_OFFLINE') {
        final requestId = data['requestId']?.toString() ??
            _buildChallengeRequestId(data['opponentId']?.toString() ?? '');
        add(MpResolveChallengeEvent(
          requestId: requestId,
          isIncoming: false,
          status: 'queued',
          notice: data['message']?.toString() ??
              'Player is busy. Your challenge will stay queued.',
        ));
      } else if (msgType == 'CHALLENGE_DECLINED' ||
          msgType == 'CHALLENGE_EXPIRED' ||
          msgType == 'CHALLENGE_CANCELLED') {
        final requestId = data['requestId']?.toString() ??
            _buildChallengeRequestId(
              data['challengerId']?.toString() ?? data['opponentId']?.toString() ?? '',
            );
        add(MpResolveChallengeEvent(
          requestId: requestId,
          isIncoming: false,
          status: msgType == 'CHALLENGE_DECLINED'
              ? 'declined'
              : (msgType == 'CHALLENGE_EXPIRED' ? 'expired' : 'cancelled'),
          notice: data['message']?.toString(),
        ));
      } else if (msgType == 'CHALLENGE_ACCEPTED') {
        final requestId = data['requestId']?.toString() ??
            _buildChallengeRequestId(
              data['challengerId']?.toString() ?? data['opponentId']?.toString() ?? '',
            );
        add(MpResolveChallengeEvent(
          requestId: requestId,
          isIncoming: false,
          status: 'accepted',
          notice: data['message']?.toString() ?? 'Challenge accepted. Starting game...',
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
      } else if (msgType == 'XP_TRANSFERRED') {
        final d = data;
        add(MpXpTransferUpdateEvent(
          donorId: d['donorId']?.toString() ?? '',
          donorName: d['donorName']?.toString() ?? 'Player',
          donorXp: _toInt(d['donorXp']),
          recipientId: d['recipientId']?.toString() ?? '',
          recipientName: d['recipientName']?.toString() ?? 'Player',
          recipientXp: _toInt(d['recipientXp']),
          amount: _toInt(d['amount']),
        ));
      } else if (msgType == 'CONNECTION_LOST') {
        add(MpLobbyNoticeEvent('Connection lost. Reconnecting...'));
        _reconnectTimer?.cancel();
        _reconnectTimer = Timer(const Duration(seconds: 5), () {
          if (_myUserId != null && state.status != MultiplayerStatus.disconnected) {
             add(MpReconnectEvent());
          }
        });
      } else if (msgType == 'PRESENCE_SYNC') {
        final presence = LobbyPresence.normalize(data['status']?.toString());
        add(MpSetPresenceEvent(
          presence,
          gameId: data['gameId']?.toString(),
          context: data['context']?.toString(),
        ));
      }
    }, onError: (err) {
      add(MpLobbyNoticeEvent('Network error: ${err.toString()}'));
      _scheduleReconnect();
    }, onDone: () {
      _scheduleReconnect();
    });
    emit(state.copyWith(
      status: MultiplayerStatus.inLobby,
      connectionError: null,
    ));
    _service.sendPresence(state.myPresence, context: 'lobby_connected');
  }

  void _scheduleReconnect() {
    _reconnectTimer?.cancel();
    _reconnectTimer = Timer(const Duration(seconds: 5), () {
      if (_myUserId != null && state.status != MultiplayerStatus.disconnected) {
        add(MpReconnectEvent());
      }
    });
  }

  void _onSetPresence(
      MpSetPresenceEvent event, Emitter<MultiplayerState> emit) {
    final normalized = LobbyPresence.normalize(event.presence);
    if (_service.isLobbyConnected) {
      _service.sendPresence(normalized,
          gameId: event.gameId, context: event.context);
    }
    emit(state.copyWith(myPresence: normalized));
  }

  void _onMatchmaking(
      MpStartMatchmakingEvent event, Emitter<MultiplayerState> emit) {
    _service.findMatch(
      timeControl: state.selectedTimeControl,
      variantId: state.selectedVariantId,
    );
    _service.sendPresence(LobbyPresence.searching, context: 'matchmaking');
    emit(state.copyWith(
      status: MultiplayerStatus.matchmaking,
      myPresence: LobbyPresence.searching,
    ));
  }

  void _onCancelMatchmaking(
      MpCancelMatchmakingEvent event, Emitter<MultiplayerState> emit) {
    _service.cancelFindMatch();
    _service.sendPresence(LobbyPresence.online, context: 'matchmaking_cancelled');
    emit(state.copyWith(
      status: MultiplayerStatus.inLobby,
      myPresence: LobbyPresence.online,
    ));
  }

  Future<void> _onGameFound(
      MpGameFoundEvent event, Emitter<MultiplayerState> emit) async {
    await _service.joinRoom(
      event.gameId,
      event.color.name,
      timeControl: event.timeControl ?? state.selectedTimeControl,
      variantId: event.variantId ?? state.selectedVariantId,
    );

    emit(state.copyWith(
      status: MultiplayerStatus.inGame,
      gameId: event.gameId,
      playerColor: event.color,
      opponentName: event.opponentName,
      opponentAvatarUrl: event.opponentAvatarUrl,
      opponentLocalAvatar: event.opponentLocalAvatar,
      variantId: event.variantId ?? 'standard',
      timeControl: event.timeControl ?? '10+0',
      opponentConnected: false,
    ));

    // Opponent join timeout
    _joinTimer?.cancel();
    _joinTimer = Timer(const Duration(seconds: 22), () {
      if (state.status == MultiplayerStatus.inGame && !state.opponentConnected) {
        add(const MpGameOverEvent('draw', 'opponent_timeout'));
      }
    });

    _gameSub?.cancel();
    _gameSub = _service.gameUpdates.listen((msg) {
      final msgType = msg['type']?.toString();
      final data = _asMap(msg['data']);
      switch (msgType) {
        case 'OPPONENT_JOINED':
        case 'GAME_STARTED':
          add(MpOpponentJoinedEvent());
          break;
        case 'MOVE_UPDATE':
          if (data['undo'] == true) {
            add(MpOpponentUndoEvent());
          } else {
            final senderId = data['userId']?.toString();
            if (senderId != null && senderId == _myUserId) {
              break;
            }
            add(MpOpponentMoveEvent(data));
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
          add(MpChatReceivedEvent(ChatMessage(
            userId: data['userId']?.toString() ?? '',
            username: data['username']?.toString() ?? 'Unknown',
            message: '${data['message']?.toString() ?? ''} ${data['emoji']?.toString() ?? ''}',
            timestamp: DateTime.fromMillisecondsSinceEpoch(
                _toInt(data['ts'], fallback: DateTime.now().millisecondsSinceEpoch)),
            isMe: data['userId']?.toString() == _myUserId,
          )));
          break;
        case 'GAME_OVER':
          add(MpGameOverEvent(
            data['result']?.toString() ?? 'draw',
            data['reason']?.toString() ?? 'unknown',
            xpDelta: _toIntOrNull(data['xpDelta']) ??
                _toIntOrNull(data['xp']) ??
                _toIntOrNull(data['xpChange']),
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
      myPresence: LobbyPresence.playing,
      incomingChallenges: const [],
      outgoingChallenges: event.requestId != null
          ? _markChallengeResolved(state.outgoingChallenges, event.requestId!, 'accepted')
          : state.outgoingChallenges,
      opponentConnected: false,
    ));
    _service.sendPresence(
      LobbyPresence.playing,
      gameId: event.gameId,
      context: event.mode ?? 'multiplayer',
    );
  }

  void _onMakeMove(MpMakeMoveEvent event, Emitter<MultiplayerState> emit) {
    _service.sendMove({
      'from': event.from,
      'to': event.to,
      if (event.promotion != null)
        'promotion': normalizePromotionCode(event.promotion),
    });
  }

  void _onOpponentMove(MpOpponentMoveEvent event, Emitter<MultiplayerState> emit) {
    emit(state.copyWith(
      lastMoveFrom: event.moveData['move']?['from']?.toString(),
      lastMoveTo: event.moveData['move']?['to']?.toString(),
      lastMovePromotion: event.moveData['move']?['promotion']?.toString(),
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

  String _buildPresenceFlair(String presence, String? flair) {
    if (flair != null && flair.trim().isNotEmpty) {
      return flair;
    }
    switch (presence) {
      case LobbyPresence.searching:
        return 'Searching for a match';
      case LobbyPresence.playing:
        return 'In a live game';
      case LobbyPresence.tournament:
        return 'Battling in tournament mode';
      case LobbyPresence.offlineGame:
        return 'In an offline game';
      case LobbyPresence.away:
        return 'Away for a moment';
      default:
        return 'Ready for a challenge';
    }
  }

  String _buildChallengeRequestId(String playerId) {
    final ts = DateTime.now().millisecondsSinceEpoch;
    return '${playerId}_$ts';
  }

  List<ChallengeRequest> _upsertChallenge(
    List<ChallengeRequest> source,
    ChallengeRequest request,
  ) {
    final next = List<ChallengeRequest>.from(source);
    final index = next.indexWhere((item) => item.id == request.id);
    if (index >= 0) {
      next[index] = request;
    } else {
      next.insert(0, request);
    }
    return next;
  }

  List<ChallengeRequest> _markChallengeResolved(
    List<ChallengeRequest> source,
    String requestId,
    String status,
  ) {
    return source
        .map((request) => request.id == requestId
            ? request.copyWith(status: status, isQueued: request.isQueued)
            : request)
        .toList(growable: false);
  }
  @override
  Future<void> close() {
    _lobbySub?.cancel();
    _gameSub?.cancel();
    _joinTimer?.cancel();
    _reconnectTimer?.cancel();
    return super.close();
  }
}
