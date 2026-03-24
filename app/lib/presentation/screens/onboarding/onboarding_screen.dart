import 'dart:math';

import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
  final Random _random = Random();
  int _currentPage = 0;
  bool _isLoading = false;
  String? _usernameErrorText;
  bool _hasRetriedSuggestedUsername = false;

  final List<_OnboardPage> _pages = const [
    _OnboardPage(
      image: 'assets/images/onboarding_1.png',
      emoji: '♟️',
      title: 'Welcome to Chess Master!',
      subtitle: 'The most fun way to play chess — anytime, anywhere! 🎉',
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF1A1A2E), Color(0xFF2D1B69)],
      ),
      accentColor: Color(0xFFFFD93D),
    ),
    _OnboardPage(
      image: 'assets/images/onboarding_2.png',
      emoji: '🤖',
      title: 'Play Against Smart AI!',
      subtitle: 'Our friendly robot will challenge you at YOUR level! 🧠',
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF0F3460), Color(0xFF1A1A4E)],
      ),
      accentColor: Color(0xFF74B9FF),
    ),
    _OnboardPage(
      image: 'assets/images/onboarding_3.png',
      emoji: '🌍',
      title: 'Play With Friends!',
      subtitle: 'Connect and battle players from around the world! 🤝',
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF1A1A2E), Color(0xFF2D4059)],
      ),
      accentColor: Color(0xFF6BCB77),
    ),
    _OnboardPage(
      image: 'assets/images/onboarding_4.png',
      emoji: '📚',
      title: 'Learn & Get Better!',
      subtitle: 'Discover cool tricks and become a chess champion! ⭐',
      gradient: LinearGradient(
        begin: Alignment.topCenter, end: Alignment.bottomCenter,
        colors: [Color(0xFF1A1A2E), Color(0xFF4A1942)],
      ),
      accentColor: Color(0xFFFF6B9D),
    ),
  ];

  @override
  Widget build(BuildContext context) {
    return BlocListener<AuthBloc, AuthState>(
      listener: (context, state) {
        if (state is AuthAuthenticatedState) context.go('/home');
        if (state is AuthErrorState) {
          final isConflict = _isRegisterConflict(state.message);
          String? suggestedUsername;
          if (isConflict) {
            suggestedUsername = _buildUsernameSuggestion(_usernameController.text.trim());
            _usernameController.text = suggestedUsername;
            _usernameController.selection = TextSelection.fromPosition(
              TextPosition(offset: _usernameController.text.length),
            );
          }

          if (isConflict && !_hasRetriedSuggestedUsername && suggestedUsername != null) {
            _hasRetriedSuggestedUsername = true;

            if (_currentPage != _pages.length - 1) {
              _pageController.animateToPage(
                _pages.length - 1,
                duration: 300.ms,
                curve: Curves.easeInOut,
              );
            }

            setState(() {
              _isLoading = true;
              _usernameErrorText = 'Username was taken. Trying "$suggestedUsername" instead...';
            });

            ScaffoldMessenger.of(context).showSnackBar(
              SnackBar(
                content: Text(
                  'Username was taken. Trying "$suggestedUsername" instead.',
                  style: GoogleFonts.baloo2(),
                ),
              ),
            );

            WidgetsBinding.instance.addPostFrameCallback((_) {
              if (!mounted) return;
              context.read<AuthBloc>().add(AuthRegisterEvent(username: suggestedUsername!));
            });
            return;
          }

          setState(() {
            _isLoading = false;
            _usernameErrorText = isConflict
                ? 'Username already taken. Try "$suggestedUsername".'
                : null;
          });

          if (isConflict && _currentPage != _pages.length - 1) {
            _pageController.animateToPage(
              _pages.length - 1,
              duration: 300.ms,
              curve: Curves.easeInOut,
            );
          }

          ScaffoldMessenger.of(context).showSnackBar(
            SnackBar(
              content: Text(
                isConflict ? 'Username already taken, try another one.' : state.message,
                style: GoogleFonts.baloo2(),
              ),
            ),
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
          padding: const EdgeInsets.symmetric(horizontal: 28),
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Generated illustration ──
              Container(
                height: 260,
                width: 260,
                decoration: BoxDecoration(
                  borderRadius: BorderRadius.circular(32),
                  boxShadow: [
                    BoxShadow(
                      color: page.accentColor.withValues(alpha: 0.3),
                      blurRadius: 40,
                      spreadRadius: 8,
                    ),
                  ],
                ),
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(32),
                  child: Image.asset(
                    page.image,
                    fit: BoxFit.cover,
                    errorBuilder: (_, __, ___) => Container(
                      color: AppTheme.surface,
                      child: Center(
                        child: Text(page.emoji, style: const TextStyle(fontSize: 96)),
                      ),
                    ),
                  ),
                ),
              )
                  .animate()
                  .scale(begin: const Offset(0.7, 0.7), duration: 600.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 400.ms),

              const SizedBox(height: 40),

              // ── Title ──
              Text(
                page.title,
                style: GoogleFonts.fredoka(
                  color: AppTheme.textPrimary,
                  fontSize: 30,
                  fontWeight: FontWeight.w700,
                  height: 1.2,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 200.ms)
                  .slideY(begin: 0.3),

              const SizedBox(height: 16),

              // ── Subtitle ──
              Text(
                page.subtitle,
                style: GoogleFonts.baloo2(
                  color: AppTheme.textSecondary,
                  fontSize: 18,
                  height: 1.5,
                ),
                textAlign: TextAlign.center,
              )
                  .animate()
                  .fadeIn(delay: 400.ms)
                  .slideY(begin: 0.2),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFooter() {
    final isLast = _currentPage == _pages.length - 1;

    return Container(
      decoration: BoxDecoration(
        color: AppTheme.midnight,
        borderRadius: const BorderRadius.vertical(top: Radius.circular(28)),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.3),
            blurRadius: 20,
            offset: const Offset(0, -4),
          ),
        ],
      ),
      padding: const EdgeInsets.fromLTRB(24, 24, 24, 40),
      child: Column(
        children: [
          // ── Page dots ──
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: List.generate(_pages.length, (i) => AnimatedContainer(
              duration: 300.ms,
              margin: const EdgeInsets.symmetric(horizontal: 5),
              width: _currentPage == i ? 32 : 10,
              height: 10,
              decoration: BoxDecoration(
                gradient: _currentPage == i
                    ? LinearGradient(colors: [_pages[_currentPage].accentColor, AppTheme.goldPrimary])
                    : null,
                color: _currentPage == i ? null : AppTheme.textMuted.withValues(alpha: 0.4),
                borderRadius: BorderRadius.circular(5),
              ),
            )),
          ),

          const SizedBox(height: 28),

          // ── Username field (last page) ──
          if (isLast) ...[
            TextField(
              controller: _usernameController,
              style: GoogleFonts.baloo2(color: AppTheme.textPrimary, fontSize: 18),
              decoration: InputDecoration(
                labelText: '🎮 Pick your player name!',
                labelStyle: GoogleFonts.fredoka(color: AppTheme.textSecondary, fontSize: 16),
                hintText: 'SuperChessKid...',
                hintStyle: GoogleFonts.baloo2(color: AppTheme.textMuted),
                prefixIcon: const Icon(Icons.person_rounded, color: AppTheme.goldPrimary, size: 28),
                border: OutlineInputBorder(borderRadius: BorderRadius.circular(20)),
                errorText: _usernameErrorText,
                filled: true,
                fillColor: AppTheme.surface,
              ),
            ).animate().fadeIn().slideY(begin: 0.3),
            const SizedBox(height: 20),
          ],

          // ── Action button ──
          SizedBox(
            width: double.infinity,
            height: 60,
            child: ElevatedButton(
              style: ElevatedButton.styleFrom(
                backgroundColor: isLast ? AppTheme.accentCyan : AppTheme.goldPrimary,
                foregroundColor: AppTheme.midnight,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
                elevation: 8,
                shadowColor: (isLast ? AppTheme.accentCyan : AppTheme.goldPrimary).withValues(alpha: 0.5),
              ),
              onPressed: _isLoading ? null : () {
                if (isLast) {
                  _register();
                } else {
                  _pageController.nextPage(
                    duration: 400.ms, curve: Curves.easeInOut,
                  );
                }
              },
              child: _isLoading
                  ? const SizedBox(width: 28, height: 28, child: CircularProgressIndicator(color: Colors.white, strokeWidth: 3))
                  : Text(
                      isLast ? '🚀 Start Playing!' : 'Next →',
                      style: GoogleFonts.fredoka(fontSize: 20, fontWeight: FontWeight.w700),
                    ),
            ),
          ).animate().fadeIn(delay: 100.ms).scale(begin: const Offset(0.95, 0.95)),

          // ── Skip ──
          if (!isLast)
            TextButton(
              onPressed: () => _pageController.jumpToPage(_pages.length - 1),
              child: Text(
                'Skip ⏩',
                style: GoogleFonts.baloo2(color: AppTheme.textMuted, fontSize: 16),
              ),
            ),
        ],
      ),
    );
  }

  void _register() {
    final username = _usernameController.text.trim();
    if (username.length < 2) {
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(
          content: Text('Username must be at least 2 characters 😊', style: GoogleFonts.baloo2()),
        ),
      );
      return;
    }
    setState(() {
      _usernameErrorText = null;
      _isLoading = true;
      _hasRetriedSuggestedUsername = false;
    });
    context.read<AuthBloc>().add(AuthRegisterEvent(username: username));
  }

  bool _isRegisterConflict(String message) {
    final text = message.toLowerCase();
    return text.contains('409') ||
        text.contains('conflict') ||
        text.contains('already exists') ||
        text.contains('already taken');
  }

  String _buildUsernameSuggestion(String currentUsername) {
    final cleaned = currentUsername.replaceAll(RegExp(r'\s+'), '');
    final base = cleaned.isEmpty ? 'ChessPlayer' : cleaned.replaceAll(RegExp(r'\d+$'), '');
    final suffix = 100 + _random.nextInt(900);
    return '$base$suffix';
  }

  @override
  void dispose() {
    _pageController.dispose();
    _usernameController.dispose();
    super.dispose();
  }
}

class _OnboardPage {
  final String image;
  final String emoji;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final Color accentColor;
  const _OnboardPage({
    required this.image,
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.accentColor,
  });
}
