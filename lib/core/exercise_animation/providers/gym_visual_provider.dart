import 'dart:convert';

import 'package:flutter/services.dart' show rootBundle;

import '../exercise_animation.dart';
import '../exercise_animation_provider.dart';

/// Único punto del proyecto que conoce el dataset
/// https://github.com/hasaneyldrm/exercises-dataset (GymVisual): estructura
/// de `exercises.json`, mapeo de slug -> archivo de GIF, y los términos de
/// atribución/licencia de la media.
///
/// Es una implementación **temporal**: el día que se reemplace por recursos
/// propios, este archivo se borra entero y nada más en la app cambia --
/// [ExerciseAnimationProvider] es lo único de lo que depende el resto del
/// código.
///
/// Licencia de la media (ver `assets/models_3d/README.md`): los GIFs son
/// © Gym visual (https://gymvisual.com/), incluidos con permiso, solo a
/// 180x180 y con atribución obligatoria -- por eso [ExerciseAnimation]
/// siempre trae `attribution` seteado acá, nunca `null`.
class GymVisualProvider implements ExerciseAnimationProvider {
  static const _mappingAssetPath = 'assets/data/gymvisual_animations.json';
  static const _attribution = '© Gym visual — https://gymvisual.com/';

  @override
  final int priority;

  /// Prioridad 10 por defecto: se consulta recién si ningún proveedor de
  /// mayor prioridad (ej. recursos propios) tuvo algo para el ejercicio.
  GymVisualProvider({this.priority = 10});

  Map<String, dynamic>? _mapping;

  Future<Map<String, dynamic>> _loadMapping() async {
    if (_mapping != null) return _mapping!;
    try {
      final raw = await rootBundle.loadString(_mappingAssetPath);
      _mapping = jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      // Archivo no bundleado todavía (falta declarar/poblar
      // assets/data/gymvisual_animations.json) -- sin dataset, sin
      // animaciones de este proveedor. No es un error de la app.
      _mapping = const {};
    }
    return _mapping!;
  }

  Future<Map<String, dynamic>?> _entryFor(String exerciseSlug) async {
    final mapping = await _loadMapping();
    return mapping[exerciseSlug] as Map<String, dynamic>?;
  }

  @override
  Future<bool> hasAnimation(String exerciseSlug) async {
    return (await _entryFor(exerciseSlug)) != null;
  }

  @override
  Future<ExerciseAnimation?> getAnimation(String exerciseSlug) async {
    final entry = await _entryFor(exerciseSlug);
    if (entry == null) return null;
    final gifPath = entry['gif_path'] as String?;
    if (gifPath == null) return null;
    return ExerciseAnimation(
      id: exerciseSlug,
      animationPath: gifPath,
      animationType: AnimationType.gif,
      provider: 'gymvisual',
      attribution: _attribution,
    );
  }
}
