import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';
import 'package:flutter_animate/flutter_animate.dart';
import '../../core/theme/app_theme.dart';

class GameRulesDialog extends StatelessWidget {
  final String timeControl;
  final String mode;

  const GameRulesDialog({
    super.key,
    required this.timeControl,
    required this.mode,
  });

  @override
  Widget build(BuildContext context) {
    // Parse timeControl to friendly label
    String title = "Blitz Match";
    String description = "Fast-paced action!";
    String details = "3 minutes per side + 2s increment";

    if (timeControl.contains('10+')) {
      title = "Rapid Match";
      description = "Strategic and balanced.";
      details = "10 minutes per side + 0s increment";
    } else if (timeControl.contains('30')) {
      title = "Standard Match";
      description = "Classic chess pace.";
      details = "30 minutes per side";
    }

    return Dialog(
      backgroundColor: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.all(24),
        decoration: BoxDecoration(
          color: AppTheme.navyCard,
          borderRadius: BorderRadius.circular(32),
          border: Border.all(
              color: AppTheme.goldPrimary.withOpacity(0.3), width: 2),
          boxShadow: [
            BoxShadow(color: Colors.black.withOpacity(0.5), blurRadius: 40),
          ],
        ),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.timer_sharp, color: AppTheme.goldPrimary, size: 48)
                .animate(onPlay: (c) => c.repeat())
                .scale(
                    begin: const Offset(1, 1),
                    end: const Offset(1.1, 1.1),
                    duration: 1.seconds,
                    curve: Curves.easeInOut)
                .then()
                .scale(
                    begin: const Offset(1.1, 1.1),
                    end: const Offset(1, 1),
                    duration: 1.seconds,
                    curve: Curves.easeInOut),
            const SizedBox(height: 16),
            Text(title.toUpperCase(),
                style: GoogleFonts.fredoka(
                    color: AppTheme.goldPrimary,
                    fontSize: 24,
                    fontWeight: FontWeight.bold)),
            const SizedBox(height: 8),
            Text(description,
                style: GoogleFonts.baloo2(
                    color: AppTheme.textSecondary, fontSize: 16)),
            const SizedBox(height: 24),
            _ruleItem(Icons.access_time_filled, details),
            _ruleItem(Icons.flash_on, "Increment support enabled (Fischer)"),
            _ruleItem(Icons.gavel,
                "Lose on time unless opponent has insufficient material"),
            _ruleItem(Icons.verified_user, "Authoritative server clock synced"),
            const SizedBox(height: 32),
            SizedBox(
              width: double.infinity,
              child: ElevatedButton(
                style: ElevatedButton.styleFrom(
                  backgroundColor: AppTheme.goldPrimary,
                  foregroundColor: Colors.black,
                  padding: const EdgeInsets.symmetric(vertical: 16),
                  shape: RoundedRectangleBorder(
                      borderRadius: BorderRadius.circular(16)),
                ),
                onPressed: () => Navigator.pop(context),
                child: Text("LET'S PLAY!",
                    style: GoogleFonts.fredoka(
                        fontWeight: FontWeight.bold, fontSize: 18)),
              ),
            ),
          ],
        ),
      ).animate().scale(duration: 400.ms, curve: Curves.easeOutBack).fadeIn(),
    );
  }

  Widget _ruleItem(IconData icon, String text) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 6),
      child: Row(
        children: [
          Icon(icon, color: AppTheme.goldPrimary.withOpacity(0.8), size: 18),
          const SizedBox(width: 12),
          Expanded(
              child: Text(text,
                  style: GoogleFonts.baloo2(
                      color: AppTheme.textPrimary, fontSize: 14))),
        ],
      ),
    );
  }
}
