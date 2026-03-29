class GameModel {
  final String id;
  final String fen;
  final String? pgn;
  final String mode;
  final String status;
  final String result;
  final String? termination;
  final String? whiteUserId;
  final String? blackUserId;
  final String? whiteUsername;
  final String? blackUsername;
  final int moveCount;
  final String? playerColor;
  final DateTime updatedAt;

  const GameModel({
    required this.id,
    required this.fen,
    this.pgn,
    required this.mode,
    required this.status,
    required this.result,
    this.termination,
    this.whiteUserId,
    this.blackUserId,
    this.whiteUsername,
    this.blackUsername,
    required this.moveCount,
    this.playerColor,
    required this.updatedAt,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) {
    // Robust int parsing
    int parseCount(dynamic value) {
      if (value is int) return value;
      if (value is String) return int.tryParse(value) ?? 0;
      if (value is double) return value.toInt();
      return 0;
    }

    // Robust date parsing
    DateTime parseDate(dynamic value) {
      if (value == null) return DateTime.now();
      if (value is String) return DateTime.tryParse(value) ?? DateTime.now();
      if (value is int) return DateTime.fromMillisecondsSinceEpoch(value);
      return DateTime.now();
    }

    return GameModel(
      id: (json['id'] ?? json['game_id'] ?? '').toString(),
      fen: (json['final_fen'] ?? json['fen'] ?? json['initial_fen'] ?? '').toString(),
      pgn: json['pgn']?.toString(),
      mode: (json['mode'] ?? 'singlePlayer').toString(),
      status: (json['status'] ?? 'active').toString(),
      result: (json['result'] ?? 'ongoing').toString(),
      termination: json['termination']?.toString(),
      whiteUserId: json['white_user_id']?.toString(),
      blackUserId: json['black_user_id']?.toString(),
      whiteUsername: json['white_username']?.toString(),
      blackUsername: json['black_username']?.toString(),
      moveCount: parseCount(json['move_count']),
      playerColor: json['player_color']?.toString(),
      updatedAt: parseDate(json['completed_at'] ?? json['updated_at']),
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'fen': fen,
    'pgn': pgn,
    'mode': mode,
    'status': status,
    'result': result,
    'termination': termination,
    'white_user_id': whiteUserId,
    'black_user_id': blackUserId,
    'white_username': whiteUsername,
    'black_username': blackUsername,
    'move_count': moveCount,
    'player_color': playerColor,
    'updated_at': updatedAt.toIso8601String(),
  };
}
