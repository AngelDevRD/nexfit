import 'package:flutter/material.dart';
import 'package:google_fonts/google_fonts.dart';

/// Design tokens del sistema "Kinetic AI" -- paleta 2026-08-28 (feedback de
/// audio + mensaje del usuario: azul como color principal, violeta solo
/// como acento puntual, verde reservado para "éxito", fondo azul-negruzco).
///
/// D1 (auditoría Fase 5) -- roles semánticos, para que "qué color uso acá"
/// tenga una sola respuesta en vez de improvisarse pantalla por pantalla:
///
/// - `primary`: la acción principal de cada pantalla (CTA, tab seleccionado,
///   FAB). Es el único color que debe aparecer en un botón `FilledButton`
///   por defecto.
/// - `secondary` (verde): EXCLUSIVAMENTE éxito/logro -- serie completada,
///   racha, XP, PR roto. Nunca como color de botón de acción neutra; si un
///   verde aparece en pantalla, tiene que significar "algo se logró".
/// - `tertiary` (violeta): acento puntual, no un color de uso general. Vive
///   en como mucho 1-2 elementos "especiales" por pantalla (la tarjeta
///   "Gemelo Digital", un badge de nivel) -- si aparece en más de eso, es la
///   señal de que se está usando como relleno en vez de como acento.
/// - `danger`: errores y acciones destructivas (borrar, deshacer). Nunca
///   decorativo.
/// - `warning`: estados de precaución (deload recomendado, fatiga alta) --
///   no intercambiable con `danger`.
/// - `onSurfaceVariant`: texto secundario/metadata sobre fondos oscuros.
///   Contraste verificado (D3): #94A3B8 sobre `surfaceContainer` (#151922)
///   da ~5.3:1, sobre `background` (#0B0D12) da ~6.4:1 -- ambos superan el
///   mínimo AA de 4.5:1 para texto normal.
///
/// `AppGlow` (sombra tintada) se reserva para tarjetas "hero"/celebratorias
/// (racha, nivel, PR) -- nunca como sombra por defecto de una tarjeta común
/// (esas usan `cardTheme`/`surfaceContainer` planos, sin elevación). Ver la
/// nota en la clase `AppGlow` más abajo.
///
/// `AppGradients` se reserva para UN solo tipo de elemento: la tarjeta de
/// acento "especial" (hoy, "Gemelo Digital"). No es un recurso decorativo de
/// uso libre -- si hiciera falta un segundo lugar con gradiente, tendría que
/// ser igual de "especial" que ese, no una tarjeta más.
class AppColors {
  static const primary = Color(0xFF4F7CFF);
  static const onPrimary = Color(0xFF071233);
  static const primaryContainer = Color(0xFF4F7CFF);
  static const onPrimaryContainer = Color(0xFFF8FAFC);
  // Verde reservado exclusivamente como señal de "éxito" (racha, serie
  // completada, XP) -- ya no convive visualmente con el violeta como un
  // segundo acento, así se evita el choque morado+verde reportado.
  static const secondary = Color(0xFF22C55E);
  static const onSecondary = Color(0xFF06280F);
  static const secondaryContainer = Color(0xFF16A34A);
  static const onSecondaryContainer = Color(0xFFEFFFF5);
  // Acento puntual -- deliberadamente el rol menos usado en la app (tarjeta
  // "Gemelo Digital", detalles especiales), nunca el color base de botones.
  static const tertiary = Color(0xFF8B5CF6);
  static const onTertiary = Color(0xFF1E1033);
  static const tertiaryContainer = Color(0xFF7C3AED);
  static const onTertiaryContainer = Color(0xFFF5F3FF);
  static const danger = Color(0xFFEF4444);
  static const onDanger = Color(0xFFFFF1F1);
  static const dangerContainer = Color(0xFFB91C1C);
  static const onDangerContainer = Color(0xFFFFF1F1);
  static const warning = Color(0xFFFFB020);

  static const background = Color(0xFF0B0D12);
  static const onBackground = Color(0xFFF8FAFC);
  static const onSurfaceVariant = Color(0xFF94A3B8);
  static const outline = Color(0xFF5B6B85);
  static const outlineVariant = Color(0xFF232B38);
  static const surfaceContainerLowest = Color(0xFF07090D);
  static const surfaceContainerLow = Color(0xFF0F131A);
  static const surfaceContainer = Color(0xFF151922);
  static const surfaceContainerHigh = Color(0xFF1C212C);
  static const surfaceContainerHighest = Color(0xFF262D3A);
  static const inversePrimary = Color(0xFF2952CC);

  static const darkBackground = background;
  static const darkSurface = surfaceContainer;
  static const lightBackground = Color(0xFFF7F7FB);
  static const lightSurface = Color(0xFFFFFFFF);
}

/// Radios de esquina del sistema Kinetic AI (rounded-sm/DEFAULT/md/lg/xl/full).
class AppRadius {
  static const sm = 4.0;
  static const md = 12.0;
  // Tarjetas grandes en 18-24px (pedido explícito de "esquinas más
  // redondeadas para que se sienta app móvil, no web").
  static const lg = 18.0;
  // Tarjetas "hero" (ejercicio en vivo, próximo entrenamiento) -- v2 mockups.
  static const xxl = 20.0;
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

/// D2: la jerarquía tipográfica vive en `Theme.of(context).textTheme`
/// (`GoogleFonts.interTextTheme`, escala Material 3 -- labelSmall 11,
/// labelMedium 12, labelLarge 14, bodySmall 12, bodyMedium 14, bodyLarge 16,
/// titleSmall 14, titleMedium 16, titleLarge 22, headlineSmall 24...). Un
/// `TextStyle(fontSize: N)` escrito a mano en una pantalla es casi siempre
/// una talla de esa escala reinventada a mano -- usar `textTheme.bodySmall`/
/// `labelMedium`/etc. (con `.copyWith` solo para color/peso) en vez de un
/// número suelto.
///
/// La única excepción real es la etiqueta de eje de un gráfico (fl_chart):
/// más chica que cualquier entrada de la escala porque compite por espacio
/// contra el propio gráfico. Se nombra acá en vez de repetir `fontSize: 10`
/// en cada pantalla con gráfico.
class AppTypography {
  static const chartAxisLabel = TextStyle(
    fontSize: 10,
    color: AppColors.onSurfaceVariant,
  );
}

/// Sombras "glow" tintadas del color de acento, reemplazando el uso de
/// `BoxShadow` escrito a mano en cada pantalla (export Stitch v2, ver
/// design/stitch_nexfit_ai_personal_trainer/kinetic_ai/DESIGN.md).
///
/// D1: uso reservado a tarjetas "hero"/celebratorias (nivel, racha, PR
/// roto, tarjeta de acento especial) -- una tarjeta común (lista de
/// ejercicios, historial, medidas) NO lleva glow, usa el `cardTheme` plano.
/// Ver la nota de roles en `AppColors`.
class AppGlow {
  static List<BoxShadow> tint(
    Color color, {
    double opacity = 0.35,
    double blur = 24,
  }) => [
    BoxShadow(
      color: color.withValues(alpha: opacity),
      blurRadius: blur,
    ),
  ];

  static List<BoxShadow> get primary => tint(AppColors.primaryContainer);
  static List<BoxShadow> get secondary =>
      tint(AppColors.secondary, opacity: 0.4, blur: 16);
  // Uso puntual (tarjetas "especiales"), no como sombra por defecto.
  static List<BoxShadow> get tertiary =>
      tint(AppColors.tertiaryContainer, opacity: 0.3, blur: 20);
}

/// Gradientes discretos reutilizables -- por ahora solo el azul->violeta ya
/// usado en la tarjeta "Gemelo Digital", extraído para no repetirlo a mano
/// en cada lugar donde se quiera el mismo acento puntual.
class AppGradients {
  static const heroAccent = LinearGradient(
    begin: Alignment.topLeft,
    end: Alignment.bottomRight,
    colors: [AppColors.primaryContainer, AppColors.tertiaryContainer],
  );
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
        indicatorColor: AppColors.primaryContainer,
        // height reducida (M3 por defecto es 80, se sentía muy grande) y
        // shadow/tint apagados a mano -- el tint de superficie de M3 se veía
        // como un sombreado raro encima de la barra.
        height: 64,
        elevation: 0,
        surfaceTintColor: Colors.transparent,
        shadowColor: Colors.transparent,
      ),
      filledButtonTheme: FilledButtonThemeData(
        style: FilledButton.styleFrom(
          backgroundColor: AppColors.primaryContainer,
          foregroundColor: AppColors.onPrimaryContainer,
          elevation: 3,
          shadowColor: AppColors.primaryContainer.withValues(alpha: 0.6),
          side: BorderSide(color: Colors.white.withValues(alpha: 0.08)),
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

/// D1: antes eran 10 acentos saturados elegidos sueltos (#FF5470, #6C5CE7,
/// #00D9A3...) que no salían de ninguna paleta y competían visualmente con
/// el azul/verde/violeta del tema. Acá los 10 comparten la MISMA saturación
/// y luminosidad (S 65%, L 58%) y sus tonos están espaciados uniformemente
/// cada 36° en la rueda de color -- una progresión analógica que además pasa
/// literalmente por los 4 anclajes semánticos del tema (`primary` en 225°,
/// `secondary` en 153°, `warning` en 45°, `tertiary` en 261°), así que el
/// conjunto entero se lee como parte de la misma familia en vez de un
/// arcoíris improvisado. Nunca se reusa el hex exacto de un color semántico
/// (el significado "éxito"/"error" queda intacto en otro lugar).
const muscleGroupColors = <String, Color>{
  'Pecho': Color(0xFF4E71DA), // 225° -- junto a `primary`
  'Espalda': Color(0xFF7F4EDA), // 261° -- junto a `tertiary`
  'Hombros': Color(0xFFDAB74E), // 45° -- junto a `warning`
  'Bíceps': Color(0xFF4EDA8D), // 153° -- junto a `secondary`
  'Tríceps': Color(0xFFDA634E), // 9°
  'Cuádriceps': Color(0xFF55DA4E), // 117°
  'Isquiotibiales': Color(0xFFA9DA4E), // 81°
  'Glúteos': Color(0xFFDA4E8D), // 333°
  'Pantorrillas': Color(0xFF4EC5DA), // 189°
  'Core': Color(0xFFD34EDA), // 297°
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
