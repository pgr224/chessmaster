import 'package:flutter/material.dart';
import 'package:flutter_bloc/flutter_bloc.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../blocs/settings/settings_bloc.dart';
import '../../blocs/theme/theme_bloc.dart';
import '../../blocs/auth/auth_bloc.dart';
import '../profile/profile_screen.dart';
import '../../../domain/engine/chess_engine.dart';
import '../../widgets/chess_piece_widget.dart';

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
                    final user = authState is AuthAuthenticatedState
                        ? authState.user
                        : null;
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
                            onChanged: (v) => context
                                .read<SettingsBloc>()
                                .add(SettingsNotificationsEvent(v)),
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
                        onChanged: (v) => context
                            .read<SettingsBloc>()
                            .add(SettingsShowCoordinatesEvent(v)),
                      ),
                      _switchTile(
                        title: 'Show Legal Move Dots',
                        subtitle: 'Display target hints for selected pieces',
                        value: settings.showLegalMoves,
                        onChanged: (v) => context
                            .read<SettingsBloc>()
                            .add(SettingsShowLegalMovesEvent(v)),
                      ),
                      _switchTile(
                        title: 'Confirm Moves',
                        subtitle: 'Tap twice or press check to move',
                        value: settings.confirmMoves,
                        onChanged: (v) => context
                            .read<SettingsBloc>()
                            .add(SettingsConfirmMovesEvent(v)),
                      ),
                      _switchTile(
                        title: 'Auto-Queen',
                        subtitle: 'Always promote pawns to queen',
                        value: settings.autoQueen,
                        onChanged: (v) => context
                            .read<SettingsBloc>()
                            .add(SettingsAutoQueenEvent(v)),
                      ),
                      _switchTile(
                        title: 'Auto-Flip Board (2 Player)',
                        subtitle: 'Rotate board to side-to-move in local games',
                        value: settings.autoFlipBoard,
                        onChanged: (v) => context
                            .read<SettingsBloc>()
                            .add(SettingsAutoFlipBoardEvent(v)),
                      ),
                      _switchTile(
                        title: 'Confirm Before Resign',
                        subtitle: 'Show confirmation dialog before resigning',
                        value: settings.confirmResign,
                        onChanged: (v) => context
                            .read<SettingsBloc>()
                            .add(SettingsConfirmResignEvent(v)),
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
                        onChanged: (v) => context
                            .read<SettingsBloc>()
                            .add(SettingsSoundEvent(v)),
                      ),
                      _switchTile(
                        title: 'Vibration',
                        subtitle: 'Haptic feedback on check and actions',
                        value: settings.vibrationEnabled,
                        onChanged: (v) => context
                            .read<SettingsBloc>()
                            .add(SettingsVibrationEvent(v)),
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
        border: Border.all(color: Colors.white.withOpacity(0.06)),
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
    final themes = [
      'classic',
      'grey',
      'dark',
      'amoled',
      'lewis',
      'cherry',
      'sage',
      'tan',
      'jade',
      'stellar',
      'green',
      'royal',
      'electric'
    ];
    final emoji = {
      'classic': '🟫',
      'grey': '⬜',
      'dark': '⬛',
      'amoled': '🌑',
      'lewis': '📽️',
      'cherry': '🍒',
      'sage': '🌿',
      'tan': '🏜️',
      'jade': '🐉',
      'stellar': '✨',
      'green': '🟩',
      'royal': '📜',
      'electric': '⚡'
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
                pieceStyle: _pieceStyle));
          },
          label: Text('${emoji[t] ?? '♟'} ${_cap(t)}',
              style: GoogleFonts.fredoka(fontSize: 12)),
          labelStyle: TextStyle(
              color: selected ? AppTheme.midnight : AppTheme.textPrimary),
          selectedColor: AppTheme.goldPrimary,
          backgroundColor: AppTheme.surface.withOpacity(0.7),
        );
      }).toList(),
    );
  }

  Widget _buildPieceShapeChips() {
    final isShuffled = _pieceShape == 'shuffled';
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: [
        Row(
           children: [
             Expanded(
               child: Container(
                 padding: const EdgeInsets.all(12),
                 decoration: BoxDecoration(
                   color: AppTheme.surface.withOpacity(0.3),
                   borderRadius: BorderRadius.circular(12),
                   border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.3)),
                 ),
                 child: Row(
                   children: [
                     _getPieceAvatar(_pieceShape),
                     const SizedBox(width: 12),
                     Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text('CURRENT SHAPE', style: GoogleFonts.fredoka(color: AppTheme.textSecondary, fontSize: 10, fontWeight: FontWeight.bold)),
                          Text(_cap(_pieceShape.replaceAll('_', ' ')), style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 16, fontWeight: FontWeight.w600)),
                        ],
                     ),
                     const Spacer(),
                     if (!isShuffled) ...[
                       IconButton(
                         icon: const Icon(Icons.shuffle_rounded, color: AppTheme.accentCyan, size: 20),
                         onPressed: () {
                           setState(() => _pieceShape = 'shuffled');
                           _updateTheme();
                         },
                         tooltip: 'Toggle Shuffle Mode',
                       ),
                     ],
                   ],
                 ),
               ),
             ),
           ],
        ),
        const SizedBox(height: 12),
        _glassButton(
          icon: Icons.grid_view_rounded,
          label: 'Change Shapes (55+ Styles)',
          onTap: () => _showPieceSelector(context),
        ),
        const SizedBox(height: 16),
        _buildCurrentThemeKeyPiecesPreview(),
      ],
    );
  }

  void _updateTheme() {
    context.read<ThemeBloc>().add(ThemeChangeEvent(
      boardTheme: _boardTheme,
      pieceShape: _pieceShape,
      pieceStyle: _pieceStyle));
  }

  Widget _buildCurrentThemeKeyPiecesPreview() {
    if (_pieceShape == 'shuffled') {
      return Container(
        width: double.infinity,
        padding: const EdgeInsets.all(20),
        decoration: BoxDecoration(
          color: AppTheme.surface.withOpacity(0.3),
          borderRadius: BorderRadius.circular(16),
          border: Border.all(color: AppTheme.accentCyan.withOpacity(0.3)),
        ),
        child: Column(
          children: [
            const Icon(Icons.shuffle_rounded,
                color: AppTheme.accentCyan, size: 32),
            const SizedBox(height: 8),
            Text('SHUFFLE MODE',
                style: GoogleFonts.fredoka(
                    color: AppTheme.accentCyan,
                    fontSize: 14,
                    fontWeight: FontWeight.bold)),
            Text('A new random theme every game!',
                style: GoogleFonts.fredoka(
                    color: AppTheme.textSecondary, fontSize: 10)),
          ],
        ),
      );
    }

    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: AppTheme.surface.withOpacity(0.3),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: AppTheme.goldPrimary.withOpacity(0.3)),
      ),
      child: Column(
        children: [
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceBetween,
            children: [
              Text('Live Preview: ${_cap(_pieceShape)}',
                  style: GoogleFonts.fredoka(
                      color: AppTheme.textSecondary,
                      fontSize: 12,
                      fontWeight: FontWeight.w600)),
              Container(
                padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                decoration: BoxDecoration(
                    color: AppTheme.goldPrimary.withOpacity(0.2),
                    borderRadius: BorderRadius.circular(8)),
                child: Text(_pieceStyle.toUpperCase(),
                    style: GoogleFonts.fredoka(
                        color: AppTheme.goldPrimary,
                        fontSize: 10,
                        fontWeight: FontWeight.bold)),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Row(
            mainAxisAlignment: MainAxisAlignment.spaceEvenly,
            children: [
              _piecePreview(_pieceShape, PieceType.king, 48),
              _piecePreview(_pieceShape, PieceType.queen, 48),
              _piecePreview(_pieceShape, PieceType.knight, 48),
              _piecePreview(_pieceShape, PieceType.rook, 48),
              _piecePreview(_pieceShape, PieceType.pawn, 48),
            ],
          ),
        ],
      ),
    );
  }

  Widget _glassButton(
      {required IconData icon,
      required String label,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        width: double.infinity,
        padding: const EdgeInsets.symmetric(vertical: 12, horizontal: 16),
        decoration: BoxDecoration(
          color: Colors.white.withOpacity(0.05),
          borderRadius: BorderRadius.circular(12),
          border: Border.all(color: Colors.white.withOpacity(0.1)),
        ),
        child: Row(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: AppTheme.skyBlue, size: 20),
            const SizedBox(width: 10),
            Text(label,
                style: GoogleFonts.fredoka(
                    color: AppTheme.skyBlue,
                    fontSize: 13,
                    fontWeight: FontWeight.w600)),
          ],
        ),
      ),
    );
  }

  void _showPieceSelector(BuildContext context) {
    // Merge basic and vector shapes
    const basicShapes = ['classic', 'modern', 'angular', 'neo', 'wood', 'fantasy', 'iconic', 'artwork'];
    final List<String> allShapes = {...basicShapes, ...PiecePathProvider.pychessShapes}.toList();

    showModalBottomSheet(
      context: context,
      backgroundColor: Colors.transparent,
      isScrollControlled: true,
      builder: (context) => Container(
        height: MediaQuery.of(context).size.height * 0.85,
        decoration: BoxDecoration(
          color: AppTheme.midnight,
          borderRadius: const BorderRadius.vertical(top: Radius.circular(32)),
          border: Border.all(color: AppTheme.skyBlue.withOpacity(0.1)),
        ),
        child: Column(
          children: [
            const SizedBox(height: 12),
            Container(width: 40, height: 4, decoration: BoxDecoration(color: Colors.white24, borderRadius: BorderRadius.circular(2))),
            Padding(
              padding: const EdgeInsets.all(24),
              child: Row(
                children: [
                  Text('Piece Shapes',
                      style: GoogleFonts.fredoka(color: AppTheme.textPrimary, fontSize: 22, fontWeight: FontWeight.bold)),
                  const Spacer(),
                  _glassAction(icon: Icons.close_rounded, size: 32, onTap: () => Navigator.pop(context)),
                ],
              ),
            ),
            Expanded(
              child: GridView.builder(
                padding: const EdgeInsets.fromLTRB(24, 0, 24, 24),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  crossAxisSpacing: 16,
                  mainAxisSpacing: 16,
                  childAspectRatio: 1.2,
                ),
                itemCount: allShapes.length,
                itemBuilder: (context, index) {
                  final s = allShapes[index];
                  final isSelected = _pieceShape == s;
                  final displayName = s.replaceAll('_', ' ').replaceAll(' SVG', '');
                  
                  return GestureDetector(
                    onTap: () {
                      setState(() => _pieceShape = s);
                      _updateTheme();
                      Navigator.pop(context);
                    },
                    child: Container(
                      decoration: BoxDecoration(
                        color: isSelected ? AppTheme.goldPrimary.withOpacity(0.1) : Colors.white.withOpacity(0.03),
                        borderRadius: BorderRadius.circular(20),
                        border: Border.all(color: isSelected ? AppTheme.goldPrimary : Colors.white10, width: 2),
                      ),
                      child: Column(
                        mainAxisAlignment: MainAxisAlignment.center,
                        children: [
                          _pychessPreview(s),
                          const SizedBox(height: 10),
                          Text(_cap(displayName),
                              style: GoogleFonts.fredoka(color: isSelected ? AppTheme.goldPrimary : AppTheme.textSecondary, fontSize: 11, fontWeight: FontWeight.bold),
                              textAlign: TextAlign.center,
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis),
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
      padding: const EdgeInsets.symmetric(vertical: 8, horizontal: 4),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.spaceEvenly,
        children: [
          _piecePreview(shape, PieceType.king, 38),
          _piecePreview(shape, PieceType.knight, 38),
          _piecePreview(shape, PieceType.pawn, 38),
        ],
      ),
    );
  }

  Widget _piecePreview(String shape, PieceType type, double size) {
    return Container(
      width: size,
      height: size,
      decoration: BoxDecoration(
        color: Colors.white.withOpacity(0.05),
        borderRadius: BorderRadius.circular(8),
      ),
      child: ChessPieceWidget(
        piece: ChessPiece(type: type, color: PieceColor.white),
        shape: shape,
        style: _pieceStyle,
        size: size * 0.8,
      ),
    );
  }

  Widget _getPieceAvatar(String id) {
    if (id == 'shuffled') {
      return Icon(Icons.shuffle,
          size: 16,
          color: _pieceShape == 'shuffled' ? AppTheme.midnight : Colors.white);
    }

    // Use Knight as the most distinctive piece for the avatar
    return Padding(
      padding: const EdgeInsets.all(2.0),
      child: ChessPieceWidget(
        piece: ChessPiece(type: PieceType.knight, color: PieceColor.white),
        shape: id,
        style: _pieceStyle,
        size: 18,
      ),
    );
  }

  Widget _glassAction(
      {required IconData icon,
      required double size,
      required VoidCallback onTap}) {
    return GestureDetector(
      onTap: onTap,
      child: Container(
        padding: const EdgeInsets.all(6),
        decoration: BoxDecoration(
            color: Colors.white.withOpacity(0.1), shape: BoxShape.circle),
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
      spacing: 8,
      runSpacing: 8,
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
                pieceStyle: _pieceStyle));
          },
          label: Text(s['name']!, style: GoogleFonts.fredoka(fontSize: 12)),
          labelStyle: TextStyle(
              color: selected ? AppTheme.midnight : AppTheme.textPrimary),
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
          onSelected: (_) => context
              .read<SettingsBloc>()
              .add(SettingsMoveAnimationSpeedEvent(id)),
          label: Text(opt['label']!, style: GoogleFonts.fredoka()),
          labelStyle: TextStyle(
              color: selected ? AppTheme.midnight : AppTheme.textPrimary),
          selectedColor: AppTheme.goldPrimary,
          backgroundColor: AppTheme.surface.withOpacity(0.7),
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
          color: AppTheme.goldPrimary.withOpacity(0.1),
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
      trailing:
          const Icon(Icons.chevron_right_rounded, color: AppTheme.textMuted),
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

  String _cap(String s) =>
      s.isEmpty ? s : '${s[0].toUpperCase()}${s.substring(1)}';

  Widget _buildBackgroundThemeChips(String selected) {
    final themes = <Map<String, dynamic>>[
      {
        'id': 'midnight',
        'label': '🌙 Midnight',
        'colors': <Color>[const Color(0xFF1A1A2E), const Color(0xFF0F3460)]
      },
      {
        'id': 'ocean',
        'label': '🌊 Ocean',
        'colors': <Color>[const Color(0xFF0D1B2A), const Color(0xFF006D77)]
      },
      {
        'id': 'forest',
        'label': '🌿 Forest',
        'colors': <Color>[const Color(0xFF1A1C16), const Color(0xFF2D6A4F)]
      },
      {
        'id': 'sunset',
        'label': '🌅 Sunset',
        'colors': <Color>[const Color(0xFF2D1B33), const Color(0xFF6B1D3F)]
      },
    ];
    return Wrap(
      spacing: 8,
      runSpacing: 8,
      children: themes.map((t) {
        final id = t['id'] as String;
        final isSelected = selected == id;
        final colors = (t['colors'] as List).cast<Color>();
        return GestureDetector(
          onTap: () =>
              context.read<SettingsBloc>().add(SettingsBackgroundEvent(id)),
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
              boxShadow: isSelected
                  ? [
                      BoxShadow(
                          color: AppTheme.goldPrimary.withOpacity(0.2),
                          blurRadius: 8)
                    ]
                  : null,
            ),
            child: Text(t['label'] as String,
                style: GoogleFonts.fredoka(
                  color:
                      isSelected ? AppTheme.goldPrimary : AppTheme.textPrimary,
                  fontSize: 13,
                  fontWeight: FontWeight.w600,
                )),
          ),
        );
      }).toList(),
    );
  }
}
