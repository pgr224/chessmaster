import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
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
    await Future.delayed(3.seconds);
    if (mounted) context.go('/home');
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Container(
        decoration: const BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topCenter,
            end: Alignment.bottomCenter,
            colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
          ),
        ),
        child: Center(
          child: Column(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              // ── Big bouncy chess king ──
              Container(
                width: 160,
                height: 160,
                decoration: BoxDecoration(
                  shape: BoxShape.circle,
                  gradient: const LinearGradient(
                    begin: Alignment.topLeft,
                    end: Alignment.bottomRight,
                    colors: [AppTheme.goldPrimary, AppTheme.accentPurple, AppTheme.skyBlue],
                  ),
                  boxShadow: [
                    BoxShadow(
                      color: AppTheme.goldPrimary.withValues(alpha: 0.5),
                      blurRadius: 50, spreadRadius: 15,
                    ),
                    BoxShadow(
                      color: AppTheme.accentPurple.withValues(alpha: 0.3),
                      blurRadius: 30, spreadRadius: 5,
                    ),
                  ],
                ),
                child: const Center(
                  child: Text('♔', style: TextStyle(fontSize: 80)),
                ),
              )
                  .animate()
                  .scale(begin: const Offset(0, 0), duration: 1000.ms, curve: Curves.elasticOut)
                  .fadeIn(duration: 600.ms)
                  .then()
                  .shimmer(duration: 1500.ms, color: Colors.white24),

              const SizedBox(height: 40),

              // ── Rainbow gradient title ──
              ShaderMask(
                shaderCallback: (bounds) => AppTheme.rainbowGradient.createShader(bounds),
                child: Text(
                  'CHESS MASTER',
                  style: GoogleFonts.fredoka(
                    color: Colors.white,
                    fontSize: 38,
                    fontWeight: FontWeight.w700,
                    letterSpacing: 4,
                  ),
                ),
              )
                  .animate()
                  .fadeIn(delay: 500.ms, duration: 600.ms)
                  .slideY(begin: 0.5)
                  .then()
                  .shimmer(delay: 500.ms, duration: 2000.ms, color: Colors.white30),

              const SizedBox(height: 12),

              Text(
                '🎮 Play • 📚 Learn • 🏆 Win',
                style: GoogleFonts.baloo2(
                  color: AppTheme.textSecondary,
                  fontSize: 18,
                  letterSpacing: 2,
                ),
              ).animate().fadeIn(delay: 800.ms),

              const SizedBox(height: 80),

              // ── Colorful loading bar ──
              SizedBox(
                width: 160,
                child: ClipRRect(
                  borderRadius: BorderRadius.circular(10),
                  child: const LinearProgressIndicator(
                    minHeight: 8,
                    backgroundColor: AppTheme.surface,
                    valueColor: AlwaysStoppedAnimation(AppTheme.goldPrimary),
                  ),
                ),
              ).animate().fadeIn(delay: 1000.ms),
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
