import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:go_router/go_router.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../core/router/app_router.dart';
import '../../blocs/theme/theme_bloc.dart';

class GameSetupScreen extends StatefulWidget {
  const GameSetupScreen({super.key});

  @override
  State<GameSetupScreen> createState() => _GameSetupScreenState();
}

class _GameSetupScreenState extends State<GameSetupScreen> {
  AIDifficulty _difficulty = AIDifficulty.intermediate;
  String _playerColor = 'white';
  String _customStartColor = 'white';
  Color _whitePieceColor = Colors.white;
  Color _blackPieceColor = Colors.black;
  String _boardTheme = 'classic';
  String _pieceTheme = 'classic3d';
  bool _hintsEnabled = true;
  int? _timeControl;
  bool _loadedThemePrefs = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedThemePrefs) return;
    final themeState = context.read<ThemeBloc>().state;
    _boardTheme = themeState.boardTheme;
    _pieceTheme = themeState.pieceTheme == 'classic' ? 'classic3d' : themeState.pieceTheme;
    _loadedThemePrefs = true;
  }

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

                    _sectionCard(
                      title: '🧩 Piece Style',
                      child: _buildPieceStyleSelector(),
                    ).animate().fadeIn(delay: 350.ms).slideY(begin: 0.1),

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
    return Column(
      children: [
        Row(children: ['white', 'custom', 'black'].map((color) {
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
        }).toList()),
        if (_playerColor == 'custom') ...[
          const SizedBox(height: 14),
          _buildCustomColorControls(),
        ],
      ],
    );
  }

  Widget _buildCustomColorControls() {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: AppTheme.surface.withValues(alpha: 0.45),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldPrimary.withValues(alpha: 0.2)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('Custom Piece Colors', style: GoogleFonts.fredoka(
            color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600,
          )),
          const SizedBox(height: 10),
          Row(
            children: [
              Expanded(child: _colorPill('Start As', _customStartColor == 'white' ? AppTheme.boardThemes['classic']!.light : AppTheme.boardThemes['classic']!.dark, () {
                setState(() {
                  _customStartColor = _customStartColor == 'white' ? 'black' : 'white';
                });
              }, labelSuffix: _customStartColor.capitalize())),
              const SizedBox(width: 10),
              Expanded(child: _colorPill('White Pieces', _whitePieceColor, () async {
                final picked = await _pickColor(context, _whitePieceColor);
                if (picked != null) setState(() => _whitePieceColor = picked);
              })),
              const SizedBox(width: 10),
              Expanded(child: _colorPill('Black Pieces', _blackPieceColor, () async {
                final picked = await _pickColor(context, _blackPieceColor);
                if (picked != null) setState(() => _blackPieceColor = picked);
              })),
            ],
          ),
          const SizedBox(height: 8),
          Text('Tap a color chip to choose your custom palette.', style: GoogleFonts.baloo2(
            color: AppTheme.textMuted, fontSize: 12,
          )),
        ],
      ),
    );
  }

  Widget _colorPill(String label, Color color, VoidCallback onTap, {String? labelSuffix}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        height: 64,
        padding: const EdgeInsets.symmetric(horizontal: 8),
        decoration: BoxDecoration(
          color: color.withValues(alpha: 0.22),
          borderRadius: BorderRadius.circular(14),
          border: Border.all(color: color.withValues(alpha: 0.9), width: 2),
        ),
        child: Center(
          child: Text(
            labelSuffix == null ? label : '$label\n$labelSuffix',
            textAlign: TextAlign.center,
            style: GoogleFonts.fredoka(
              color: AppTheme.textPrimary,
              fontSize: 12,
              fontWeight: FontWeight.w600,
              height: 1.1,
            ),
          ),
        ),
      ),
    );
  }

  Future<Color?> _pickColor(BuildContext context, Color initial) async {
    const swatches = [
      Color(0xFFFFFFFF), Color(0xFF111111), Color(0xFFFFD93D), Color(0xFF6BCB77),
      Color(0xFF74B9FF), Color(0xFFFF6B9D), Color(0xFFFF8A5C), Color(0xFFA29BFE),
      Color(0xFFF5E6CA), Color(0xFF8B6B4A), Color(0xFF2ECC71), Color(0xFFE74C3C),
    ];
    Color selected = initial;

    return showDialog<Color>(
      context: context,
      builder: (ctx) => AlertDialog(
        backgroundColor: AppTheme.navyCard,
        title: Text('Pick Color', style: GoogleFonts.fredoka(color: AppTheme.textPrimary)),
        content: StatefulBuilder(
          builder: (context, setLocalState) {
            return SizedBox(
              width: 280,
              child: Wrap(
                spacing: 10,
                runSpacing: 10,
                children: swatches.map((c) {
                  final isSelected = c.value == selected.value;
                  return GestureDetector(
                    onTap: () => setLocalState(() => selected = c),
                    child: Container(
                      width: 36,
                      height: 36,
                      decoration: BoxDecoration(
                        color: c,
                        shape: BoxShape.circle,
                        border: Border.all(
                          color: isSelected ? AppTheme.goldPrimary : Colors.white24,
                          width: isSelected ? 3 : 1,
                        ),
                      ),
                    ),
                  );
                }).toList(),
              ),
            );
          },
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(ctx),
            child: Text('Cancel', style: GoogleFonts.fredoka(color: AppTheme.textMuted)),
          ),
          ElevatedButton(
            onPressed: () => Navigator.pop(ctx, selected),
            child: Text('Apply', style: GoogleFonts.fredoka(color: AppTheme.midnight)),
          ),
        ],
      ),
    );
  }

  Widget _buildThemeSelector() {
    final themes = ['classic', 'wood', 'neon', 'minimal'];
    final themeEmoji = {'classic': '♜', 'wood': '🪵', 'neon': '💜', 'minimal': '⬜'};
    return SingleChildScrollView(
      scrollDirection: Axis.horizontal,
      child: Row(children: themes.map((theme) {
        final isSelected = _boardTheme == theme;
        return GestureDetector(
          onTap: () {
            setState(() => _boardTheme = theme);
            context.read<ThemeBloc>().add(
              ThemeChangeEvent(boardTheme: _boardTheme, pieceTheme: _pieceTheme),
            );
          },
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

  Widget _buildPieceStyleSelector() {
    final styles = [
      {'id': 'classic3d', 'name': 'Classic 3D', 'emoji': '♔', 'desc': 'Balanced glossy look'},
      {'id': 'marble3d', 'name': 'Marble 3D', 'emoji': '◈', 'desc': 'Smooth stone finish'},
      {'id': 'metal3d', 'name': 'Metal 3D', 'emoji': '⚙', 'desc': 'Polished metallic style'},
    ];

    return Column(
      children: styles.map((style) {
        final id = style['id']!;
        final isSelected = _pieceTheme == id;
        return GestureDetector(
          onTap: () {
            setState(() => _pieceTheme = id);
            context.read<ThemeBloc>().add(
              ThemeChangeEvent(boardTheme: _boardTheme, pieceTheme: _pieceTheme),
            );
          },
          child: AnimatedContainer(
            duration: 250.ms,
            margin: const EdgeInsets.only(bottom: 10),
            padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
            decoration: BoxDecoration(
              color: isSelected
                  ? AppTheme.goldPrimary.withValues(alpha: 0.16)
                  : AppTheme.surface.withValues(alpha: 0.5),
              borderRadius: BorderRadius.circular(18),
              border: Border.all(
                color: isSelected ? AppTheme.goldPrimary : Colors.transparent,
                width: 2,
              ),
            ),
            child: Row(
              children: [
                _pieceStylePreview(id),
                const SizedBox(width: 12),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        children: [
                          Text(style['emoji']!, style: const TextStyle(fontSize: 16)),
                          const SizedBox(width: 6),
                          Text(style['name']!, style: GoogleFonts.fredoka(
                            color: isSelected ? AppTheme.goldPrimary : AppTheme.textPrimary,
                            fontWeight: FontWeight.w600,
                            fontSize: 16,
                          )),
                        ],
                      ),
                      Text(style['desc']!, style: GoogleFonts.baloo2(
                        color: AppTheme.textSecondary,
                        fontSize: 13,
                      )),
                    ],
                  ),
                ),
                if (isSelected)
                  const Icon(Icons.check_circle_rounded, color: AppTheme.goldPrimary, size: 24),
              ],
            ),
          ),
        );
      }).toList(),
    );
  }

  Widget _pieceStylePreview(String styleId) {
    final left = _previewColors(styleId, isWhite: true);
    final right = _previewColors(styleId, isWhite: false);

    return SizedBox(
      width: 56,
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceBetween,
        children: [
          _miniKingToken(gradient: left.$1, glyphColor: left.$2),
          _miniKingToken(gradient: right.$1, glyphColor: right.$2),
        ],
      ),
    );
  }

  (Gradient, Color) _previewColors(String styleId, {required bool isWhite}) {
    if (styleId == 'marble3d') {
      final base = isWhite ? const Color(0xFFF1F3F6) : const Color(0xFFCDD3DE);
      return (
        RadialGradient(
          center: const Alignment(-0.2, -0.3),
          colors: [
            Color.lerp(base, Colors.white, 0.35)!,
            base,
            Color.lerp(base, const Color(0xFF667085), 0.35)!,
          ],
          stops: const [0.0, 0.58, 1.0],
        ),
        const Color(0xFF2A3240),
      );
    }

    if (styleId == 'metal3d') {
      final base = isWhite ? const Color(0xFFBFC8D6) : const Color(0xFF6C7689);
      return (
        RadialGradient(
          center: const Alignment(-0.25, -0.35),
          colors: [
            Color.lerp(base, Colors.white, 0.42)!,
            base,
            Color.lerp(base, const Color(0xFF1F2A37), 0.45)!,
          ],
          stops: const [0.0, 0.57, 1.0],
        ),
        Colors.white.withValues(alpha: 0.9),
      );
    }

    // classic3d
    final base = isWhite ? const Color(0xFFECECEC) : const Color(0xFF2C2C2C);
    return (
      RadialGradient(
        center: const Alignment(-0.2, -0.3),
        colors: [
          Color.lerp(base, Colors.white, 0.3)!,
          base,
          Color.lerp(base, Colors.black, 0.32)!,
        ],
        stops: const [0.0, 0.58, 1.0],
      ),
      isWhite ? const Color(0xFF1B1B1B) : Colors.white,
    );
  }

  Widget _miniKingToken({required Gradient gradient, required Color glyphColor}) {
    return Container(
      width: 24,
      height: 24,
      decoration: BoxDecoration(
        shape: BoxShape.circle,
        gradient: gradient,
        border: Border.all(color: glyphColor.withValues(alpha: 0.22), width: 1),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.2),
            blurRadius: 3,
            offset: const Offset(0, 1),
          ),
        ],
      ),
      alignment: Alignment.center,
      child: CustomPaint(
        size: const Size.square(12),
        painter: _MiniKingPainter(
          fill: glyphColor.withValues(alpha: 0.95),
          stroke: glyphColor.withValues(alpha: 0.22),
        ),
      ),
    );
  }
  void _startGame() {
    final useCustomColors = _playerColor == 'custom';
    final resolvedColor = useCustomColors ? _customStartColor : _playerColor;

    context.go('/game/play', extra: GameConfig(
      mode: GameMode.singlePlayer,
      difficulty: _difficulty,
      playerColor: resolvedColor,
      boardTheme: _boardTheme,
      pieceTheme: _pieceTheme,
      whitePieceColor: useCustomColors ? _whitePieceColor : null,
      blackPieceColor: useCustomColors ? _blackPieceColor : null,
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
    'white'  => '♔', 'black' => '♚', _ => '🎨',
  };
  String _colorName(String color) => switch (color) {
    'white'  => 'White', 'black' => 'Black', _ => 'Custom',
  };
}

class _MiniKingPainter extends CustomPainter {
  final Color fill;
  final Color stroke;

  const _MiniKingPainter({required this.fill, required this.stroke});

  @override
  void paint(Canvas canvas, Size s) {
    final p = Path();
    final w = s.width;
    final h = s.height;

    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.45, h * 0.06, w * 0.1, h * 0.18),
      Radius.circular(w * 0.03),
    ));
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.39, h * 0.11, w * 0.22, h * 0.08),
      Radius.circular(w * 0.03),
    ));
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.34, h * 0.24, w * 0.32, h * 0.35),
      Radius.circular(w * 0.08),
    ));
    p.addRRect(RRect.fromRectAndRadius(
      Rect.fromLTWH(w * 0.25, h * 0.62, w * 0.5, h * 0.2),
      Radius.circular(w * 0.08),
    ));

    final fillPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = fill;
    final strokePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = w * 0.04
      ..color = stroke;

    canvas.drawPath(p, fillPaint);
    canvas.drawPath(p, strokePaint);
  }

  @override
  bool shouldRepaint(covariant _MiniKingPainter oldDelegate) {
    return oldDelegate.fill != fill || oldDelegate.stroke != stroke;
  }
}

extension on String {
  String capitalize() => isEmpty ? this : '${this[0].toUpperCase()}${substring(1)}';
}
