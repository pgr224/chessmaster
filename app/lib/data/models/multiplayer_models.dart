import 'package:equatable/equatable.dart';

class LobbyPresence {
  static const String online = 'online';
  static const String idle = 'idle';
  static const String searching = 'searching';
  static const String playing = 'playing';
  static const String tournament = 'tournament';
  static const String offlineGame = 'offline_game';
  static const String away = 'away';
  static const String offline = 'offline';

  static String normalize(String? value) {
    final normalized = (value ?? '').trim().toLowerCase();
    switch (normalized) {
      case 'ready':
      case 'available':
        return idle;
      case 'in_game':
      case 'busy':
        return playing;
      case 'tourney':
        return tournament;
      case 'local_game':
      case 'offline':
        return offlineGame;
      default:
        return normalized.isEmpty ? online : normalized;
    }
  }

  static bool isReady(String? value) {
    final normalized = normalize(value);
    return normalized == online || normalized == idle;
  }

  static bool supportsQueuedChallenge(String? value) {
    final normalized = normalize(value);
    return normalized == searching ||
        normalized == playing ||
        normalized == tournament ||
        normalized == offlineGame;
  }

  static String label(String? value) {
    switch (normalize(value)) {
      case idle:
      case online:
        return 'Ready';
      case searching:
        return 'Searching';
      case playing:
        return 'Playing';
      case tournament:
        return 'In Tournament';
      case offlineGame:
        return 'Offline Game';
      case away:
        return 'Away';
      default:
        return 'Offline';
    }
  }
}

class OnlineLobbyUser extends Equatable {
  final String id;
  final String name;
  final int rating;
  final String presence;
  final String flair;
  final int xp;

  const OnlineLobbyUser({
    required this.id,
    required this.name,
    this.rating = 0,
    this.presence = LobbyPresence.online,
    this.flair = 'Ready to play',
    this.xp = 0,
  });

  bool get isAvailable => LobbyPresence.isReady(presence);
  bool get supportsQueuedChallenge =>
      LobbyPresence.supportsQueuedChallenge(presence);
  bool get isBusy => !isAvailable;
  String get presenceLabel => LobbyPresence.label(presence);

  OnlineLobbyUser copyWith({
    String? id,
    String? name,
    int? rating,
    String? presence,
    String? flair,
    int? xp,
  }) {
    return OnlineLobbyUser(
      id: id ?? this.id,
      name: name ?? this.name,
      rating: rating ?? this.rating,
      presence: presence ?? this.presence,
      flair: flair ?? this.flair,
      xp: xp ?? this.xp,
    );
  }

  @override
  List<Object?> get props => [id, name, rating, presence, flair, xp];
}

class ChallengeRequest extends Equatable {
  final String id;
  final String playerId;
  final String playerName;
  final String mode;
  final String timeControl;
  final String variantId;
  final bool isIncoming;
  final bool isQueued;
  final String status;
  final String? message;
  final DateTime createdAt;

  const ChallengeRequest({
    required this.id,
    required this.playerId,
    required this.playerName,
    required this.mode,
    required this.timeControl,
    required this.variantId,
    required this.isIncoming,
    this.isQueued = false,
    this.status = 'pending',
    this.message,
    required this.createdAt,
  });

  bool get canAccept => isIncoming && status == 'pending';
  bool get isResolved =>
      status == 'accepted' ||
      status == 'declined' ||
      status == 'expired' ||
      status == 'cancelled';

  String get summary {
    final queueText = isQueued ? 'Queued' : 'Live';
    return '$queueText ${mode.toUpperCase()} • $timeControl • $variantId';
  }

  ChallengeRequest copyWith({
    String? id,
    String? playerId,
    String? playerName,
    String? mode,
    String? timeControl,
    String? variantId,
    bool? isIncoming,
    bool? isQueued,
    String? status,
    String? message,
    DateTime? createdAt,
  }) {
    return ChallengeRequest(
      id: id ?? this.id,
      playerId: playerId ?? this.playerId,
      playerName: playerName ?? this.playerName,
      mode: mode ?? this.mode,
      timeControl: timeControl ?? this.timeControl,
      variantId: variantId ?? this.variantId,
      isIncoming: isIncoming ?? this.isIncoming,
      isQueued: isQueued ?? this.isQueued,
      status: status ?? this.status,
      message: message ?? this.message,
      createdAt: createdAt ?? this.createdAt,
    );
  }

  @override
  List<Object?> get props => [
        id,
        playerId,
        playerName,
        mode,
        timeControl,
        variantId,
        isIncoming,
        isQueued,
        status,
        message,
        createdAt,
      ];
}

class ChatMessage extends Equatable {
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
    this.isMe = false,
  });

  @override
  List<Object?> get props => [userId, username, message, timestamp, isMe];
}
