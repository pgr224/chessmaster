import 'dart:async';
import 'package:equatable/equatable.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import '../../../data/models/tournament_model.dart';
import '../../../data/repositories/tournament_repository.dart';
import '../../../data/services/multiplayer_service.dart';

// ─── Events ──────────────────────────────────────────────────────

abstract class TournamentEvent extends Equatable {
  const TournamentEvent();
  @override
  List<Object?> get props => [];
}

class TournamentLoadListEvent extends TournamentEvent {}

class TournamentCreateEvent extends TournamentEvent {
  final String name;
  final String type;
  final int totalRounds;
  final String timeControl;
  final List<String> invitedPlayers;

  const TournamentCreateEvent({
    required this.name,
    required this.type,
    required this.totalRounds,
    required this.timeControl,
    this.invitedPlayers = const [],
  });

  @override
  List<Object?> get props => [name, type, totalRounds, timeControl, invitedPlayers];
}

class TournamentJoinEvent extends TournamentEvent {
  final String tournamentId;
  const TournamentJoinEvent(this.tournamentId);
  @override
  List<Object?> get props => [tournamentId];
}

class TournamentConnectEvent extends TournamentEvent {
  final String tournamentId;
  final String userId;
  final String username;
  final int rating;
  const TournamentConnectEvent({
    required this.tournamentId,
    required this.userId,
    required this.username,
    this.rating = 1200,
  });
  @override
  List<Object?> get props => [tournamentId, userId, username, rating];
}

class TournamentReadyEvent extends TournamentEvent {}

class TournamentDisconnectEvent extends TournamentEvent {}

class TournamentSelectRoundsEvent extends TournamentEvent {
  final int rounds;
  const TournamentSelectRoundsEvent(this.rounds);
  @override
  List<Object?> get props => [rounds];
}

class TournamentSelectTimeControlEvent extends TournamentEvent {
  final String timeControl;
  const TournamentSelectTimeControlEvent(this.timeControl);
  @override
  List<Object?> get props => [timeControl];
}

// Internal: message received from DO
class _TournamentWsMessageEvent extends TournamentEvent {
  final Map<String, dynamic> data;
  const _TournamentWsMessageEvent(this.data);
  @override
  List<Object?> get props => [data];
}

// ─── State ───────────────────────────────────────────────────────

enum TournamentStatus { idle, loading, waiting, active, finished, error }

class TournamentState extends Equatable {
  final TournamentStatus status;
  final List<TournamentModel> tournaments;
  final TournamentModel? activeTournament;
  final int currentRound;
  final int totalRounds;
  final String selectedTimeControl;
  final int selectedRounds;
  final String? engagementMessage;
  final String? errorMessage;
  final int xpEarned;
  final int eloChange;

  const TournamentState({
    this.status = TournamentStatus.idle,
    this.tournaments = const [],
    this.activeTournament,
    this.currentRound = 0,
    this.totalRounds = 3,
    this.selectedTimeControl = '10+0',
    this.selectedRounds = 3,
    this.engagementMessage,
    this.errorMessage,
    this.xpEarned = 0,
    this.eloChange = 0,
  });

  TournamentState copyWith({
    TournamentStatus? status,
    List<TournamentModel>? tournaments,
    TournamentModel? activeTournament,
    int? currentRound,
    int? totalRounds,
    String? selectedTimeControl,
    int? selectedRounds,
    String? engagementMessage,
    String? errorMessage,
    int? xpEarned,
    int? eloChange,
  }) {
    return TournamentState(
      status: status ?? this.status,
      tournaments: tournaments ?? this.tournaments,
      activeTournament: activeTournament ?? this.activeTournament,
      currentRound: currentRound ?? this.currentRound,
      totalRounds: totalRounds ?? this.totalRounds,
      selectedTimeControl: selectedTimeControl ?? this.selectedTimeControl,
      selectedRounds: selectedRounds ?? this.selectedRounds,
      engagementMessage: engagementMessage,
      errorMessage: errorMessage,
      xpEarned: xpEarned ?? this.xpEarned,
      eloChange: eloChange ?? this.eloChange,
    );
  }

  @override
  List<Object?> get props => [
        status,
        tournaments,
        activeTournament,
        currentRound,
        totalRounds,
        selectedTimeControl,
        selectedRounds,
        engagementMessage,
        errorMessage,
        xpEarned,
        eloChange,
      ];
}

// ─── BLoC ────────────────────────────────────────────────────────

class TournamentBloc extends Bloc<TournamentEvent, TournamentState> {
  final TournamentRepository _repo;
  final MultiplayerService _mpService;
  StreamSubscription<Map<String, dynamic>>? _wsSubscription;

  TournamentBloc(this._repo, this._mpService)
      : super(const TournamentState()) {
    on<TournamentLoadListEvent>(_onLoadList);
    on<TournamentCreateEvent>(_onCreate);
    on<TournamentJoinEvent>(_onJoin);
    on<TournamentConnectEvent>(_onConnect);
    on<TournamentReadyEvent>(_onReady);
    on<TournamentDisconnectEvent>(_onDisconnect);
    on<TournamentSelectRoundsEvent>(_onSelectRounds);
    on<TournamentSelectTimeControlEvent>(_onSelectTimeControl);
    on<_TournamentWsMessageEvent>(_onWsMessage);
  }

  Future<void> _onLoadList(TournamentLoadListEvent event, Emitter<TournamentState> emit) async {
    emit(state.copyWith(status: TournamentStatus.loading));
    try {
      final list = await _repo.fetchTournaments();
      emit(state.copyWith(status: TournamentStatus.idle, tournaments: list));
    } catch (e) {
      emit(state.copyWith(status: TournamentStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onCreate(TournamentCreateEvent event, Emitter<TournamentState> emit) async {
    emit(state.copyWith(status: TournamentStatus.loading));
    try {
      await _repo.createTournament(
        name: event.name,
        type: event.type,
        totalRounds: event.totalRounds,
        timeControl: event.timeControl,
        invitedPlayers: event.invitedPlayers,
      );
      emit(state.copyWith(status: TournamentStatus.idle));
    } catch (e) {
      emit(state.copyWith(status: TournamentStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onJoin(TournamentJoinEvent event, Emitter<TournamentState> emit) async {
    try {
      await _repo.joinTournament(event.tournamentId);
    } catch (e) {
      emit(state.copyWith(status: TournamentStatus.error, errorMessage: e.toString()));
    }
  }

  Future<void> _onConnect(TournamentConnectEvent event, Emitter<TournamentState> emit) async {
    emit(state.copyWith(status: TournamentStatus.waiting));
    await _wsSubscription?.cancel();
    await _mpService.connectTournament(
      event.tournamentId,
      event.userId,
      event.username,
      rating: event.rating,
      totalRounds: state.selectedRounds,
      timeControl: state.selectedTimeControl,
    );
    _wsSubscription = _mpService.tournamentUpdates.listen((msg) {
      add(_TournamentWsMessageEvent(msg));
    });
  }

  void _onReady(TournamentReadyEvent event, Emitter<TournamentState> emit) {
    _mpService.sendTournamentReady();
  }

  Future<void> _onDisconnect(TournamentDisconnectEvent event, Emitter<TournamentState> emit) async {
    await _wsSubscription?.cancel();
    _wsSubscription = null;
    _mpService.disconnectTournament();
    emit(const TournamentState());
  }

  void _onSelectRounds(TournamentSelectRoundsEvent event, Emitter<TournamentState> emit) {
    emit(state.copyWith(selectedRounds: event.rounds));
  }

  void _onSelectTimeControl(TournamentSelectTimeControlEvent event, Emitter<TournamentState> emit) {
    emit(state.copyWith(selectedTimeControl: event.timeControl));
  }

  void _onWsMessage(_TournamentWsMessageEvent event, Emitter<TournamentState> emit) {
    final msg = event.data;
    final type = msg['type'] as String? ?? '';
    final data = msg['data'] as Map<String, dynamic>? ?? {};

    switch (type) {
      case 'tournament_state':
        final model = TournamentModel.fromJson(data);
        emit(state.copyWith(
          activeTournament: model,
          currentRound: model.currentRound,
          totalRounds: model.totalRounds,
          status: model.status == 'waiting'
              ? TournamentStatus.waiting
              : model.status == 'active'
                  ? TournamentStatus.active
                  : TournamentStatus.finished,
        ));
        break;

      case 'tournament_start':
        emit(state.copyWith(
          status: TournamentStatus.active,
          totalRounds: (data['totalRounds'] as num?)?.toInt() ?? state.totalRounds,
        ));
        break;

      case 'round_start':
        final round = (data['round'] as num?)?.toInt() ?? state.currentRound + 1;
        final pairings = (data['pairings'] as List<dynamic>?)
                ?.map((e) => TournamentPairing.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        final updated = state.activeTournament == null
            ? null
            : TournamentModel(
                id: state.activeTournament!.id,
                name: state.activeTournament!.name,
                type: state.activeTournament!.type,
                format: state.activeTournament!.format,
                status: 'active',
                totalRounds: state.activeTournament!.totalRounds,
                currentRound: round,
                timeControl: state.activeTournament!.timeControl,
                players: state.activeTournament!.players,
                currentPairings: pairings,
              );
        emit(state.copyWith(
          currentRound: round,
          activeTournament: updated,
          engagementMessage: null,
        ));
        break;

      case 'match_result':
        // standings come with this; rebuild TournamentModel players
        final standings = (data['standings'] as List<dynamic>?)
                ?.map((e) => TournamentPlayer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            state.activeTournament?.players ??
            [];
        if (state.activeTournament != null) {
          final updated = TournamentModel(
            id: state.activeTournament!.id,
            name: state.activeTournament!.name,
            type: state.activeTournament!.type,
            format: state.activeTournament!.format,
            status: state.activeTournament!.status,
            totalRounds: state.activeTournament!.totalRounds,
            currentRound: state.activeTournament!.currentRound,
            timeControl: state.activeTournament!.timeControl,
            players: standings,
            currentPairings: state.activeTournament!.currentPairings,
          );
          emit(state.copyWith(activeTournament: updated));
        }
        break;

      case 'engagement_notice':
        emit(state.copyWith(engagementMessage: data['message'] as String?));
        break;

      case 'tournament_end':
        final xpDeltas = data['xpDeltas'] as Map<String, dynamic>? ?? {};
        final eloDeltas = data['eloDeltas'] as Map<String, dynamic>? ?? {};
        // We don't know local userId here; callers read from activeTournament standings
        emit(state.copyWith(
          status: TournamentStatus.finished,
          xpEarned: (xpDeltas.values.isNotEmpty
              ? xpDeltas.values.first as num
              : 0)
              .toInt(),
          eloChange: (eloDeltas.values.isNotEmpty
              ? eloDeltas.values.first as num
              : 0)
              .toInt(),
        ));
        break;

      case 'players_update':
        final players = (data['players'] as List<dynamic>?)
                ?.map((e) => TournamentPlayer.fromJson(e as Map<String, dynamic>))
                .toList() ??
            [];
        if (state.activeTournament != null) {
          final updated = TournamentModel(
            id: state.activeTournament!.id,
            name: state.activeTournament!.name,
            type: state.activeTournament!.type,
            format: state.activeTournament!.format,
            status: state.activeTournament!.status,
            totalRounds: state.activeTournament!.totalRounds,
            currentRound: state.activeTournament!.currentRound,
            timeControl: state.activeTournament!.timeControl,
            players: players,
            currentPairings: state.activeTournament!.currentPairings,
          );
          emit(state.copyWith(activeTournament: updated));
        }
        break;
    }
  }

  @override
  Future<void> close() async {
    await _wsSubscription?.cancel();
    _mpService.disconnectTournament();
    return super.close();
  }
}
