import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class SplashScreen extends StatefulWidget {
  const SplashScreen({super.key});

  @override
  State<SplashScreen> createState() => _SplashScreenState();
}

class _SplashScreenState extends State<SplashScreen>
    with SingleTickerProviderStateMixin {
  late AnimationController _controller;

  @override
  void initState() {
    super.initState();
    _controller = AnimationController(vsync: this, duration: 2.seconds);
    _controller.forward();
    _navigate();
  }

  Future<void> _navigate() async {
    await Future.delayed(2500.ms);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // Chess piece logo
              Container(
                width: 120,
                height: 120,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.goldDark, AppTheme.goldLight],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.goldPrimary.withOpacity(0.5),
                      blurRadius: 40, spreadRadius: 10,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('♔', style: TextStyle(fontSize: 64)),
                ),
              ).animate()
                  .scale(begin: const Offset(0, 0), duration: 800.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 500.ms),

              const SizedBox(height: 32),

              // App name
              ShaderMask(
                shaderCallback: (bounds) => const LinearGradient(
                  colors: [AppTheme.goldDark, AppTheme.goldLight, AppTheme.goldDark],
                ).createShader(bounds),
                child: const Text(
                  'CHESS MASTER',
                  style: TextStyle(
                    color: Colors.white,
                    fontSize: 32,
                    fontWeight: FontWeight.w900,
                    letterSpacing: 6,
                  ),
                ),
              ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.3),

              const SizedBox(height: 8),

              const Text(
                'Play • Learn • Compete',
                style: TextStyle(
                  color: AppTheme.textSecondary,
                  fontSize: 14,
                  letterSpacing: 3,
                ),
              ).animate().fadeIn(delay: 600.ms),

              const SizedBox(height: 80),

              // Loading indicator
              SizedBox(
                width: 120,
                child: LinearProgressIndicator(
                  backgroundColor: AppTheme.surface,
                  valueColor: const AlwaysStoppedAnimation(AppTheme.goldPrimary),
                ),
              ).animate().fadeIn(delay: 800.ms),
            ],
          ),
        ),
      ),
    );
  }

  @override
  void dispose() {
    _controller.dispose();
    super.dispose();
  }
}
