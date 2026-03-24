import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';
import '../../../presentation/blocs/auth/auth_bloc.dart';

class OnboardingScreen extends StatefulWidget {
  const OnboardingScreen({super.key});

  @override
  State<OnboardingScreen> createState() => _OnboardingScreenState();
}

class _OnboardingScreenState extends State<OnboardingScreen> {
  final _pageController = PageController();
  final _usernameController = TextEditingController();
  int _currentPage = 0;
  bool _isLoading = false;

  final List<_OnboardPage> _pages = const [
    _OnboardPage(
      emoji: '♟️',
      title: 'Welcome to Chess Master',
      subtitle: 'Play chess like never before — offline anytime, online with the world.',
      gradient: LinearGradient(colors: [Color(0xFF0A0E27), Color(0xFF1A2248)]),
    ),
    _OnboardPage(
      emoji: '🤖',
      title: 'Powerful AI Opponent',
      subtitle: 'Challenge our Stockfish-powered AI across 4 difficulty levels.',
      gradient: LinearGradient(colors: [Color(0xFF0F1535), Color(0xFF1565C0)]),
    ),
    _OnboardPage(
      emoji: '🌐',
      title: 'Real-time Multiplayer',
      subtitle: 'Battle players worldwide, join tournaments, and climb the leaderboard.',
      gradient: LinearGradient(colors: [Color(0xFF0F1535), Color(0xFF7B61FF)]),
    ),
    _OnboardPage(
      emoji: '📚',
      title: 'Learn & Improve',
      subtitle: 'Master openings, tactics, and endgames with our interactive tutorial.',
      gradient: LinearGradient(colors: [Color(0xFF0F1535), Color(0xFF880E4F)]),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticatedState) context.go('/home');
        if (state is AuthErrorState) {
          setState(() => _isLoading = false);
          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(content: Text(state.message)),
          );
        }
      },
      child: Scaffold(
        body: Column(
          children: [
            Expanded(
              child: PageView.builder(
                controller: _pageController,
                onPageChanged: (i) => setState(() => _currentPage = i),
                itemCount: _pages.length,
                itemBuilder: (context, i) => _buildPage(_pages[i], i),
              ),
            ),
            _buildFooter(),
          ],
        ),
      ),
    );
  }

  Widget _buildPage(_OnboardPage page, int index) {
    return Container(
      decoration: BoxDecoration(gradient: page.gradient),
      child: SafeArea(
        child: Padding(
          padding: const EdgeInsets.all(32),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Text(page.emoji, style: const TextStyle(fontSize: 96))
                  .animate().scale(duration: 500.ms, curve: Curves.elasticOut),
              const SizedBox(height: 40),
              Text(
                page.title,
                style: const TextStyle(
                  color: AppTheme.textPrimary, fontSize: 28, fontWeight: FontWeight.w800,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 200.ms),
              const SizedBox(height: 16),
              Text(
                page.subtitle,
                style: const TextStyle(
                  color: AppTheme.textSecondary, fontSize: 16, height: 1.5,
                ),
                textAlign: TextAlign.center,
              ).animate().fadeIn(delay: 300.ms),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final isLast = _currentPage == _pages.length - 1;

    return Container(
      color: AppTheme.midnight,
      padding: const EdgeInsets.fromLTRB(24, 20, 24, 40),
      child: Column(
        children: [
          // Page indicators
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) => AnimatedContainer(
              duration: 300.ms,
              margin: const EdgeInsets.symmetric(horizontal: 4),
              width: _currentPage == i ? 24 : 8,
              height: 8,
              decoration: BoxDecoration(
                color: _currentPage == i ? AppTheme.goldPrimary : AppTheme.textMuted,
                borderRadius: BorderRadius.circular(4),
              ),
            )),
          ),

          const SizedBox(height: 24),

          // Username field (last page only)
          if (isLast) ...[
            TextField(
              controller: _usernameController,
              decoration: InputDecoration(
                labelText: 'Choose your username',
                hintText: 'ChessMaster2024...',
                prefixIcon: const Icon(Icons.person_rounded, color: AppTheme.goldPrimary),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(14)),
              ),
            ).animate().fadeIn().slideY(begin: 0.3),
            const SizedBox(height: 16),
          ],

          // Action button
          SizedBox(
            width: double.infinity,
            height: 54,
            child: ElevatedButton(
              onPressed: _isLoading ? null : () {
                if (isLast) {
                  _register();
                } else {
                  _pageController.nextPage(
                    duration: 300.ms, curve: Curves.easeInOut,
                  );
                }
              },
              child: _isLoading
                  ? const SizedBox(width: 24, height: 24, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 2))
                  : Text(
                      isLast ? 'Start Playing!' : 'Next →',
                      style: const TextStyle(fontSize: 17, fontWeight: FontWeight.w800),
                    ),
            ),
          ),

          // Skip button
          if (!isLast)
            TextButton(
              onPressed: () => _pageController.jumpToPage(_pages.length - 1),
              child: const Text('Skip', style: TextStyle(color: AppTheme.textMuted)),
            ),
        ],
      ),
    );
  }

  void _register() {
    final username = _usernameController.text.trim();
    if (username.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Username must be at least 2 characters')),
      );
      return;
    }
    setState(() => _isLoading = true);
    context.read<AuthBloc>().add(AuthRegisterEvent(username: username));
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}

class _OnboardPage {
  final String emoji;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  const _OnboardPage({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
  });
}
