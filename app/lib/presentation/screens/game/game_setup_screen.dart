import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:go_router/go_router.dart';
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
  int? _timeControl; // null = no clock

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
                  icon: const Icon(Icons.arrow_back_rounded, color: AppTheme.textPrimary),
                  onPressed: () => context.pop(),
                ),
                title: const Text('New Game vs AI', style: TextStyle(color: AppTheme.textPrimary)),
                centerTitle: true,
              ),
              SliverPadding(
                padding: const EdgeInsets.all(20),
                sliver: SliverList(
                  delegate: SliverChildListDelegate([

                    // ── DIFFICULTY ──
                    _sectionCard(
                      title: 'Difficulty',
                      icon: Icons.psychology_rounded,
                      child: _buildDifficultySelector(),
                    ).animate().fadeIn(delay: 100.ms).slideY(begin: 0.1),

                    const SizedBox(height: 16),

                    // ── COLOR ──
                    _sectionCard(
                      title: 'Play As',
                      icon: Icons.swap_horiz_rounded,
                      child: _buildColorSelector(),
                    ).animate().fadeIn(delay: 200.ms).slideY(begin: 0.1),

                    const SizedBox(height: 16),

                    // ── BOARD THEME ──
                    _sectionCard(
                      title: 'Board Theme',
                      icon: Icons.palette_rounded,
                      child: _buildThemeSelector(),
                    ).animate().fadeIn(delay: 300.ms).slideY(begin: 0.1),

                    const SizedBox(height: 16),

                    // ── OPTIONS ──
                    _sectionCard(
                      title: 'Game Options',
                      icon: Icons.tune_rounded,
                      child: _buildOptions(),
                    ).animate().fadeIn(delay: 400.ms).slideY(begin: 0.1),

                    const SizedBox(height: 32),

                    // ── START ──
                    SizedBox(
                      width: double.infinity,
                      height: 56,
                      child: ElevatedButton.icon(
                        onPressed: _startGame,
                        icon: const Icon(Icons.play_arrow_rounded, size: 28),
                        label: const Text('Start Game', style: TextStyle(fontSize: 18, fontWeight: FontWeight.w800)),
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

  Widget _sectionCard({required String title, required IconData icon, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(20),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(20),
        border: Border.all(color: Colors.white.withOpacity(0.05)),
        boxShadow: AppTheme.cardShadow,
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(children: [
            Icon(icon, color: AppTheme.goldPrimary, size: 20),
            const SizedBox(width: 8),
            Text(title, style: const TextStyle(
              color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w700,
            )),
          ]),
          const SizedBox(height: 16),
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
            duration: 200.ms,
            margin: const EdgeInsets.only(bottom: 8),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.goldPrimary.withOpacity(0.15) : AppTheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.goldPrimary : Colors.transparent, width: 1.5,
              ),
            ),
            child: Row(children: [
              Text(info['emoji']!, style: const TextStyle(fontSize: 24)),
              const SizedBox(width: 12),
              Expanded(child: Column(crossAxisAlignment: CrossAxisAlignment.start, children: [
                Text(info['name']!, style: TextStyle(
                  color: isSelected ? AppTheme.goldPrimary : AppTheme.textPrimary,
                  fontWeight: FontWeight.w700, fontSize: 15,
                )),
                Text(info['desc']!, style: const TextStyle(color: AppTheme.textSecondary, fontSize: 12)),
              ])),
              if (isSelected)
                const Icon(Icons.check_circle_rounded, color: AppTheme.goldPrimary, size: 22),
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
            duration: 200.ms,
            margin: const EdgeInsets.symmetric(horizontal: 4),
            height: 72,
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.goldPrimary.withOpacity(0.15) : AppTheme.surface.withOpacity(0.5),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(color: isSelected ? AppTheme.goldPrimary : Colors.transparent, width: 1.5),
            ),
            child: Column(mainAxisAlignment: MainAxisAlignment.center, children: [
              Text(_colorEmoji(color), style: const TextStyle(fontSize: 24)),
              Text(_colorName(color), style: TextStyle(
                color: isSelected ? AppTheme.goldPrimary : AppTheme.textSecondary,
                fontSize: 11, fontWeight: FontWeight.w600,
              )),
            ]),
          ),
        ),
      );
    }).toList());
  }

  Widget _buildThemeSelector() {
    final themes = ['classic', 'wood', 'neon', 'minimal'];
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: themes.map((theme) {
        final isSelected = _boardTheme == theme;
        return GestureDetector(
          onTap: () => setState(() => _boardTheme = theme),
          child: AnimatedContainer(
            duration: 200.ms,
            margin: const EdgeInsets.only(right: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
            decoration: BoxDecoration(
              color: isSelected ? AppTheme.goldPrimary.withOpacity(0.2) : AppTheme.surface,
              borderRadius: BorderRadius.circular(12),
              border: Border.all(color: isSelected ? AppTheme.goldPrimary : Colors.transparent),
            ),
            child: Text(theme.capitalize(), style: TextStyle(
              color: isSelected ? AppTheme.goldPrimary : AppTheme.textSecondary,
              fontWeight: isSelected ? FontWeight.w700 : FontWeight.w400,
            )),
          ),
        );
      }).toList()),
    );
  }

  Widget _buildOptions() {
    return Column(children: [
      SwitchListTile(
        title: const Text('Enable Hints (max 3)', style: TextStyle(color: AppTheme.textPrimary)),
        subtitle: const Text('Get best move suggestions', style: TextStyle(color: AppTheme.textMuted, fontSize: 12)),
        value: _hintsEnabled,
        activeColor: AppTheme.goldPrimary,
        contentPadding: EdgeInsets.zero,
        onChanged: (v) => setState(() => _hintsEnabled = v),
      ),
    ]);
  }

  void _startGame() {
    context.go('/game/play', extra: GameConfig(
      mode: GameMode.singlePlayer,
      difficulty: _difficulty,
      playerColor: _playerColor == 'random' ? (DateTime.now().millisecond.isEven ? 'white' : 'black') : _playerColor,
      boardTheme: _boardTheme,
      hintsEnabled: _hintsEnabled,
    ));
  }

  Map<String, String> _difficultyInfo(AIDifficulty d) => switch (d) {
    AIDifficulty.basic        => {'emoji': '🌱', 'name': 'Basic', 'desc': 'Random moves, great for beginners'},
    AIDifficulty.intermediate => {'emoji': '⚔️', 'name': 'Intermediate', 'desc': 'Tactical play, moderate challenge'},
    AIDifficulty.advanced     => {'emoji': '🔬', 'name': 'Advanced', 'desc': 'Strategic depth, serious opponent'},
    AIDifficulty.impossible   => {'emoji': '🤖', 'name': 'Impossible', 'desc': 'Near-perfect engine play'},
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
