import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens del sistema "Kinetic AI" (export Stitch 2026-07-03,
/// ver design/stitch_appgym_ai_coach/kinetic_ai/DESIGN.md).
class AppColors {
  static const primary = Color(0xFFC6BFFF);
  static const onPrimary = Color(0xFF2900A0);
  static const primaryContainer = Color(0xFF6C5CE7);
  static const onPrimaryContainer = Color(0xFFFAF6FF);
  static const secondary = Color(0xFF44F5BD);
  static const onSecondary = Color(0xFF003828);
  static const secondaryContainer = Color(0xFF00D8A2);
  static const onSecondaryContainer = Color(0xFF005840);
  static const tertiary = Color(0xFF8ACEFF);
  static const onTertiary = Color(0xFF00344E);
  static const tertiaryContainer = Color(0xFF0079AE);
  static const onTertiaryContainer = Color(0xFFF4F8FF);
  static const danger = Color(0xFFFFB4AB);
  static const onDanger = Color(0xFF690005);
  static const dangerContainer = Color(0xFF93000A);
  static const onDangerContainer = Color(0xFFFFDAD6);
  static const warning = Color(0xFFFFB020);

  static const background = Color(0xFF131319);
  static const onBackground = Color(0xFFE4E1EA);
  static const onSurfaceVariant = Color(0xFFC8C4D7);
  static const outline = Color(0xFF928EA0);
  static const outlineVariant = Color(0xFF474554);
  static const surfaceContainerLowest = Color(0xFF0E0E14);
  static const surfaceContainerLow = Color(0xFF1B1B21);
  static const surfaceContainer = Color(0xFF1F1F25);
  static const surfaceContainerHigh = Color(0xFF2A2930);
  static const surfaceContainerHighest = Color(0xFF34343B);
  static const inversePrimary = Color(0xFF5847D2);

  static const darkBackground = background;
  static const darkSurface = surfaceContainer;
  static const lightBackground = Color(0xFFF7F7FB);
  static const lightSurface = Color(0xFFFFFFFF);
}

/// Radios de esquina del sistema Kinetic AI (rounded-sm/DEFAULT/md/lg/xl/full).
class AppRadius {
  static const sm = 4.0;
  static const md = 12.0;
  static const lg = 16.0;
  static const xl = 24.0;
  static const full = 999.0;
}

/// Espaciado del grid de 8px del sistema Kinetic AI.
class AppSpacing {
  static const xs = 4.0;
  static const sm = 8.0;
  static const md = 16.0;
  static const lg = 24.0;
  static const xl = 32.0;
}

class AppTheme {
  static ThemeData light() {
    final scheme = ColorScheme.fromSeed(
      seedColor: AppColors.primaryContainer,
      brightness: Brightness.light,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: GoogleFonts.interTextTheme(),
      scaffoldBackgroundColor: AppColors.lightBackground,
      appBarTheme: const AppBarTheme(centerTitle: false, elevation: 0),
      cardTheme: CardThemeData(
        color: AppColors.lightSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.lightSurface,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
      ),
    );
  }

  static ThemeData dark() {
    final scheme = ColorScheme.dark(
      primary: AppColors.primary,
      onPrimary: AppColors.onPrimary,
      primaryContainer: AppColors.primaryContainer,
      onPrimaryContainer: AppColors.onPrimaryContainer,
      secondary: AppColors.secondary,
      onSecondary: AppColors.onSecondary,
      secondaryContainer: AppColors.secondaryContainer,
      onSecondaryContainer: AppColors.onSecondaryContainer,
      tertiary: AppColors.tertiary,
      onTertiary: AppColors.onTertiary,
      tertiaryContainer: AppColors.tertiaryContainer,
      onTertiaryContainer: AppColors.onTertiaryContainer,
      error: AppColors.danger,
      onError: AppColors.onDanger,
      errorContainer: AppColors.dangerContainer,
      onErrorContainer: AppColors.onDangerContainer,
      surface: AppColors.background,
      onSurface: AppColors.onBackground,
      onSurfaceVariant: AppColors.onSurfaceVariant,
      outline: AppColors.outline,
      outlineVariant: AppColors.outlineVariant,
      surfaceContainerLowest: AppColors.surfaceContainerLowest,
      surfaceContainerLow: AppColors.surfaceContainerLow,
      surfaceContainer: AppColors.surfaceContainer,
      surfaceContainerHigh: AppColors.surfaceContainerHigh,
      surfaceContainerHighest: AppColors.surfaceContainerHighest,
      inversePrimary: AppColors.inversePrimary,
    );
    final coloredText = ThemeData.dark().textTheme.apply(
      bodyColor: AppColors.onBackground,
      displayColor: AppColors.onBackground,
    );
    return ThemeData(
      useMaterial3: true,
      colorScheme: scheme,
      textTheme: GoogleFonts.interTextTheme(coloredText),
      scaffoldBackgroundColor: AppColors.darkBackground,
      appBarTheme: const AppBarTheme(
        centerTitle: false,
        elevation: 0,
        backgroundColor: AppColors.darkBackground,
      ),
      cardTheme: CardThemeData(
        color: AppColors.darkSurface,
        elevation: 0,
        shape: RoundedRectangleBorder(
          borderRadius: BorderRadius.circular(AppRadius.lg),
        ),
      ),
      inputDecorationTheme: InputDecorationTheme(
        filled: true,
        fillColor: AppColors.surfaceContainerLow,
        border: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: BorderSide.none,
        ),
        focusedBorder: OutlineInputBorder(
          borderRadius: BorderRadius.circular(AppRadius.md),
          borderSide: const BorderSide(color: AppColors.primary, width: 2),
        ),
      ),
      navigationBarTheme: NavigationBarThemeData(
        backgroundColor: AppColors.surfaceContainer,
        indicatorColor: AppColors.secondaryContainer,
        elevation: 0,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: AppColors.onPrimaryContainer,
          shape: RoundedRectangleBorder(
            borderRadius: BorderRadius.circular(AppRadius.md),
          ),
        ),
      ),
      floatingActionButtonTheme: const FloatingActionButtonThemeData(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
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
