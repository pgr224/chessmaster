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
    required this.updatedAt,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) => GameModel(
    id: json['id'] as String? ?? '',
    fen: json['final_fen'] as String? ?? json['fen'] as String? ?? '',
    pgn: json['pgn'] as String?,
    mode: json['mode'] as String? ?? 'singlePlayer',
    status: json['status'] as String? ?? 'active',
    result: json['result'] as String? ?? 'ongoing',
    termination: json['termination'] as String?,
    whiteUserId: json['white_user_id'] as String?,
    blackUserId: json['black_user_id'] as String?,
    whiteUsername: json['white_username'] as String?,
    blackUsername: json['black_username'] as String?,
    moveCount: json['move_count'] as int? ?? 0,
    updatedAt: DateTime.tryParse((json['completed_at'] ?? json['updated_at']) as String? ?? '') ?? DateTime.now(),
  );

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
    'updated_at': updatedAt.toIso8601String(),
  };
}
