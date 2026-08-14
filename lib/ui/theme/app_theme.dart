import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

class AppTheme {
  // ── Monochrome Palette (inspired by the black & white ghost logo) ─────────
  static const Color background    = Color(0xFF000000); // Pure black
  static const Color surface       = Color(0xFF111111); // Near-black card
  static const Color surfaceLight  = Color(0xFF1C1C1C); // Lifted surface
  static const Color primary       = Color(0xFFFFFFFF); // White as accent
  static const Color primaryAccent = Color(0xFFE0E0E0); // Soft white
  static const Color secondary     = Color(0xFF888888); // Mid grey
  static const Color textPrimary   = Color(0xFFFFFFFF); // Pure white text
  static const Color textSecondary = Color(0xFFAAAAAA); // Light grey
  static const Color textMuted     = Color(0xFF555555); // Dark grey
  static const Color success       = Color(0xFFFFFFFF); // White for success
  static const Color cardBorder    = Color(0x22FFFFFF); // Subtle white border

  // White → grey gradient (like the logo's black/white shading)
  static const LinearGradient primaryGradient = LinearGradient(
    colors: [Color(0xFFFFFFFF), Color(0xFF888888)],
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
  );

  static const LinearGradient cardGradient = LinearGradient(
    colors: [Color(0xFF1A1A1A), Color(0xFF0D0D0D)],
    begin: Alignment.topCenter,
    end: Alignment.bottomCenter,
  );

  static ThemeData get darkTheme {
    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        secondary: secondary,
        surface: surface,
      ),
      textTheme: GoogleFonts.outfitTextTheme(
        ThemeData.dark().textTheme.apply(
              bodyColor: textPrimary,
              displayColor: textPrimary,
            ),
      ),
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
      ),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(16),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
    );
  }
}
