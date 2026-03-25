import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';

import '../../../core/theme/app_theme.dart';

class ChessWorldScreen extends StatelessWidget {
  const ChessWorldScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.transparent,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: ListView(
            physics: const BouncingScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 18, 16, 28),
            children: [
              _buildHeader(),
              const SizedBox(height: 16),
              _WorldCard(
                emoji: '🌍',
                title: 'Global Tournament News',
                subtitle: 'Fresh updates from around the chess world.',
                gradient: const LinearGradient(
                  colors: [Color(0xFF74B9FF), Color(0xFFA29BFE)],
                ),
                items: const [
                  'FIDE World Championship: final prep games are trending this week.',
                  'Candidates Tournament watch: new young stars are climbing fast.',
                  'Junior Chess Cup registrations opened in 20+ countries.',
                ],
              ).animate().fadeIn(duration: 350.ms).slideY(begin: 0.08),
              const SizedBox(height: 14),
              _WorldCard(
                emoji: '📅',
                title: 'Upcoming & Participation',
                subtitle: 'How to join kids and amateur events.',
                gradient: const LinearGradient(
                  colors: [Color(0xFF6BCB77), Color(0xFF4ECDC4)],
                ),
                items: const [
                  'Kids Rapid Weekend: register via contact@chesskids.org.',
                  'City Open (U-12 / U-16): ask your local chess club for qualifiers.',
                  'Online Youth League: team signups at events@chessfuture.net.',
                ],
              ).animate().fadeIn(delay: 120.ms, duration: 350.ms).slideY(begin: 0.08),
              const SizedBox(height: 14),
              _WorldCard(
                emoji: '🚀',
                title: 'Career in Chess',
                subtitle: 'Grow from beginner to champion with a clear path.',
                gradient: const LinearGradient(
                  colors: [Color(0xFFFF6B9D), Color(0xFFFF8A5C)],
                ),
                items: const [
                  'Learn ratings: start with local events, then national and FIDE-rated tournaments.',
                  'Build your toolkit: tactics puzzles, endgame practice, and game review habits.',
                  'Dream big: track your progress toward titled-player milestones.',
                ],
              ).animate().fadeIn(delay: 240.ms, duration: 350.ms).slideY(begin: 0.08),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildHeader() {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.rainbowGradient,
        borderRadius: BorderRadius.circular(26),
        boxShadow: [
          BoxShadow(
            color: AppTheme.goldPrimary.withValues(alpha: 0.3),
            blurRadius: 18,
            offset: const Offset(0, 8),
          ),
        ],
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              const Icon(Icons.public_rounded, color: AppTheme.midnight, size: 34),
              const SizedBox(width: 10),
              Expanded(
                child: Text(
                  'Chess World',
                  style: GoogleFonts.fredoka(
                    color: AppTheme.midnight,
                    fontSize: 30,
                    fontWeight: FontWeight.w700,
                    height: 1.1,
                  ),
                ),
              ),
            ],
          ),
          const SizedBox(height: 8),
          Text(
            'News, events, and inspiration for your chess journey.',
            style: GoogleFonts.baloo2(
              color: AppTheme.midnight.withValues(alpha: 0.9),
              fontSize: 18,
              fontWeight: FontWeight.w600,
              height: 1.25,
            ),
          ),
        ],
      ),
    );
  }
}

class _WorldCard extends StatelessWidget {
  final String emoji;
  final String title;
  final String subtitle;
  final LinearGradient gradient;
  final List<String> items;

  const _WorldCard({
    required this.emoji,
    required this.title,
    required this.subtitle,
    required this.gradient,
    required this.items,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.08), width: 1.2),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Padding(
        padding: const EdgeInsets.all(18),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Container(
              padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
              decoration: BoxDecoration(
                gradient: gradient,
                borderRadius: BorderRadius.circular(18),
              ),
              child: Row(
                children: [
                  Text(emoji, style: const TextStyle(fontSize: 30)),
                  const SizedBox(width: 10),
                  Expanded(
                    child: Text(
                      title,
                      style: GoogleFonts.fredoka(
                        color: AppTheme.midnight,
                        fontSize: 22,
                        fontWeight: FontWeight.w700,
                      ),
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: 12),
            Text(
              subtitle,
              style: GoogleFonts.baloo2(
                color: AppTheme.textPrimary,
                fontSize: 18,
                fontWeight: FontWeight.w600,
              ),
            ),
            const SizedBox(height: 10),
            ...items.map(
              (item) => Padding(
                padding: const EdgeInsets.only(bottom: 8),
                child: Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Container(
                      margin: const EdgeInsets.only(top: 7),
                      width: 8,
                      height: 8,
                      decoration: BoxDecoration(
                        color: AppTheme.goldPrimary,
                        borderRadius: BorderRadius.circular(999),
                      ),
                    ),
                    const SizedBox(width: 10),
                    Expanded(
                      child: Text(
                        item,
                        style: GoogleFonts.baloo2(
                          color: AppTheme.textSecondary,
                          fontSize: 16,
                          fontWeight: FontWeight.w500,
                          height: 1.25,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}