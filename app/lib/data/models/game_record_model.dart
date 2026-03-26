import 'user_model.dart';

class GameRecord {
  final String id;
  final String date;
  final String opponent;
  final String result; // 'Won', 'Lost', 'Draw'
  final String mode; // 'AI', 'Multiplayer'
  final int moves;

  const GameRecord({
    required this.id,
    required this.date,
    required this.opponent,
    required this.result,
    required this.mode,
    required this.moves,
  });

  factory GameRecord.fromJson(Map<String, dynamic> json) {
    return GameRecord(
      id: json['id'] as String,
      date: json['date'] as String,
      opponent: json['opponent'] as String,
      result: json['result'] as String,
      mode: json['mode'] as String,
      moves: json['moves'] as int,
    );
  }

  Map<String, dynamic> toJson() => {
    'id': id,
    'date': date,
    'opponent': opponent,
    'result': result,
    'mode': mode,
    'moves': moves,
  };
}
