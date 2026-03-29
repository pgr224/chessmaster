import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:flutter_svg/flutter_svg.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/settings/settings_bloc.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../profile/profile_screen.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _boardTheme;
  late String _pieceShape;
  late String _pieceStyle;
  bool _loadedTheme = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedTheme) return;
    final themeState = context.read<ThemeBloc>().state;
    _boardTheme = themeState.boardTheme;
    _pieceShape = themeState.pieceShape;
    _pieceStyle = themeState.pieceStyle;
    _loadedTheme = true;
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppTheme.midnight,
      appBar: AppBar(
        backgroundColor: Colors.transparent,
        elevation: 0,
        title: Text(
          'Settings',
          style: GoogleFonts.fredoka(
            color: AppTheme.textPrimary,
            fontWeight: FontWeight.w700,
          ),
        ),
      ),
      body: Container(
        decoration: const BoxDecoration(gradient: AppTheme.backgroundGradient),
        child: BlocBuilder<SettingsBloc, SettingsState>(
          builder: (context, settings) {
            return ListView(
              padding: const EdgeInsets.all(16),
              children: [
                BlocBuilder<AuthBloc, AuthState>(
                  builder: (context, authState) {
                    final user = authState is AuthAuthenticatedState ? authState.user : null;
                    return _sectionCard(
                      title: 'General',
                      child: Column(
                        children: [
                          _listTile(
                            icon: Icons.person_outline_rounded,
                            title: 'Profile Settings',
                            subtitle: 'Username, avatar, and account info',
                            onTap: () {
                              if (user != null) {
                                showEditProfileModal(context, user);
                              }
                            },
                          ),
                          _switchTile(
                            title: 'Notifications',
                            subtitle: 'Match invites and multiplayer updates',
                            value: settings.notificationsEnabled,
                            onChanged: (v) => context.read<SettingsBloc>().add(SettingsNotificationsEvent(v)),
                          ),
                        ],
                      ),
                    );
                  },
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: 'Theme',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _subTitle('Board Theme'),
                      const SizedBox(height: 10),
                      _buildBoardThemeChips(),
                      const SizedBox(height: 14),
                      _subTitle('Piece Shape'),
                      const SizedBox(height: 10),
                      _buildPieceShapeChips(),
                      const SizedBox(height: 20),
                      _subTitle('Piece Style'),
                      const SizedBox(height: 10),
                      _buildPieceStyleChips(),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: 'Board & Play',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _subTitle('Move Animation Speed'),
                      const SizedBox(height: 8),
                      _buildAnimationSpeedChips(settings.moveAnimationSpeed),
                      const SizedBox(height: 6),
                      _switchTile(
                        title: 'Show Coordinates',
                        subtitle: 'Display ranks/files on the board edge',
                        value: settings.showCoordinates,
                        onChanged: (v) => context.read<SettingsBloc>().add(SettingsShowCoordinatesEvent(v)),
                      ),
                      _switchTile(
                        title: 'Show Legal Move Dots',
                        subtitle: 'Display target hints for selected pieces',
                        value: settings.showLegalMoves,
                        onChanged: (v) => context.read<SettingsBloc>().add(SettingsShowLegalMovesEvent(v)),
                      ),
                      _switchTile(
                        title: 'Confirm Moves',
                        subtitle: 'Tap twice or press check to move',
                        value: settings.confirmMoves,
                        onChanged: (v) => context.read<SettingsBloc>().add(SettingsConfirmMovesEvent(v)),
                      ),
                      _switchTile(
                        title: 'Auto-Queen',
                        subtitle: 'Always promote pawns to queen',
                        value: settings.autoQueen,
                        onChanged: (v) => context.read<SettingsBloc>().add(SettingsAutoQueenEvent(v)),
                      ),
                      _switchTile(
                        title: 'Auto-Flip Board (2 Player)',
                        subtitle: 'Rotate board to side-to-move in local games',
                        value: settings.autoFlipBoard,
                        onChanged: (v) => context.read<SettingsBloc>().add(SettingsAutoFlipBoardEvent(v)),
                      ),
                      _switchTile(
                        title: 'Confirm Before Resign',
                        subtitle: 'Show confirmation dialog before resigning',
                        value: settings.confirmResign,
                        onChanged: (v) => context.read<SettingsBloc>().add(SettingsConfirmResignEvent(v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: 'Audio & Haptics',
                  child: Column(
                    children: [
                      _switchTile(
                        title: 'Sound Effects',
                        subtitle: 'Move, check, and game result sounds',
                        value: settings.soundEnabled,
                        onChanged: (v) => context.read<SettingsBloc>().add(SettingsSoundEvent(v)),
                      ),
                      _switchTile(
                        title: 'Vibration',
                        subtitle: 'Haptic feedback on check and actions',
                        value: settings.vibrationEnabled,
                        onChanged: (v) => context.read<SettingsBloc>().add(SettingsVibrationEvent(v)),
                      ),
                    ],
                  ),
                ),
                const SizedBox(height: 14),
                _sectionCard(
                  title: 'Background',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _subTitle('App Background'),
                      const SizedBox(height: 10),
                      _buildBackgroundThemeChips(settings.backgroundTheme),
                    ],
                  ),
                ),
              ],
            );
          },
        ),
      ),
    );
  }

  Widget _sectionCard({required String title, required Widget child}) {
    return Container(
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        gradient: AppTheme.cardGradient,
        borderRadius: BorderRadius.circular(18),
        border: Border.all(color: Colors.white.withValues(alpha: 0.06)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: GoogleFonts.fredoka(
              color: AppTheme.textPrimary,
              fontSize: 18,
              fontWeight: FontWeight.w700,
            ),
          ),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }

  Widget _subTitle(String text) {
    return Text(
      text,
      style: GoogleFonts.fredoka(
        color: AppTheme.textSecondary,
        fontSize: 14,
        fontWeight: FontWeight.w600,
      ),
    );
  }

  Widget _buildBoardThemeChips() {
    final themes = ['classic', 'grey', 'dark', 'amoled', 'lewis', 'cherry', 'sage', 'tan', 'jade'];
    final emoji = {
      'classic': '🟫', 'grey': '⬜', 'dark': '⬛', 'amoled': '🌑', 
      'lewis': '📽️', 'cherry': '🍒', 'sage': '🌿', 'tan': '🏜️', 'jade': '🐉'
    };
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: themes.map((t) {
        final selected = _boardTheme == t;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) {
            setState(() => _boardTheme = t);
            context.read<ThemeBloc>().add(ThemeChangeEvent(
              boardTheme: _boardTheme, 
              pieceShape: _pieceShape,
              pieceStyle: _pieceStyle
            ));
          },
          label: Text('${emoji[t] ?? '♟'} ${_cap(t)}', style: GoogleFonts.fredoka(fontSize: 12)),
          labelStyle: TextStyle(color: selected ? AppTheme.midnight : AppTheme.textPrimary),
          selectedColor: AppTheme.goldPrimary,
          backgroundColor: AppTheme.surface.withValues(alpha: 0.7),
        );
      }).toList(),
    );
  }

  Widget _buildPieceShapeChips() {
    final shapes = [
      {'id': 'classic', 'name': 'Classic'},
      {'id': 'modern', 'name': 'Modern'},
      {'id': 'angular', 'name': 'Angular'},
      {'id': 'neo', 'name': 'Neo'},
      {'id': 'wood', 'name': 'Wood'},
      {'id': 'fantasy', 'name': 'Fantasy'},
      {'id': 'iconic', 'name': 'Iconic SVG'},
      {'id': 'artwork', 'name': 'Artwork SVG'},
      {'id': 'shuffled', 'name': '🔀 SHUFFLE'},
    ];
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Wrap(
          spacing: 8, runSpacing: 8,
          children: shapes.map((s) {
            final id = s['id']!;
            final selected = _pieceShape == id;
            return ChoiceChip(
              selected: selected,
              onSelected: (_) {
                setState(() => _pieceShape = id);
                context.read<ThemeBloc>().add(ThemeChangeEvent(
                  boardTheme: _boardTheme, 
                  pieceShape: _pieceShape, 
                  pieceStyle: _pieceStyle
                ));
              },
              label: Text(s['name']!, style: GoogleFonts.fredoka(fontSize: 12)),
              labelStyle: TextStyle(
                color: selected ? AppTheme.midnight : AppTheme.textPrimary,
                fontWeight: id == 'shuffled' ? FontWeight.w800 : FontWeight.w500,
              ),
              selectedColor: id == 'shuffled' ? AppTheme.accentCyan : AppTheme.goldPrimary,
            );
          }).toList(),
        ),
        const SizedBox(height: 12),
        _glassButton(
          icon: Icons.grid_view_rounded,
          label: 'Browse 49+ PyChess Shapes',
          onTap: () => _showPychessSelector(context),
        ),
      ],
    );
  }

  Widget _glassButton({required IconData icon, required String label, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withValues(alpha: 0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withValues(alpha: 0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.skyBlue, size: 20),
            const SizedBox(width: 10),
            Text(label, style: GoogleFonts.fredoka(color: AppTheme.skyBlue, fontSize: 13, fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showPychessSelector(BuildContext context) {
    final List<String> pychessShapes = [
      'alfonso', 'alila', 'alpha', 'atopdown', 'california', 'cardinal', 'cburnett',
      'celtic', 'chess7', 'chessicons', 'chessmonk', 'chessnut', 'companion',
      'dubrovny', 'eyes', 'fantasy', 'fantasy_alt', 'freak', 'freestaunton',
      'fresca', 'gioco', 'governor', 'horsey', 'icpieces', 'kilfiger', 'kosal',
      'leipzig', 'letter', 'libra', 'maestro', 'magnetic', 'makruk', 'maya',
      'merida', 'merida_new', 'metaltops', 'pirat', 'pirouetti', 'pixel', 'prmi',
      'regular', 'reillycraig', 'riohacha', 'shapes', 'sittuyin', 'skulls',
      'spatial', 'staunty', 'tatiana'
    ];

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.75,
        decoration: BoxDecoration(
          color: AppTheme.midnight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppTheme.skyBlue.withValues(alpha: 0.2)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Text('PyChess Shapes', style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.w700)),
                  const Spacer(),
                  _glassAction(icon: Icons.close_rounded, size: 32, onTap: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2, crossAxisSpacing: 16, mainAxisSpacing: 16, childAspectRatio: 1.1,
                ),
                itemCount: pychessShapes.length,
                itemBuilder: (context, index) {
                  final s = pychessShapes[index];
                  final isSelected = _pieceShape == s;
                  return GestureDetector(
                    onTap: () {
                      setState(() => _pieceShape = s);
                      context.read<ThemeBloc>().add(ThemeChangeEvent(
                        boardTheme: _boardTheme, 
                        pieceShape: _pieceShape, 
                        pieceStyle: _pieceStyle
                      ));
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.goldPrimary.withValues(alpha: 0.1) : AppTheme.surface.withValues(alpha: 0.4),
                        borderRadius: BorderRadius.circular(16),
                        border: Border.all(color: isSelected ? AppTheme.goldPrimary : Colors.white12, width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _pychessPreview(s),
                          const SizedBox(height: 8),
                          Text(_cap(s), style: GoogleFonts.fredoka(color: isSelected ? AppTheme.goldPrimary : AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.w600)),
                        ],
                      ),
                    ),
                  );
                },
              ),
            ),
          ],
        ),
      ),
    );
  }

  Widget _pychessPreview(String shape) {
    return Container(
      padding: const EdgeInsets.all(8),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _svgIcon(shape, 'wk', 40),
              const SizedBox(width: 8),
              _svgIcon(shape, 'wb', 40),
            ],
          ),
          const SizedBox(height: 8),
          Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              _svgIcon(shape, 'wn', 40),
              const SizedBox(width: 8),
              _svgIcon(shape, 'wr', 40),
            ],
          ),
        ],
      ),
    );
  }

  Widget _svgIcon(String shape, String piece, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withValues(alpha: 0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: SvgPicture.asset(
        'assets/pieces/pychess/$shape/$piece.svg',
        width: size * 0.8, height: size * 0.8,
        errorBuilder: (context, error, stackTrace) => Icon(Icons.help_outline_rounded, color: Colors.white24, size: size * 0.6),
      ),
    );
  }

  Widget _glassAction({required IconData icon, required double size, required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(color: Colors.white.withValues(alpha: 0.1), shape: BoxShape.circle),
        child: Icon(icon, color: AppTheme.textPrimary, size: size - 12),
      ),
    );
  }

  Widget _buildPieceStyleChips() {
    final styles = [
      {'id': '3d', 'name': 'Classic 3D'},
      {'id': 'neon', 'name': 'Neon'},
      {'id': 'metal', 'name': 'Metallic Gold'},
      {'id': 'flat', 'name': 'Minimal Flat'},
      {'id': 'glass', 'name': 'Glass / Crystal'},
      {'id': 'wood', 'name': 'Classic Wood'},
      {'id': 'luxury', 'name': 'Luxury Gold & Black'},
      {'id': 'royal', 'name': 'Royal'},
    ];
    return Wrap(
      spacing: 8, runSpacing: 8,
      children: styles.map((s) {
        final id = s['id']!;
        final selected = _pieceStyle == id;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) {
            setState(() => _pieceStyle = id);
            context.read<ThemeBloc>().add(ThemeChangeEvent(
              boardTheme: _boardTheme, 
              pieceShape: _pieceShape, 
              pieceStyle: _pieceStyle
            ));
          },
          label: Text(s['name']!, style: GoogleFonts.fredoka(fontSize: 12)),
          labelStyle: TextStyle(color: selected ? AppTheme.midnight : AppTheme.textPrimary),
          selectedColor: AppTheme.goldPrimary,
        );
      }).toList(),
    );
  }

  Widget _buildAnimationSpeedChips(String selectedSpeed) {
    const options = [
      {'id': 'off', 'label': 'Off'},
      {'id': 'normal', 'label': 'Normal'},
      {'id': 'fast', 'label': 'Fast'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: options.map((opt) {
        final id = opt['id']!;
        final selected = selectedSpeed == id;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) => context.read<SettingsBloc>().add(SettingsMoveAnimationSpeedEvent(id)),
          label: Text(opt['label']!, style: GoogleFonts.fredoka()),
          labelStyle: TextStyle(color: selected ? AppTheme.midnight : AppTheme.textPrimary),
          selectedColor: AppTheme.goldPrimary,
          backgroundColor: AppTheme.surface.withValues(alpha: 0.7),
        );
      }).toList(),
    );
  }

  Widget _listTile({
    required IconData icon,
    required String title,
    required String subtitle,
    required VoidCallback onTap,
  }) {
    return ListTile(
      onTap: onTap,
      contentPadding: EdgeInsets.zero,
      leading: Container(
        padding: const EdgeInsets.all(8),
        decoration: BoxDecoration(
          color: AppTheme.goldPrimary.withValues(alpha: 0.1),
          shape: BoxShape.circle,
        ),
        child: Icon(icon, color: AppTheme.goldPrimary, size: 22),
      ),
      title: Text(
        title,
        style: GoogleFonts.fredoka(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.baloo2(
          color: AppTheme.textMuted,
          fontSize: 12,
        ),
      ),
      trailing: const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
    );
  }

  Widget _switchTile({
    required String title,
    required String subtitle,
    required bool value,
    required ValueChanged<bool> onChanged,
  }) {
    return SwitchListTile.adaptive(
      value: value,
      onChanged: onChanged,
      contentPadding: EdgeInsets.zero,
      activeThumbColor: AppTheme.goldPrimary,
      title: Text(
        title,
        style: GoogleFonts.fredoka(
          color: AppTheme.textPrimary,
          fontSize: 16,
          fontWeight: FontWeight.w600,
        ),
      ),
      subtitle: Text(
        subtitle,
        style: GoogleFonts.baloo2(
          color: AppTheme.textMuted,
          fontSize: 12,
        ),
      ),
    );
  }

  String _cap(String s) => s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _buildBackgroundThemeChips(String selected) {
    final themes = <Map<String, dynamic>>[
      {'id': 'midnight', 'label': '🌙 Midnight', 'colors': <Color>[const Color(0xFF1A1A2E), const Color(0xFF0F3460)]},
      {'id': 'ocean', 'label': '🌊 Ocean', 'colors': <Color>[const Color(0xFF0D1B2A), const Color(0xFF006D77)]},
      {'id': 'forest', 'label': '🌿 Forest', 'colors': <Color>[const Color(0xFF1A1C16), const Color(0xFF2D6A4F)]},
      {'id': 'sunset', 'label': '🌅 Sunset', 'colors': <Color>[const Color(0xFF2D1B33), const Color(0xFF6B1D3F)]},
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: themes.map((t) {
        final id = t['id'] as String;
        final isSelected = selected == id;
        final colors = (t['colors'] as List).cast<Color>();
        return GestureDetector(
          onTap: () => context.read<SettingsBloc>().add(SettingsBackgroundEvent(id)),
          child: AnimatedContainer(
            duration: const Duration(milliseconds: 200),
            width: 145,
            padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
            decoration: BoxDecoration(
              gradient: LinearGradient(colors: colors),
              borderRadius: BorderRadius.circular(14),
              border: Border.all(
                color: isSelected ? AppTheme.goldPrimary : Colors.transparent,
                width: isSelected ? 2.5 : 1,
              ),
              boxShadow: isSelected ? [BoxShadow(color: AppTheme.goldPrimary.withValues(alpha: 0.2), blurRadius: 8)] : null,
            ),
            child: Text(t['label'] as String, style: GoogleFonts.fredoka(
              color: isSelected ? AppTheme.goldPrimary : AppTheme.textPrimary,
              fontSize: 13, fontWeight: FontWeight.w600,
            )),
          ),
        );
      }).toList(),
    );
  }
}
