import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ═══════════════════════════════════════════
  // COLOR PALETTE — Warm, Vibrant, Child-Friendly
  // ═══════════════════════════════════════════
  static const Color midnight = Color(0xFF0F0F23); // deep dark navy
  static const Color deepSpace = Color(0xFF151532);
  static const Color navyCard = Color(0xFF1E1E46);
  static const Color surface = Color(0xFF27275B);
  static const Color surfaceAlt = Color(0xFF323275);

  static const Color goldPrimary = Color(0xFFFFD600); // sunshine yellow
  static const Color goldLight = Color(0xFFFFEA79);
  static const Color goldDark = Color(0xFFE5A900);

  static const Color accentCyan = Color(0xFF00FF88); // electric green
  static const Color accentPurple = Color(0xFFFA2E76); // electric magenta/pink
  static const Color accentGreen = Color(0xFF00F5D4); // electric teal
  static const Color accentRed = Color(0xFFFF4757); // bright cherry red
  static const Color accentOrange = Color(0xFFFF9F0A); // vibrant orange

  static const Color skyBlue = Color(0xFF00D2FF);
  static const Color lavender = Color(0xFFB1A2FF);
  static const Color peach = Color(0xFFFFCCBC);

  static const Color textPrimary = Color(0xFFF8F9FF);
  static const Color textSecondary = Color(0xFFB8C5E8);
  static const Color textMuted = Color(0xFF6B7DB3);

  // ═══════════════════════════════════════════
  // BOARD THEMES
  // ═══════════════════════════════════════════
  static Map<String, BoardThemeData> boardThemes = {
    'classic': BoardThemeData(
        light: Color(0xFFF5E6CA),
        dark: Color(0xFF8B6B4A),
        notation: Color(0xFF8B6B4A)),
    'grey': BoardThemeData(
        light: Color(0xFFB2B2B2),
        dark: Color(0xFF808080),
        notation: Color(0xFF808080)),
    'dark': BoardThemeData(
        light: Color(0xFF444444),
        dark: Color(0xFF333333),
        notation: Color(0xFFCCCCCC)),
    'amoled': BoardThemeData(
        light: Color(0xFF222222),
        dark: Color(0xFF000000),
        notation: Color(0xFF888888)),
    'lewis': BoardThemeData(
        light: Color(0xFFDBD1C1),
        dark: Color(0xFFAB3848),
        notation: Color(0xFFAB3848)),
    'cherry': BoardThemeData(
        light: Color(0xFFDB5E5C),
        dark: Color(0xFF645183),
        notation: Color(0xFFFFFFFF)),
    'sage': BoardThemeData(
        light: Color(0xFFB2AD91),
        dark: Color(0xFF83886F),
        notation: Color(0xFF83886F)),
    'tan': BoardThemeData(
        light: Color(0xFFD3A373),
        dark: Color(0xFF866749),
        notation: Color(0xFF866749)),
    'jade': BoardThemeData(
        light: Color(0xFF85B39F),
        dark: Color(0xFF517970),
        notation: Color(0xFFD0F0E0)),
    'stellar': BoardThemeData(
        light: Color(0xFFE2E8F0),
        dark: Color(0xFF475569),
        notation: Color(0xFF475569)),
    'green': BoardThemeData(
        light: Color(0xFFEBECD0),
        dark: Color(0xFF779556),
        notation: Color(0xFF779556)),
    'royal': BoardThemeData(
        light: Color(0xFFD1B28C),
        dark: Color(0xFF8D6E63),
        notation: Color(0xFF8D6E63)),
    'electric': BoardThemeData(
        light: Color(0xFFD1D1FF),
        dark: Color(0xFF5353EC),
        notation: Color(0xFF5353EC)),
  };

  static const Color selectedSq = Color(0xFF7BC67B);
  static const Color legalMoveSq = Color(0x6000FF88);
  static const Color lastMoveSq = Color(0x60FFD700);
  static const Color checkSq = Color(0x90FF6B9D);
  static const Color hintSq = Color(0x7074B9FF);

  // ═══════════════════════════════════════════
  // GRADIENTS — Warm & Playful
  // ═══════════════════════════════════════════
  static const LinearGradient backgroundGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF0F0F23), Color(0xFF151532), Color(0xFF11224D)],
  );

  static const Map<String, LinearGradient> backgroundGradients = {
    'midnight': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A1A2E), Color(0xFF16213E), Color(0xFF0F3460)],
    ),
    'ocean': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF0D1B2A), Color(0xFF1B3A4B), Color(0xFF006D77)],
    ),
    'forest': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF1A1C16), Color(0xFF1E3A2F), Color(0xFF2D6A4F)],
    ),
    'sunset': LinearGradient(
      begin: Alignment.topLeft,
      end: Alignment.bottomRight,
      colors: [Color(0xFF2D1B33), Color(0xFF4A1942), Color(0xFF6B1D3F)],
    ),
  };

  static LinearGradient getBackground(String key) {
    return backgroundGradients[key] ?? backgroundGradient;
  }

  static const LinearGradient goldGradient = LinearGradient(
    colors: [
      Color(0xFFE5A900),
      Color(0xFFFFD600),
      Color(0xFFFFEA79),
      Color(0xFFFFD600)
    ],
  );

  static const LinearGradient cardGradient = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [Color(0xFF1E1E46), Color(0xFF121228)],
  );

  static const LinearGradient cyanGradient = LinearGradient(
    colors: [Color(0xFF00FF88), Color(0xFF00F5D4)],
  );

  static const LinearGradient pinkGradient = LinearGradient(
    colors: [Color(0xFFFA2E76), Color(0xFFB1A2FF)],
  );

  static const LinearGradient rainbowGradient = LinearGradient(
    colors: [
      Color(0xFFFF6B9D),
      Color(0xFFFFD93D),
      Color(0xFF6BCB77),
      Color(0xFF74B9FF),
      Color(0xFFA29BFE)
    ],
  );

  static const LinearGradient errorGradient = LinearGradient(
    colors: [Color(0xFFFF8A5C), Color(0xFFFF6B9D)],
  );

  // ═══════════════════════════════════════════
  // SHADOWS
  // ═══════════════════════════════════════════
  static List<BoxShadow> goldShadow = [
    BoxShadow(
        color: goldPrimary.withValues(alpha: 0.4), blurRadius: 24, spreadRadius: 4),
  ];

  static List<BoxShadow> cyanShadow = [
    BoxShadow(
        color: accentCyan.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2),
  ];

  static List<BoxShadow> cardShadow = [
    BoxShadow(
      color: Colors.black.withValues(alpha: 0.3),
      blurRadius: 16,
      offset: const Offset(0, 8),
    ),
  ];

  static List<BoxShadow> pinkShadow = [
    BoxShadow(
        color: accentPurple.withValues(alpha: 0.3), blurRadius: 20, spreadRadius: 2),
  ];

  // ═══════════════════════════════════════════
  // TYPOGRAPHY — Playful & Rounded
  // ═══════════════════════════════════════════
  static TextTheme _buildTextTheme() {
    return TextTheme(
      displayLarge: GoogleFonts.fredoka(
        fontSize: 58,
        fontWeight: FontWeight.w700,
        color: textPrimary,
        letterSpacing: -0.5,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
      displayMedium: GoogleFonts.fredoka(
        fontSize: 46,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
      displaySmall: GoogleFonts.fredoka(
        fontSize: 38,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
      headlineLarge: GoogleFonts.fredoka(
        fontSize: 34,
        fontWeight: FontWeight.w700,
        color: textPrimary,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
      headlineMedium: GoogleFonts.jura(
        fontSize: 30,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
      headlineSmall: GoogleFonts.jura(
        fontSize: 26,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
      titleLarge: GoogleFonts.fredoka(
        fontSize: 24,
        fontWeight: FontWeight.w600,
        color: textPrimary,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
      titleMedium: GoogleFonts.jura(
        fontSize: 18,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 0.15,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
      titleSmall: GoogleFonts.jura(
        fontSize: 16,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        letterSpacing: 0.1,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
      bodyLarge: GoogleFonts.baloo2(
        fontSize: 18,
        fontWeight: FontWeight.w400,
        color: textPrimary,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
      bodyMedium: GoogleFonts.baloo2(
        fontSize: 16,
        fontWeight: FontWeight.w400,
        color: textSecondary,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
      bodySmall: GoogleFonts.baloo2(
        fontSize: 14,
        fontWeight: FontWeight.w400,
        color: textMuted,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
      labelLarge: GoogleFonts.fredoka(
        fontSize: 16,
        fontWeight: FontWeight.w600,
        color: textPrimary,
        letterSpacing: 1.0,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
      labelMedium: GoogleFonts.fredoka(
        fontSize: 14,
        fontWeight: FontWeight.w500,
        color: textSecondary,
        letterSpacing: 0.5,
      ).copyWith(fontFamilyFallback: [GoogleFonts.notoSans().fontFamily!]),
    );
  }

  // ═══════════════════════════════════════════
  // DARK THEME — Warm & Child-Friendly
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
        titleTextStyle: GoogleFonts.fredoka(
          fontSize: 22,
          fontWeight: FontWeight.w700,
          color: textPrimary,
          letterSpacing: 0.5,
        ),
        iconTheme: const IconThemeData(color: textPrimary),
      ),
      cardTheme: CardThemeData(
        color: navyCard,
        elevation: 8,
        shadowColor: Colors.black.withValues(alpha: 0.4),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(24)),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          backgroundColor: goldPrimary,
          foregroundColor: midnight,
          elevation: 8,
          shadowColor: goldPrimary.withValues(alpha: 0.4),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
          textStyle: GoogleFonts.fredoka(
              fontSize: 18, fontWeight: FontWeight.w700, letterSpacing: 0.5),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          foregroundColor: goldPrimary,
          side: const BorderSide(color: goldPrimary, width: 2),
          shape:
              RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
          padding: const EdgeInsets.symmetric(horizontal: 36, vertical: 18),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: surface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(20),
          borderSide: const BorderSide(color: goldPrimary, width: 2),
        ),
        labelStyle: GoogleFonts.baloo2(color: textSecondary, fontSize: 16),
        hintStyle: GoogleFonts.baloo2(color: textMuted, fontSize: 16),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: deepSpace,
        selectedItemColor: goldPrimary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 20,
      ),
      dividerTheme:
          const DividerThemeData(color: Color(0xFF2D3A6A), thickness: 1),
      iconTheme: const IconThemeData(color: textSecondary, size: 26),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: goldPrimary,
        linearTrackColor: surface,
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: navyCard,
        contentTextStyle: GoogleFonts.baloo2(color: textPrimary, fontSize: 16),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(20)),
        behavior: SnackBarBehavior.floating,
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: navyCard,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(28)),
        elevation: 24,
      ),
      chipTheme: ChipThemeData(
        backgroundColor: surface,
        selectedColor: goldPrimary.withValues(alpha: 0.2),
        labelStyle: GoogleFonts.fredoka(fontSize: 14, color: textPrimary),
        side: const BorderSide(color: Color(0xFF2D3A6A)),
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
      ),
    );
  }
}

class BoardThemeData {
  final Color light;
  final Color dark;
  final Color notation;
  const BoardThemeData(
      {required this.light, required this.dark, required this.notation});
}

