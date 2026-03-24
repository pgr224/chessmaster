import 'package:flutter/material.dart';

class BracketScreen extends StatelessWidget {
  final String tournamentId;
  const BracketScreen({super.key, required this.tournamentId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tournament Bracket')),
      body: const Center(
        child: Text('Bracket Screen - Coming Soon'),
      ),
    );
  }
}
