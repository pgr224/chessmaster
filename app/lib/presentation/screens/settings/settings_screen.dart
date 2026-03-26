import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/settings/settings_bloc.dart';
import '../../blocs/theme/theme_bloc.dart';

class SettingsScreen extends StatefulWidget {
  const SettingsScreen({super.key});

  @override
  State<SettingsScreen> createState() => _SettingsScreenState();
}

class _SettingsScreenState extends State<SettingsScreen> {
  late String _boardTheme;
  late String _pieceTheme;
  bool _loadedTheme = false;

  @override
  void didChangeDependencies() {
    super.didChangeDependencies();
    if (_loadedTheme) return;
    final themeState = context.read<ThemeBloc>().state;
    _boardTheme = themeState.boardTheme;
    _pieceTheme = themeState.pieceTheme;
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
                _sectionCard(
                  title: 'Theme',
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      _subTitle('Board Theme'),
                      const SizedBox(height: 10),
                      _buildBoardThemeChips(),
                      const SizedBox(height: 14),
                      _subTitle('Piece Style'),
                      const SizedBox(height: 10),
                      _buildPieceThemeChips(),
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
                      _switchTile(
                        title: 'Confirm Before Offer Draw',
                        subtitle: 'Show confirmation dialog before sending draw offer',
                        value: settings.confirmDrawOffer,
                        onChanged: (v) => context.read<SettingsBloc>().add(SettingsConfirmDrawOfferEvent(v)),
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
                const SizedBox(height: 14),
                _sectionCard(
                  title: 'Other',
                  child: _switchTile(
                    title: 'Notifications',
                    subtitle: 'Match invites and multiplayer updates',
                    value: settings.notificationsEnabled,
                    onChanged: (v) => context.read<SettingsBloc>().add(SettingsNotificationsEvent(v)),
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
            context.read<ThemeBloc>().add(ThemeChangeEvent(boardTheme: _boardTheme, pieceTheme: _pieceTheme));
          },
          label: Text('${emoji[t] ?? '♟'} ${_cap(t)}', style: GoogleFonts.fredoka(fontSize: 12)),
          labelStyle: TextStyle(color: selected ? AppTheme.midnight : AppTheme.textPrimary),
          selectedColor: AppTheme.goldPrimary,
          backgroundColor: AppTheme.surface.withValues(alpha: 0.7),
        );
      }).toList(),
    );
  }

  Widget _buildPieceThemeChips() {
    final themes = [
      {'id': 'classic3d', 'name': 'Classic 3D'},
      {'id': 'marble3d', 'name': 'Marble 3D'},
      {'id': 'metal3d', 'name': 'Metal 3D'},
      {'id': 'letters', 'name': 'Letters'},
      {'id': '8-bit', 'name': '8-Bit'},
      {'id': 'angular', 'name': 'Angular'},
      {'id': 'mexico', 'name': 'Mexico'},
      {'id': 'lewis', 'name': 'Lewis'},
      {'id': 'video', 'name': 'Neon/Video'},
    ];

    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: themes.map((t) {
        final id = t['id']!;
        final selected = _pieceTheme == id;
        return ChoiceChip(
          selected: selected,
          onSelected: (_) {
            setState(() => _pieceTheme = id);
            context.read<ThemeBloc>().add(ThemeChangeEvent(boardTheme: _boardTheme, pieceTheme: _pieceTheme));
          },
          label: Text(t['name']!, style: GoogleFonts.fredoka(fontSize: 12)),
          labelStyle: TextStyle(color: selected ? AppTheme.midnight : AppTheme.textPrimary),
          selectedColor: AppTheme.goldPrimary,
          backgroundColor: AppTheme.surface.withValues(alpha: 0.7),
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
      activeColor: AppTheme.goldPrimary,
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
    final themes = [
      {'id': 'midnight', 'label': '🌙 Midnight', 'colors': [const Color(0xFF1A1A2E), const Color(0xFF0F3460)]},
      {'id': 'ocean', 'label': '🌊 Ocean', 'colors': [const Color(0xFF0D1B2A), const Color(0xFF006D77)]},
      {'id': 'forest', 'label': '🌿 Forest', 'colors': [const Color(0xFF1A1C16), const Color(0xFF2D6A4F)]},
      {'id': 'sunset', 'label': '🌅 Sunset', 'colors': [const Color(0xFF2D1B33), const Color(0xFF6B1D3F)]},
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: themes.map((t) {
        final id = t['id'] as String;
        final isSelected = selected == id;
        final colors = t['colors'] as List<Color>;
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
