import 'package:flutter/material.dart';

class GameRoomScreen extends StatelessWidget {
  final String gameId;
  const GameRoomScreen({super.key, required this.gameId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: Text('Game Room: $gameId')),
      body: const Center(
        child: Text('Online Game Room - Coming Soon'),
      ),
    );
  }
}
