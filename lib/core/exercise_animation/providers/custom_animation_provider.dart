import 'package:flutter/services.dart' show rootBundle;

import '../exercise_animation.dart';
import '../exercise_animation_provider.dart';

/// Recursos propios (grabados o generados por AppGym), para cuando se
/// reemplace el dataset de terceros. Hoy no hay ningún archivo bundleado
/// bajo `assets/animations/custom/` -- este proveedor ya sabe buscarlos ahí,
/// simplemente no encuentra nada todavía y por eso `AnimationRepository`
/// sigue cayendo a los proveedores de menor prioridad.
///
/// El día que se agreguen archivos reales a esa carpeta (con el nombre
/// `<slug>.<extensión>`) y se declaren en `pubspec.yaml`, empiezan a
/// aparecer solos: no hace falta tocar este archivo ni ningún otro. Probar
/// primero el formato con mejor calidad/control (video) y por último el más
/// simple (imagen estática) es una decisión de este proveedor, no de
/// `AnimationRepository`.
class CustomAnimationProvider implements ExerciseAnimationProvider {
  static const _basePath = 'assets/animations/custom';

  static const _extensionsByType = <AnimationType, String>{
    AnimationType.mp4: 'mp4',
    AnimationType.webm: 'webm',
    AnimationType.gif: 'gif',
    AnimationType.lottie: 'json',
    AnimationType.image: 'webp',
  };

  @override
  final int priority;

  /// Prioridad 0 por defecto: los recursos propios siempre se prueban antes
  /// que cualquier proveedor de terceros.
  CustomAnimationProvider({this.priority = 0});

  Future<bool> _assetExists(String path) async {
    try {
      await rootBundle.load(path);
      return true;
    } catch (_) {
      return false;
    }
  }

  String _pathFor(String exerciseSlug, String extension) =>
      '$_basePath/$exerciseSlug.$extension';

  Future<ExerciseAnimation?> _firstMatch(String exerciseSlug) async {
    for (final entry in _extensionsByType.entries) {
      final path = _pathFor(exerciseSlug, entry.value);
      if (await _assetExists(path)) {
        return ExerciseAnimation(
          id: exerciseSlug,
          animationPath: path,
          animationType: entry.key,
          provider: 'custom',
        );
      }
    }
    return null;
  }

  @override
  Future<bool> hasAnimation(String exerciseSlug) async =>
      (await _firstMatch(exerciseSlug)) != null;

  @override
  Future<ExerciseAnimation?> getAnimation(String exerciseSlug) =>
      _firstMatch(exerciseSlug);
}
