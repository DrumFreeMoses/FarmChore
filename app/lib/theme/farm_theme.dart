import 'package:flutter/material.dart';
import 'package:farm_chore/domain/roles.dart';

/// FarmChore design tokens: dawn on the cottonwood row.
/// See docs/design.md for the story behind each color.
abstract final class FarmColors {
  // ── Core palette ──────────────────────────────────────────────────
  static const dawnAmber = Color(0xFFE8A33D);
  static const cottonwoodGreen = Color(0xFF4E6B3A);
  static const springBlue = Color(0xFF5B87A6);
  static const milkWhite = Color(0xFFFAF6EF);
  static const soilBrown = Color(0xFF5C4A32);
  static const hayYellow = Color(0xFFF2D58C);
  static const sabbath = Color(0xFF8C9A8A);

  // ── Semantic tokens ───────────────────────────────────────────────
  static const success = cottonwoodGreen;
  static const warning = dawnAmber;
  static const error = Color(0xFFB3261E);
  static const info = springBlue;

  static const surface = milkWhite;
  static const surfaceVariant = Color(0xFFF2EDE4);
  static const onSurface = soilBrown;
  static const outline = Color(0xFFC9BFB0);
  static const outlineVariant = Color(0xFFE0D8CC);
}

/// One accent per role, used on role headers everywhere so the same
/// role always reads the same color.
Color roleAccent(FarmRole role) => switch (role) {
  FarmRole.milkers => FarmColors.dawnAmber,
  FarmRole.pourers => FarmColors.springBlue,
  FarmRole.feeders => FarmColors.cottonwoodGreen,
  FarmRole.mechanics => FarmColors.soilBrown,
  FarmRole.farmers => FarmColors.hayYellow,
  FarmRole.nonJsf => FarmColors.sabbath,
};

/// The farm's dawn theme: cream backgrounds, soil text, amber chore accents.
/// Includes a full text theme scaled to the farm's warm palette.
ThemeData farmTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: FarmColors.cottonwoodGreen,
        brightness: Brightness.light,
      ).copyWith(
        primary: FarmColors.cottonwoodGreen,
        onPrimary: Colors.white,
        secondary: FarmColors.dawnAmber,
        onSecondary: FarmColors.soilBrown,
        tertiary: FarmColors.springBlue,
        surface: FarmColors.surface,
        onSurface: FarmColors.onSurface,
        surfaceContainerHighest: FarmColors.surfaceVariant,
        outline: FarmColors.outline,
        outlineVariant: FarmColors.outlineVariant,
        error: FarmColors.error,
        onError: Colors.white,
      );

  final textTheme = TextTheme(
    displayLarge: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 57,
      fontWeight: FontWeight.w400,
      color: FarmColors.onSurface,
    ),
    headlineLarge: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 32,
      fontWeight: FontWeight.w600,
      color: FarmColors.onSurface,
    ),
    headlineMedium: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 28,
      fontWeight: FontWeight.w600,
      color: FarmColors.onSurface,
    ),
    headlineSmall: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 24,
      fontWeight: FontWeight.w600,
      color: FarmColors.onSurface,
    ),
    titleLarge: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 22,
      fontWeight: FontWeight.w500,
      color: FarmColors.onSurface,
    ),
    titleMedium: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w500,
      color: FarmColors.onSurface,
    ),
    titleSmall: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: FarmColors.onSurface,
    ),
    bodyLarge: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 16,
      fontWeight: FontWeight.w400,
      color: FarmColors.onSurface,
    ),
    bodyMedium: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 14,
      fontWeight: FontWeight.w400,
      color: FarmColors.onSurface,
    ),
    bodySmall: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 12,
      fontWeight: FontWeight.w400,
      color: FarmColors.sabbath,
    ),
    labelLarge: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 14,
      fontWeight: FontWeight.w500,
      color: FarmColors.onSurface,
    ),
    labelMedium: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 12,
      fontWeight: FontWeight.w500,
      color: FarmColors.sabbath,
    ),
    labelSmall: const TextStyle(
      fontFamily: 'Roboto',
      fontSize: 11,
      fontWeight: FontWeight.w500,
      color: FarmColors.sabbath,
    ),
  );

  return ThemeData(
    colorScheme: scheme,
    textTheme: textTheme,
    scaffoldBackgroundColor: FarmColors.surface,
    appBarTheme: const AppBarTheme(
      backgroundColor: FarmColors.surface,
      foregroundColor: FarmColors.onSurface,
      elevation: 0,
      titleTextStyle: TextStyle(
        fontFamily: 'Roboto',
        fontSize: 20,
        fontWeight: FontWeight.w600,
        color: FarmColors.onSurface,
      ),
    ),
    cardTheme: const CardThemeData(
      color: FarmColors.surface,
      surfaceTintColor: Colors.transparent,
      elevation: 1,
      margin: EdgeInsets.symmetric(horizontal: 16, vertical: 6),
    ),
    filledButtonTheme: FilledButtonThemeData(
      style: FilledButton.styleFrom(
        backgroundColor: FarmColors.dawnAmber,
        foregroundColor: FarmColors.soilBrown,
      ),
    ),
    textButtonTheme: TextButtonThemeData(
      style: TextButton.styleFrom(foregroundColor: FarmColors.cottonwoodGreen),
    ),
    inputDecorationTheme: const InputDecorationTheme(
      filled: true,
      fillColor: FarmColors.surfaceVariant,
      border: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: FarmColors.outline),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: FarmColors.outlineVariant),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.all(Radius.circular(12)),
        borderSide: BorderSide(color: FarmColors.cottonwoodGreen, width: 2),
      ),
      contentPadding: EdgeInsets.symmetric(horizontal: 16, vertical: 12),
    ),
    dividerTheme: const DividerThemeData(
      color: FarmColors.outlineVariant,
      thickness: 1,
      space: 1,
    ),
    snackBarTheme: const SnackBarThemeData(
      backgroundColor: FarmColors.soilBrown,
      contentTextStyle: TextStyle(color: Colors.white, fontSize: 14),
    ),
  );
}
