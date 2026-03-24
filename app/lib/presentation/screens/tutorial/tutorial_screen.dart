import 'package:flutter/material.dart';

class TutorialScreen extends StatelessWidget {
  const TutorialScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Tutorial')),
      body: const Center(
        child: Text('Tutorial Screen - Coming Soon'),
      ),
    );
  }
}
