import 'package:flutter/material.dart';

class AppColors {
  static const primary = Color(0xFF6C5CE7);
  static const secondary = Color(0xFF00D9A3);
  static const danger = Color(0xFFFF5470);
  static const warning = Color(0xFFFFB020);
  static const darkBackground = Color(0xFF121218);
  static const darkSurface = Color(0xFF1C1C26);
  static const lightBackground = Color(0xFFF7F7FB);
  static const lightSurface = Color(0xFFFFFFFF);
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primary,
      brightness: Brightness.dark,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(16)),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.darkSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(12),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }
}

const muscleGroupColors = <String, Color>{
  'Pecho': Color(0xFFFF5470),
  'Espalda': Color(0xFF6C5CE7),
  'Hombros': Color(0xFFFFB020),
  'Bíceps': Color(0xFF00D9A3),
  'Tríceps': Color(0xFF0FA3E8),
  'Cuádriceps': Color(0xFFE84393),
  'Isquiotibiales': Color(0xFFA55EEA),
  'Glúteos': Color(0xFFFD79A8),
  'Pantorrillas': Color(0xFF00B894),
  'Core': Color(0xFFFDCB6E),
};

Color colorForLevel(String level) {
  switch (level) {
    case 'alto':
      return AppColors.danger;
    case 'medio':
      return AppColors.warning;
    case 'bajo':
      return AppColors.secondary;
    default:
      return Colors.blueGrey;
  }
}
