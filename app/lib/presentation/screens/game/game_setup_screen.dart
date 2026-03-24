import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';

class GameSetupScreen extends StatefulWidget {
  const GameSetupScreen({super.key});

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  AIDifficulty _difficulty = AIDifficulty.intermediate;
  String _playerColor = 'white';
  String _boardTheme = 'classic';
  bool _hintsEnabled = true;
  int? _timeControl;

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: SafeArea(
          child: CustomScrollView(
            slivers: [
              SliverAppBar(
                backgroundColor: Colors.transparent,
                elevation: 0,
                leading: IconButton(
                  icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary, size: 28),
                  onPressed: () => context.pop(),
                ),
                title: Text('🤖 New Game vs AI',
                  style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w600),
                ),
                centerTitle: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // ── DIFFICULTY ──
                    _sectionCard(
                      title: '🧠 Difficulty',
                      child: _buildDifficultySelector(),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

                    const SizedBox(height: 18),

                    // ── COLOR ──
                    _sectionCard(
                      title: '♟️ Play As',
                      child: _buildColorSelector(),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                    const SizedBox(height: 18),

                    // ── BOARD THEME ──
                    _sectionCard(
                      title: '🎨 Board Theme',
                      child: _buildThemeSelector(),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                    const SizedBox(height: 18),

                    // ── OPTIONS ──
                    _sectionCard(
                      title: '⚙️ Options',
                      child: _buildOptions(),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

                    const SizedBox(height: 36),

                    // ── BIG START BUTTON ──
                    SizedBox(
                      width: double.infinity,
                      height: 64,
                      child: ElevatedButton.icon(
                        onPressed: _startGame,
                        style: ElevatedButton.styleFrom(
                          backgroundColor: AppTheme.accentCyan,
                          foregroundColor: AppTheme.midnight,
                          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(22)),
                          elevation: 10,
                          shadowColor: AppTheme.accentCyan.withValues(alpha: 0.5),
                        ),
                        icon: const Icon(Icons.play_arrow_rounded, size: 34),
                        label: Text('Start Game! 🚀',
                          style: GoogleFonts.fredoka(fontSize: 22, fontWeight: FontWeight.w700),
                        ),
                      ),
                    ).animate().fadeIn(delay: 500.ms).scale(begin: const Offset(0.9, 0.9)),
                  ]),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(22),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(24),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: GoogleFonts.fredoka(
            color: AppTheme.textPrimary, fontSize: 20, fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 18),
          child,
        ],
      ),
    );
  }

  Widget _buildDifficultySelector() {
    return Column(
      children: AIDifficulty.values.map((d) {
        final isSelected = d == _difficulty;
        final info = _difficultyInfo(d);
        return GestureDetector(
          onTap: () => setState(() => _difficulty = d),
          child: AnimatedContainer(
            duration: 250.ms,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 18, vertical: 16),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.goldPrimary.withValues(alpha: 0.18)
                  : AppTheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.goldPrimary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(children: [
              Text(info['emoji']!, style: const TextStyle(fontSize: 30)),
              const SizedBox(width: 14),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info['name']!, style: GoogleFonts.fredoka(
                  color: isSelected ? AppTheme.goldPrimary : AppTheme.textPrimary,
                  fontWeight: FontWeight.w600, fontSize: 18,
                )),
                Text(info['desc']!, style: GoogleFonts.baloo2(
                  color: AppTheme.textSecondary, fontSize: 14,
                )),
              ])),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: AppTheme.goldPrimary, size: 26),
            ]),
          ),
        );
      }).toList(),
    );
  }

  Widget _buildColorSelector() {
    return Row(children: ['white', 'random', 'black'].map((color) {
      final isSelected = _playerColor == color;
      return Expanded(
        child: GestureDetector(
          onTap: () => setState(() => _playerColor = color),
          child: AnimatedContainer(
            duration: 250.ms,
            margin: const EdgeInsets.symmetric(horizontal: 5),
            height: 88,
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.goldPrimary.withValues(alpha: 0.18)
                  : AppTheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(20),
              border: Border.all(
                color: isSelected ? AppTheme.goldPrimary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_colorEmoji(color), style: const TextStyle(fontSize: 32)),
              const SizedBox(height: 6),
              Text(_colorName(color), style: GoogleFonts.fredoka(
                color: isSelected ? AppTheme.goldPrimary : AppTheme.textSecondary,
                fontSize: 14, fontWeight: FontWeight.w600,
              )),
            ]),
          ),
        ),
      );
    }).toList());
  }

  Widget _buildThemeSelector() {
    final themes = ['classic', 'wood', 'neon', 'minimal'];
    final themeEmoji = {'classic': '♜', 'wood': '🪵', 'neon': '💜', 'minimal': '⬜'};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: themes.map((theme) {
        final isSelected = _boardTheme == theme;
        return GestureDetector(
          onTap: () => setState(() => _boardTheme = theme),
          child: AnimatedContainer(
            duration: 250.ms,
            margin: const EdgeInsets.only(right: 12),
            padding: const EdgeInsets.symmetric(horizontal: 20, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.goldPrimary.withValues(alpha: 0.2)
                  : AppTheme.surface,
              borderRadius: BorderRadius.circular(16),
              border: Border.all(
                color: isSelected ? AppTheme.goldPrimary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                Text(themeEmoji[theme] ?? '', style: const TextStyle(fontSize: 18)),
                const SizedBox(width: 8),
                Text(theme.capitalize(), style: GoogleFonts.fredoka(
                  color: isSelected ? AppTheme.goldPrimary : AppTheme.textSecondary,
                  fontWeight: FontWeight.w600, fontSize: 16,
                )),
              ],
            ),
          ),
        );
      }).toList()),
    );
  }

  Widget _buildOptions() {
    return SwitchListTile(
      title: Text('💡 Enable Hints (max 3)', style: GoogleFonts.fredoka(
        color: AppTheme.textPrimary, fontSize: 17,
      )),
      subtitle: Text('Get best move suggestions!', style: GoogleFonts.baloo2(
        color: AppTheme.textMuted, fontSize: 14,
      )),
      value: _hintsEnabled,
      activeColor: AppTheme.goldPrimary,
      contentPadding: EdgeInsets.zero,
      onChanged: (v) => setState(() => _hintsEnabled = v),
    );
  }

  void _startGame() {
    context.go('/game/play', extra: GameConfig(
      mode: GameMode.singlePlayer,
      difficulty: _difficulty,
      playerColor: _playerColor == 'random'
          ? (DateTime.now().millisecond.isEven ? 'white' : 'black')
          : _playerColor,
      boardTheme: _boardTheme,
      hintsEnabled: _hintsEnabled,
    ));
  }

  Map<String, String> _difficultyInfo(AIDifficulty d) => switch (d) {
    AIDifficulty.basic        => {'emoji': '🌱', 'name': 'Easy', 'desc': 'Perfect for beginners!'},
    AIDifficulty.intermediate => {'emoji': '⚔️', 'name': 'Medium', 'desc': 'A good challenge!'},
    AIDifficulty.advanced     => {'emoji': '🔥', 'name': 'Hard', 'desc': 'Serious play!'},
    AIDifficulty.impossible   => {'emoji': '🤖', 'name': 'Impossible', 'desc': 'Can you beat the machine?'},
  };

  String _colorEmoji(String color) => switch (color) {
    'white'  => '♔', 'black' => '♚', _ => '🎲',
  };
  String _colorName(String color) => switch (color) {
    'white'  => 'White', 'black' => 'Black', _ => 'Random',
  };
}

extension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
