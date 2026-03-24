import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import '../../../core/theme/app_theme.dart';

class ArticleScreen extends StatelessWidget {
  final String articleId;
  const ArticleScreen({super.key, required this.articleId});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: CustomScrollView(
        slivers: [
          _buildSliverAppBar(context),
          SliverToBoxAdapter(
            child: Padding(
              padding: const EdgeInsets.all(24.0),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  _buildAuthorInfo(),
                  const SizedBox(height: 24),
                  _buildContent(),
                  const SizedBox(height: 40),
                  _buildRelatedLessons(),
                ],
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _buildSliverAppBar(BuildContext context) {
    return SliverAppBar(
      expandedHeight: 240,
      pinned: true,
      backgroundColor: AppTheme.midnight,
      leading: CircleAvatar(
        backgroundColor: Colors.black26,
        child: IconButton(
          icon: const Icon(Icons.close_rounded, color: Colors.white),
          onPressed: () => context.pop(),
        ),
      ),
      flexibleSpace: FlexibleSpaceBar(
        title: Text(
          'Sicilian Defense',
          style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 18),
        ).animate().fadeIn(delay: 200.ms),
        background: Stack(
          fit: StackFit.expand,
          children: [
            Image.network('https://images.unsplash.com/photo-1529699211952-734e80c4d42b?auto=format&fit=crop&q=80&w=800', fit: BoxFit.cover),
            Container(
              decoration: BoxDecoration(
                gradient: LinearGradient(
                  begin: Alignment.topCenter, end: Alignment.bottomCenter,
                  colors: [Colors.transparent, AppTheme.midnight.withOpacity(0.9)],
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _buildAuthorInfo() {
    return Row(
      children: [
        const CircleAvatar(radius: 16, backgroundColor: AppTheme.goldPrimary, child: Icon(Icons.person, size: 16, color: AppTheme.midnight)),
        const SizedBox(width: 12),
        const Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Text('Master Bot', style: TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold, fontSize: 14)),
            Text('Published on March 25, 2026', style: TextStyle(color: AppTheme.textMuted, fontSize: 11)),
          ],
        ),
        const Spacer(),
        _badge('FEATURED'),
      ],
    ).animate().fadeIn();
  }

  Widget _badge(String label) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(color: AppTheme.goldPrimary.withOpacity(0.1), borderRadius: BorderRadius.circular(8)),
      child: Text(label, style: const TextStyle(color: AppTheme.goldPrimary, fontSize: 10, fontWeight: FontWeight.w800)),
    );
  }

  Widget _buildContent() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text(
          'The Sicilian Defense is the most popular and best-scoring response to White\'s first move 1.e4.',
          style: TextStyle(color: AppTheme.textPrimary, fontSize: 18, fontWeight: FontWeight.w600, height: 1.5),
        ),
        const SizedBox(height: 20),
        const Text(
          'Why play the Sicilian?\n\n'
          '1. It\'s aggressive: Unlike the Petroff or Berlin, the Sicilian aims to win as Black from the start.\n'
          '2. Asymmetry: The pawn structure is imbalanced, creating more tactical opportunities.\n'
          '3. Versatility: From the Najdorf to the Dragon, there is a variation for every style.',
          style: TextStyle(color: AppTheme.textSecondary, fontSize: 15, height: 1.6),
        ),
        const SizedBox(height: 32),
        // A placeholder for a board diagram
         Container(
          height: 300,
          width: double.infinity,
          decoration: BoxDecoration(color: AppTheme.navyCard, borderRadius: BorderRadius.circular(20)),
          child: const Center(child: Icon(Icons.grid_4x4_rounded, size: 60, color: AppTheme.goldPrimary)),
        ),
        const SizedBox(height: 8),
        const Center(child: Text('Position after 1.e4 c5', style: TextStyle(color: AppTheme.textMuted, fontSize: 12))),
      ],
    ).animate().fadeIn(delay: 200.ms);
  }

  Widget _buildRelatedLessons() {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        const Text('Related Lessons', style: TextStyle(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.bold)),
        const SizedBox(height: 16),
        SizedBox(
          height: 140,
          child: ListView(
            scrollDirection: Axis.horizontal,
            children: [
              _relatedCard('The Najdorf Variation', '30 min'),
              _relatedCard('Sicilian Dragon Basics', '20 min'),
              _relatedCard('The Rossolimo Attack', '15 min'),
            ],
          ),
        ),
      ],
    ).animate().fadeIn(delay: 400.ms);
  }

  Widget _relatedCard(String title, String time) {
    return Container(
      width: 200,
      margin: const EdgeInsets.only(right: 16),
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(color: AppTheme.surface, borderRadius: BorderRadius.circular(16)),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(color: AppTheme.textPrimary, fontWeight: FontWeight.bold)),
          const Spacer(),
          Row(children: [
            const Icon(Icons.timer_rounded, size: 14, color: AppTheme.textMuted),
            const SizedBox(width: 4),
            Text(time, style: const TextStyle(color: AppTheme.textMuted, fontSize: 12)),
          ]),
        ],
      ),
    );
  }
}
