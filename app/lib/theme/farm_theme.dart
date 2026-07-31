import 'package:flutter/material.dart';

/// FarmChore design tokens: dawn on the cottonwood row.
/// See docs/design.md for the story behind each color.
abstract final class FarmColors {
  static const dawnAmber = Color(0xFFE8A33D);
  static const cottonwoodGreen = Color(0xFF4E6B3A);
  static const springBlue = Color(0xFF5B87A6);
  static const milkWhite = Color(0xFFFAF6EF);
  static const soilBrown = Color(0xFF5C4A32);
  static const hayYellow = Color(0xFFF2D58C);
  static const sabbath = Color(0xFF8C9A8A);
}

/// The farm's dawn theme: cream backgrounds, soil text, amber chore accents.
ThemeData farmTheme() {
  final scheme =
      ColorScheme.fromSeed(
        seedColor: FarmColors.cottonwoodGreen,
        brightness: Brightness.light,
      ).copyWith(
        primary: FarmColors.cottonwoodGreen,
        secondary: FarmColors.dawnAmber,
        tertiary: FarmColors.springBlue,
        surface: FarmColors.milkWhite,
        onSurface: FarmColors.soilBrown,
        error: Color(0xFFB3261E),
      );

  return ThemeData(
    colorScheme: scheme,
    scaffoldBackgroundColor: FarmColors.milkWhite,
    appBarTheme: const AppBarTheme(
      backgroundColor: FarmColors.milkWhite,
      foregroundColor: FarmColors.soilBrown,
      elevation: 0,
    ),
    cardTheme: const CardThemeData(
      color: FarmColors.milkWhite,
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
  );
}
