import 'package:flutter/material.dart';

class MatchmakingScreen extends StatelessWidget {
  const MatchmakingScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Searching for opponent...')),
      body: const Center(
        child: CircularProgressIndicator(),
      ),
    );
  }
}
