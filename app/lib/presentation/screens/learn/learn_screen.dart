import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';

class LearnScreen extends StatelessWidget {
  const LearnScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text('📚 Chess Academy',
          style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 26, fontWeight: FontWeight.w700),
        ),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              _buildFeaturedCard(context),
              Expanded(
                child: ListView(
                  padding: const EdgeInsets.all(24),
                  children: [
                    Text('🗂️ Explore Categories',
                      style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 24, fontWeight: FontWeight.w700),
                    ),
                    const SizedBox(height: 18),
                    _buildCategory('🎓 Fundamentals', 'Learn how pieces move!', AppTheme.goldPrimary),
                    _buildCategory('♟️ Openings', 'Control the center!', AppTheme.skyBlue),
                    _buildCategory('⚡ Tactics', 'Find winning combos!', AppTheme.accentPurple),
                    _buildCategory('⏳ Endgames', 'Finish strong!', AppTheme.accentCyan),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildFeaturedCard(BuildContext context) {
    return Container(
      margin: const EdgeInsets.symmetric(horizontal: 24, vertical: 14),
      width: double.infinity,
      height: 190,
      decoration: BoxDecoration(
        gradient: const LinearGradient(
          colors: [Color(0xFFFF8A5C), Color(0xFFFFD93D), Color(0xFF6BCB77)],
        ),
        borderRadius: BorderRadius.circular(28),
        boxShadow: [
          BoxShadow(color: AppTheme.goldPrimary.withValues(alpha: 0.35), blurRadius: 24, offset: const Offset(0, 10)),
        ],
      ),
      child: Stack(
        children: [
          Positioned(
            right: -10, bottom: -10,
            child: Icon(Icons.star_rounded, size: 120, color: Colors.white.withValues(alpha: 0.15)),
          ),
          Padding(
            padding: const EdgeInsets.all(26),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Text('✨ LATEST LESSON', style: GoogleFonts.fredoka(
                  color: AppTheme.midnight, fontSize: 12, fontWeight: FontWeight.w600, letterSpacing: 1,
                )),
                const SizedBox(height: 10),
                Text('Master the\nSicilian Defense', style: GoogleFonts.fredoka(
                  color: AppTheme.midnight, fontSize: 28, fontWeight: FontWeight.w700, height: 1.15,
                )),
                const Spacer(),
                ElevatedButton(
                  onPressed: () {},
                  style: ElevatedButton.styleFrom(
                    backgroundColor: AppTheme.midnight,
                    foregroundColor: Colors.white,
                    shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
                    padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
                  ),
                  child: Text('Start Now! 🚀', style: GoogleFonts.fredoka(fontWeight: FontWeight.w600, fontSize: 16)),
                ),
              ],
            ),
          ),
        ],
      ),
    ).animate().fadeIn().slideY(begin: 0.1);
  }

  Widget _buildCategory(String title, String desc, Color color) {
    return GestureDetector(
      onTap: () {},
      child: Container(
        margin: const EdgeInsets.only(bottom: 16),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(24),
          border: Border.all(color: color.withValues(alpha: 0.15)),
          boxShadow: [
            BoxShadow(color: color.withValues(alpha: 0.1), blurRadius: 12, offset: const Offset(0, 4)),
          ],
        ),
        child: Row(
          children: [
            Expanded(
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(title, style: GoogleFonts.fredoka(
                    color: AppTheme.textPrimary, fontSize: 21, fontWeight: FontWeight.w700,
                  )),
                  const SizedBox(height: 4),
                  Text(desc, style: GoogleFonts.baloo2(color: AppTheme.textSecondary, fontSize: 16, fontWeight: FontWeight.w600)),
                ],
              ),
            ),
            Container(
              width: 36, height: 36,
              decoration: BoxDecoration(
                color: color.withValues(alpha: 0.15),
                borderRadius: BorderRadius.circular(12),
              ),
              child: Icon(Icons.arrow_forward_ios_rounded, color: color, size: 16),
            ),
          ],
        ),
      ),
    ).animate().fadeIn().slideX(begin: 0.05);
  }
}
