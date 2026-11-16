import 'package:flutter/material.dart';
import 'package:go_router/go_router.dart';
import '../../core/theme/app_theme.dart';

class GuestAccountPrompt extends StatelessWidget {
  final String title;
  final String message;
  const GuestAccountPrompt(
      {super.key,
      this.title = 'Ready for your next chapter?',
      this.message =
          'Create an account to keep future progress and play online. Guest XP is temporary and resets when you leave this game.'});

  @override
  Widget build(BuildContext context) => Container(
      padding: const EdgeInsets.all(16),
      margin: const EdgeInsets.symmetric(vertical: 12),
      decoration: BoxDecoration(
          color: AppTheme.accentCyan.withValues(alpha: 0.1),
          borderRadius: BorderRadius.circular(18),
          border:
              Border.all(color: AppTheme.accentCyan.withValues(alpha: 0.4))),
      child: Column(mainAxisSize: MainAxisSize.min, children: [
        const Icon(Icons.person_add_alt_1_rounded, color: AppTheme.accentCyan),
        const SizedBox(height: 8),
        Text(title,
            textAlign: TextAlign.center,
            style: const TextStyle(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.bold)),
        const SizedBox(height: 8),
        Text(message,
            textAlign: TextAlign.center,
            style: const TextStyle(color: AppTheme.textSecondary)),
        const SizedBox(height: 12),
        Wrap(
            alignment: WrapAlignment.center,
            spacing: 8,
            runSpacing: 8,
            children: [
              FilledButton(
                  onPressed: () => context.go('/onboarding?account=true'),
                  child: const Text('Create account')),
              TextButton(
                  onPressed: () =>
                      context.go('/onboarding?account=true&login=true'),
                  child: const Text('Log in')),
            ]),
      ]));
}

class GuestAccessScreen extends StatelessWidget {
  final String feature;
  const GuestAccessScreen({super.key, required this.feature});
  @override
  Widget build(BuildContext context) => Scaffold(
      backgroundColor: AppTheme.deepSpace,
      appBar: AppBar(
          title: const Text('Play your way'),
          leading: IconButton(
              icon: const Icon(Icons.arrow_back),
              onPressed: () => context.go('/home'))),
      body: Center(
          child: SingleChildScrollView(
              padding: const EdgeInsets.all(24),
              child: ConstrainedBox(
                  constraints: const BoxConstraints(maxWidth: 480),
                  child: Column(mainAxisSize: MainAxisSize.min, children: [
                    GuestAccountPrompt(
                        title: 'Join the chess community',
                        message:
                            '$feature is available with a player account. You can keep enjoying the computer, puzzles, lessons and local two-player games as a guest.'),
                    TextButton(
                        onPressed: () => context.go('/home'),
                        child: const Text('Keep playing offline')),
                  ])))));
}
