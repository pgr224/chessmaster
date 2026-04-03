import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../../data/models/tutorial_model.dart';

enum TutorialDifficulty { beginner, intermediate, advanced }

class TutorialScreen extends StatefulWidget {
  const TutorialScreen({super.key});

  @override
  State<TutorialScreen> createState() => _TutorialScreenState();
}

class _TutorialScreenState extends State<TutorialScreen> {
  late TutorialDifficulty _selectedDifficulty;

  @override
  void initState() {
    super.initState();
    _selectedDifficulty = TutorialDifficulty.beginner;
  }

  List<TutorialLesson> _getLessonsByDifficulty(TutorialDifficulty difficulty) {
    final prefix = difficulty.name;
    return tutorialLessons
        .where((lesson) => lesson.id.startsWith(prefix))
        .toList();
  }

  Color _getDifficultyColor(TutorialDifficulty difficulty) {
    switch (difficulty) {
      case TutorialDifficulty.beginner:
        return AppTheme.accentCyan;
      case TutorialDifficulty.intermediate:
        return Colors.orange;
      case TutorialDifficulty.advanced:
        return AppTheme.accentRed;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        leading: IconButton(
          icon:
              const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
          onPressed: () => context.pop(),
        ),
        title: Text('Chess Academy',
            style: GoogleFonts.fredoka(
                color: AppTheme.textPrimary, fontWeight: FontWeight.w700)),
        centerTitle: true,
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: Column(
            children: [
              // Difficulty Selector
              Padding(
                padding: const EdgeInsets.all(16),
                child: SingleChildScrollView(
                  scrollDirection: Axis.horizontal,
                  child: Row(
                    children: [
                      _buildDifficultyTab(
                          TutorialDifficulty.beginner, '🟢 Beginner'),
                      const SizedBox(width: 12),
                      _buildDifficultyTab(
                          TutorialDifficulty.intermediate, '🟡 Intermediate'),
                      const SizedBox(width: 12),
                      _buildDifficultyTab(
                          TutorialDifficulty.advanced, '🔴 Advanced'),
                    ],
                  ),
                ),
              ),
              // Lessons List
              Expanded(
                child: ListView.builder(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                  itemCount:
                      _getLessonsByDifficulty(_selectedDifficulty).length,
                  itemBuilder: (context, index) {
                    final lesson =
                        _getLessonsByDifficulty(_selectedDifficulty)[index];
                    return _buildLessonCard(context, lesson, index);
                  },
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _buildDifficultyTab(TutorialDifficulty difficulty, String label) {
    final isSelected = _selectedDifficulty == difficulty;
    final color = _getDifficultyColor(difficulty);

    return GestureDetector(
      onTap: () => setState(() => _selectedDifficulty = difficulty),
      child: AnimatedContainer(
        duration: 200.ms,
        padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 12),
        decoration: BoxDecoration(
          gradient: isSelected
              ? LinearGradient(colors: [
                  color.withOpacity(0.2),
                  color.withOpacity(0.05)
                ])
              : null,
          color: !isSelected ? AppTheme.surface.withOpacity(0.5) : null,
          borderRadius: BorderRadius.circular(16),
          border: Border.all(
            color:
                isSelected ? color : AppTheme.textMuted.withOpacity(0.2),
            width: isSelected ? 2 : 1,
          ),
        ),
        child: Text(
          label,
          style: GoogleFonts.fredoka(
            color: isSelected ? color : AppTheme.textSecondary,
            fontWeight: isSelected ? FontWeight.w700 : FontWeight.w600,
            fontSize: 14,
          ),
        ),
      ),
    ).animate().fadeIn();
  }

  Widget _buildLessonCard(
      BuildContext context, TutorialLesson lesson, int index) {
    final difficulty = _selectedDifficulty;
    final difficultyColor = _getDifficultyColor(difficulty);
    final stepCount = lesson.steps.length;

    return GestureDetector(
      onTap: () {
        context.push('/game/play',
            extra: GameRouteExtra(
              config: const GameConfig(mode: GameMode.tutorial),
              tutorial: lesson,
            ));
      },
      child: Container(
        margin: const EdgeInsets.only(bottom: 12),
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          gradient: AppTheme.cardGradient,
          borderRadius: BorderRadius.circular(20),
          border: Border.all(
              color: difficultyColor.withOpacity(0.15), width: 1.5),
          boxShadow: [
            BoxShadow(
                color: difficultyColor.withOpacity(0.08),
                blurRadius: 12,
                offset: const Offset(0, 4)),
          ],
        ),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                  width: 56,
                  height: 56,
                  decoration: BoxDecoration(
                    color: difficultyColor.withOpacity(0.12),
                    borderRadius: BorderRadius.circular(14),
                  ),
                  child: Center(
                    child: Text(
                      lesson.title.split(' ').first, // Use emoji from title
                      style: const TextStyle(fontSize: 28),
                    ),
                  ),
                ),
                const SizedBox(width: 16),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        lesson.title,
                        style: GoogleFonts.fredoka(
                          color: AppTheme.textPrimary,
                          fontSize: 16,
                          fontWeight: FontWeight.w700,
                        ),
                      ),
                      const SizedBox(height: 4),
                      Text(
                        lesson.description,
                        style: GoogleFonts.baloo2(
                            color: AppTheme.textSecondary, fontSize: 12),
                      ),
                    ],
                  ),
                ),
              ],
            ),
            const SizedBox(height: 14),
            Row(
              children: [
                Container(
                  padding:
                      const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
                  decoration: BoxDecoration(
                    color: difficultyColor.withOpacity(0.1),
                    borderRadius: BorderRadius.circular(8),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.layers_rounded,
                          size: 14, color: difficultyColor),
                      const SizedBox(width: 6),
                      Text(
                        '$stepCount ${stepCount == 1 ? 'Step' : 'Steps'}',
                        style: GoogleFonts.fredoka(
                          color: difficultyColor,
                          fontSize: 12,
                          fontWeight: FontWeight.w600,
                        ),
                      ),
                    ],
                  ),
                ),
                const Spacer(),
                Icon(Icons.arrow_forward_rounded,
                    color: AppTheme.textMuted, size: 20),
              ],
            ),
          ],
        ),
      ).animate().fadeIn(delay: (index * 80).ms).slideX(begin: 0.1),
    );
  }
}
