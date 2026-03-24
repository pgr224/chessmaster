import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ═══════════════════════════════════════════
  // COLOR PALETTE
  // ═══════════════════════════════════════════
  static const Color midnight    = Color(0xFF0A0E27);
  static const Color deepSpace   = Color(0xFF0F1535);
  static const Color navyCard    = Color(0xFF141A3D);
  static const Color surface     = Color(0xFF1A2248);
  static const Color surfaceAlt  = Color(0xFF1F2952);

  static const Color goldPrimary  = Color(0xFFD4AF37);
  static const Color goldLight    = Color(0xFFFFD700);
  static const Color goldDark     = Color(0xFFB8860B);

  static const Color accentCyan   = Color(0xFF00D4FF);
  static const Color accentPurple = Color(0xFF7B61FF);
  static const Color accentGreen  = Color(0xFF00E676);
  static const Color accentRed    = Color(0xFFFF3D71);
  static const Color accentOrange = Color(0xFFFF9800);

  static const Color textPrimary   = Color(0xFFF0F4FF);
  static const Color textSecondary = Color(0xFF8A9BC7);
  static const Color textMuted     = Color(0xFF4A5580);

  // Board Colors
  static const Color lightSquare  = Color(0xFFECDFC7);
  static const Color darkSquare   = Color(0xFF7B4F3A);
  static const Color selectedSq   = Color(0xFF7BC67B);
  static const Color legalMoveSq  = Color(0x6000FF88);
  static const Color lastMoveSq   = Color(0x60FFD700);
  static const Color checkSq      = Color(0x90FF3D71);
  static const Color hintSq       = Color(0x7000D4FF);

  // Neon board variant
  static const Color neonLight    = Color(0xFF1A1A2E);
  static const Color neonDark     = Color(0xFF0F0F1A);

  // Wood board variant
  static const Color woodLight    = Color(0xFFF0D9B5);
  static const Color woodDark     = Color(0xFFB58863);

  // ═══════════════════════════════════════════
  // GRADIENTS
  // ═══════════════════════════════════════════
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [midnight, Color(0xFF0E1530), deepSpace],
  );

  static const LinearGradient goldGradient = LinearGradient(
    colors: [goldDark, goldPrimary, goldLight, goldPrimary],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1A2248), Color(0xFF0F1535)],
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF00D4FF), Color(0xFF7B61FF)],
  );

  // ═══════════════════════════════════════════
  // SHADOWS
  // ═══════════════════════════════════════════
  static List<BoxShadow> goldShadow = [
    BoxShadow(color: goldPrimary.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
  ];

  static List<BoxShadow> cyanShadow = [
    BoxShadow(color: accentCyan.withOpacity(0.3), blurRadius: 20, spreadRadius: 2),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withOpacity(0.4),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  // ═══════════════════════════════════════════
  // TYPOGRAPHY
  // ═══════════════════════════════════════════
  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.outfit(
        fontSize: 57, fontWeight: FontWeight.w700, color: textPrimary, letterSpacing: -0.5,
      ),
      displayMedium: GoogleFonts.outfit(
        fontSize: 45, fontWeight: FontWeight.w600, color: textPrimary,
      ),
      displaySmall: GoogleFonts.outfit(
        fontSize: 36, fontWeight: FontWeight.w600, color: textPrimary,
      ),
      headlineLarge: GoogleFonts.outfit(
        fontSize: 32, fontWeight: FontWeight.w700, color: textPrimary,
      ),
      headlineMedium: GoogleFonts.outfit(
        fontSize: 28, fontWeight: FontWeight.w600, color: textPrimary,
      ),
      headlineSmall: GoogleFonts.outfit(
        fontSize: 24, fontWeight: FontWeight.w600, color: textPrimary,
      ),
      titleLarge: GoogleFonts.outfit(
        fontSize: 22, fontWeight: FontWeight.w600, color: textPrimary,
      ),
      titleMedium: GoogleFonts.outfit(
        fontSize: 16, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: 0.15,
      ),
      titleSmall: GoogleFonts.outfit(
        fontSize: 14, fontWeight: FontWeight.w500, color: textSecondary, letterSpacing: 0.1,
      ),
      bodyLarge: GoogleFonts.inter(
        fontSize: 16, fontWeight: FontWeight.w400, color: textPrimary,
      ),
      bodyMedium: GoogleFonts.inter(
        fontSize: 14, fontWeight: FontWeight.w400, color: textSecondary,
      ),
      bodySmall: GoogleFonts.inter(
        fontSize: 12, fontWeight: FontWeight.w400, color: textMuted,
      ),
      labelLarge: GoogleFonts.outfit(
        fontSize: 14, fontWeight: FontWeight.w600, color: textPrimary, letterSpacing: 1.2,
      ),
      labelMedium: GoogleFonts.outfit(
        fontSize: 12, fontWeight: FontWeight.w500, color: textSecondary, letterSpacing: 0.5,
      ),
    );
  }

  // ═══════════════════════════════════════════
  // DARK THEME
  // ═══════════════════════════════════════════
  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: midnight,
      colorScheme: const ColorScheme.dark(
        primary: goldPrimary,
        secondary: accentCyan,
        tertiary: accentPurple,
        surface: navyCard,
        error: accentRed,
        onPrimary: midnight,
        onSecondary: midnight,
        onSurface: textPrimary,
        surfaceContainerHighest: surface,
      ),
      textTheme: _buildTextTheme(),
      appBarTheme: AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: true,
        titleTextStyle: GoogleFonts.outfit(
          fontSize: 20, fontWeight: FontWeight.w700,
          color: textPrimary, letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: navyCard,
        elevation: 8,
        shadowColor: Colors.black.withOpacity(0.5),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldPrimary,
          foregroundColor: midnight,
          elevation: 8,
          shadowColor: goldPrimary.withOpacity(0.4),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
          textStyle: GoogleFonts.outfit(fontSize: 16, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldPrimary,
          side: const BorderSide(color: goldPrimary, width: 1.5),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 16),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: const BorderSide(color: goldPrimary, width: 1.5),
        ),
        labelStyle: GoogleFonts.inter(color: textSecondary),
        hintStyle: GoogleFonts.inter(color: textMuted),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: deepSpace,
        selectedItemColor: goldPrimary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 20,
      ),
      dividerTheme: const DividerThemeData(color: Color(0xFF1F2952), thickness: 1),
      iconTheme: const IconThemeData(color: textSecondary, size: 24),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: goldPrimary,
        linearTrackColor: surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navyCard,
        contentTextStyle: GoogleFonts.inter(color: textPrimary),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
        elevation: 24,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: goldPrimary.withOpacity(0.2),
        labelStyle: GoogleFonts.outfit(fontSize: 12, color: textPrimary),
        side: const BorderSide(color: Color(0xFF1F2952)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(8)),
      ),
    );
  }
}
