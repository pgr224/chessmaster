import 'package:flutter/material.dart';
import 'package:flutter_animate/flutter_animate.dart';
import 'package:google_fonts/google_fonts.dart';
import '../../../core/theme/app_theme.dart';
import '../../../domain/engine/chess_engine.dart';
import './animated_robot_coach.dart';

class PlayerInfoWidget extends StatelessWidget {
  final String name;
  final PieceColor color;
  final bool isActive;
  final bool isAI;
  final bool isThinking;
  final String? avatarUrl;
  final String? localAvatar;

  const PlayerInfoWidget({
    super.key,
    required this.name,
    required this.color,
    required this.isActive,
    required this.isAI,
    required this.isThinking,
    this.avatarUrl,
    this.localAvatar,
  });

  @override
  Widget build(BuildContext context) {
    return AnimatedContainer(
      duration: 400.ms,
      curve: Curves.easeInOut,
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 6),
      decoration: BoxDecoration(
        color: isActive
            ? AppTheme.surface.withOpacity(0.95)
            : AppTheme.navyCard.withOpacity(0.5),
        borderRadius: BorderRadius.circular(16),
        border: Border.all(
          color: isActive
              ? AppTheme.goldPrimary.withOpacity(0.8)
              : Colors.transparent,
          width: 1.5,
        ),
        boxShadow: isActive
            ? [
                BoxShadow(
                    color: AppTheme.goldPrimary.withOpacity(0.1), blurRadius: 8)
              ]
            : null,
      ),
      child: Row(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Avatar / piece color indicator
          Container(
            width: 38,
            height: 38,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              boxShadow: isActive
                  ? [
                      BoxShadow(
                        color: (avatarUrl != null
                                ? AppTheme.goldPrimary
                                : (color == PieceColor.white
                                    ? Colors.white70
                                    : Colors.black54))
                            .withOpacity(0.3),
                        blurRadius: 8,
                        spreadRadius: 1,
                      )
                    ]
                  : null,
              border: Border.all(
                color: isActive
                    ? AppTheme.goldPrimary
                    : (color == PieceColor.white
                        ? AppTheme.goldDark
                        : AppTheme.textMuted),
                width: 2.5,
              ),
            ),
            child: ClipOval(
              child: _buildAvatarImage(),
            ),
          ),
          const SizedBox(width: 10),
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisSize: MainAxisSize.min,
            children: [
              SizedBox(
                width: 150,
                child: Text(
                  name,
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                  style: GoogleFonts.fredoka(
                    color: AppTheme.textPrimary,
                    fontWeight: FontWeight.w700,
                    fontSize: 15,
                  ),
                ),
              ),
              Text(
                color == PieceColor.white ? '⚪ White' : '⚫ Black',
                style: GoogleFonts.baloo2(
                  color: isActive ? AppTheme.textSecondary : AppTheme.textMuted,
                  fontSize: 12,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ],
      ),
    );
  }

  Widget _buildAvatarImage() {
    if (avatarUrl != null && avatarUrl!.isNotEmpty) {
      return Image.network(
        avatarUrl!,
        fit: BoxFit.cover,
        errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
      );
    }

    if (localAvatar != null && localAvatar!.isNotEmpty) {
      if (localAvatar!.startsWith('assets/')) {
        return Image.asset(
          localAvatar!,
          fit: BoxFit.cover,
          errorBuilder: (context, error, stackTrace) => _buildDefaultIcon(),
        );
      }
    }

    return _buildDefaultIcon();
  }

  Widget _buildDefaultIcon() {
    return Container(
      decoration: BoxDecoration(
        gradient: color == PieceColor.white
            ? const LinearGradient(colors: [Colors.white, Color(0xFFF5E6CA)])
            : const LinearGradient(
                colors: [Color(0xFF2D1B69), AppTheme.midnight]),
      ),
      child: Center(
        child: Icon(
          isThinking
              ? Icons.psychology_rounded
              : (isAI ? Icons.smart_toy_rounded : Icons.person_rounded),
          color: color == PieceColor.white ? AppTheme.midnight : Colors.white,
          size: 20,
        ),
      ),
    );
  }
}
