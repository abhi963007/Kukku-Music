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
  static const Color textSecondary = Color(0xFFB3B3B3); // Light grey (4.5:1 on #111)
  static const Color textMuted     = Color(0xFF8A8A8A); // Dim grey (3:1 on #111)
  static const Color success       = Color(0xFFFFFFFF); // White for success
  static const Color danger        = Color(0xFFFF6B6B); // Destructive actions
  static const Color cardBorder    = Color(0x22FFFFFF); // Subtle white border

  /// Minimum tappable edge length, per Material accessibility guidance.
  static const double minTouchTarget = 48.0;

  /// Shared corner radii so cards, sheets and chips stay visually consistent.
  static const double radiusSm = 10;
  static const double radiusMd = 14;
  static const double radiusLg = 20;
  static const double radiusXl = 26;

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

  /// Clamps the user's font scale so accessibility settings never break fixed
  /// height carousels, while still honouring a meaningful range.
  static TextScaler clampTextScaler(BuildContext context) {
    return MediaQuery.textScalerOf(context).clamp(minScaleFactor: 0.9, maxScaleFactor: 1.35);
  }

  static ThemeData get darkTheme {
    final baseTextTheme = GoogleFonts.outfitTextTheme(
      ThemeData.dark().textTheme.apply(
            bodyColor: textPrimary,
            displayColor: textPrimary,
          ),
    );

    return ThemeData(
      useMaterial3: true,
      brightness: Brightness.dark,
      scaffoldBackgroundColor: background,
      primaryColor: primary,
      splashFactory: InkSparkle.splashFactory,
      colorScheme: const ColorScheme.dark(
        primary: primary,
        onPrimary: background,
        secondary: secondary,
        onSecondary: background,
        surface: surface,
        onSurface: textPrimary,
        surfaceContainerHighest: surfaceLight,
        error: danger,
        outline: secondary,
      ),
      textTheme: baseTextTheme,
      // Guarantees every icon button / list row is at least 48dp tall.
      materialTapTargetSize: MaterialTapTargetSize.padded,
      visualDensity: VisualDensity.standard,
      appBarTheme: const AppBarTheme(
        backgroundColor: Colors.transparent,
        surfaceTintColor: Colors.transparent,
        elevation: 0,
        centerTitle: false,
        iconTheme: IconThemeData(color: textPrimary),
      ),
      iconTheme: const IconThemeData(color: textPrimary, size: 24),
      cardTheme: CardThemeData(
        color: surface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(radiusMd),
          side: const BorderSide(color: cardBorder, width: 1),
        ),
      ),
      dividerTheme: const DividerThemeData(
        color: cardBorder,
        thickness: 1,
        space: 1,
      ),
      listTileTheme: const ListTileThemeData(
        iconColor: textSecondary,
        textColor: textPrimary,
        minVerticalPadding: 8,
      ),
      bottomNavigationBarTheme: const BottomNavigationBarThemeData(
        backgroundColor: surface,
        selectedItemColor: primary,
        unselectedItemColor: textMuted,
        type: BottomNavigationBarType.fixed,
        elevation: 0,
      ),
      bottomSheetTheme: const BottomSheetThemeData(
        backgroundColor: surface,
        surfaceTintColor: Colors.transparent,
        modalBackgroundColor: surface,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.vertical(top: Radius.circular(radiusXl)),
        ),
      ),
      dialogTheme: DialogThemeData(
        backgroundColor: surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(18)),
        titleTextStyle: baseTextTheme.titleLarge?.copyWith(
          fontSize: 18,
          fontWeight: FontWeight.bold,
          color: textPrimary,
        ),
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(
          fontSize: 14,
          color: textSecondary,
        ),
      ),
      snackBarTheme: SnackBarThemeData(
        backgroundColor: surfaceLight,
        contentTextStyle: baseTextTheme.bodyMedium?.copyWith(color: textPrimary),
        behavior: SnackBarBehavior.floating,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
      ),
      popupMenuTheme: PopupMenuThemeData(
        color: surfaceLight,
        surfaceTintColor: Colors.transparent,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusMd)),
        textStyle: baseTextTheme.bodyMedium?.copyWith(color: textPrimary, fontSize: 14),
      ),
      tooltipTheme: const TooltipThemeData(
        decoration: BoxDecoration(
          color: surfaceLight,
          borderRadius: BorderRadius.all(Radius.circular(8)),
        ),
        textStyle: TextStyle(color: textPrimary, fontSize: 12),
      ),
      progressIndicatorTheme: const ProgressIndicatorThemeData(
        color: primary,
        linearMinHeight: 2,
      ),
      inputDecorationTheme: InputDecorationTheme(
        border: InputBorder.none,
        hintStyle: const TextStyle(color: textMuted),
        contentPadding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      ),
      textButtonTheme: TextButtonThemeData(
        style: TextButton.styleFrom(
          foregroundColor: primaryAccent,
          minimumSize: const Size(64, minTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(radiusSm)),
        ),
      ),
      elevatedButtonTheme: ElevatedButtonThemeData(
        style: ElevatedButton.styleFrom(
          minimumSize: const Size(64, minTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      outlinedButtonTheme: OutlinedButtonThemeData(
        style: OutlinedButton.styleFrom(
          minimumSize: const Size(64, minTouchTarget),
          shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
        ),
      ),
      iconButtonTheme: IconButtonThemeData(
        style: IconButton.styleFrom(
          minimumSize: const Size(minTouchTarget, minTouchTarget),
          foregroundColor: textPrimary,
        ),
      ),
    );
  }
}
