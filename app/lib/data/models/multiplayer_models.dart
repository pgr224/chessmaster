import 'package:equatable/equatable.dart';

class OnlineLobbyUser extends Equatable {
  final String id;
  final String name;
  final int xp;
  final bool isAvailable;
  final String flair;

  const OnlineLobbyUser({
    required this.id,
    required this.name,
    required this.xp,
    this.isAvailable = true,
    this.flair = 'Ready to play',
  });

  @override
  List<Object?> get props => [id, name, xp, isAvailable, flair];
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
