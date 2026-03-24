class GameModel {
  final String id;
  final String fen;
  final String? pgn;
  final String mode;
  final String status;
  final String result;
  final int moveCount;
  final DateTime updatedAt;

  const GameModel({
    required this.id,
    required this.fen,
    this.pgn,
    required this.mode,
    required this.status,
    required this.result,
    required this.moveCount,
    required this.updatedAt,
  });

  factory GameModel.fromJson(Map<String, dynamic> json) => GameModel(
    id: json['id'] as String,
    fen: json['final_fen'] as String? ?? json['fen'] as String? ?? '',
    pgn: json['pgn'] as String?,
    mode: json['mode'] as String,
    status: json['status'] as String,
    result: json['result'] as String? ?? 'ongoing',
    moveCount: json['move_count'] as int? ?? 0,
    updatedAt: DateTime.tryParse(json['updated_at'] as String? ?? '') ?? DateTime.now(),
  );
}
