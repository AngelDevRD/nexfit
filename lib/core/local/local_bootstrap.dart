import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:flutter/foundation.dart' show visibleForTesting;
import 'package:flutter/services.dart' show rootBundle;
import 'package:shared_preferences/shared_preferences.dart';

import 'database.dart';

const _catalogVersionPrefsKey = 'exercise_catalog_version';

/// E2: reemplaza a la vieja `seedExercisesIfEmpty`, que solo sembraba el
/// catálogo la primera vez (`if (existing.isNotEmpty) return`) -- ampliar
/// `assets/data/exercises.json` no le llegaba a ningún usuario que ya
/// tuviera la app instalada.
///
/// Fusión idempotente por `slug`: agrega los ejercicios nuevos del catálogo,
/// actualiza los datos (nombre/grupo/dificultad/detalle) de los que ya
/// existían, y NUNCA toca ejercicios propios (`ExerciseRepository.
/// isCustomExercise`, id desde 1.000.000 -- sus slugs (`custom-` + el id) no
/// coinciden con ningún slug del catálogo semilla, así que quedan afuera de
/// este merge sin necesidad de filtrarlos a mano) ni cambia el id de una
/// fila existente (si lo hiciera, las series ya registradas contra ese id
/// en `WorkoutSets` quedarían apuntando a un ejercicio distinto).
///
/// Se re-ejecuta solo cuando el contenido de `exercises.json` cambió --
/// versión guardada en preferencias como el hash del archivo crudo, no en
/// cada arranque.
Future<void> syncExerciseCatalog(AppDatabase db) async {
  final raw = await rootBundle.loadString('assets/data/exercises.json');
  await mergeExerciseCatalog(db, raw);
}

/// Lógica de la fusión, separada de la carga del asset para poder probarla
/// con un catálogo arbitrario (viejo/ampliado) sin depender del contenido
/// real de `assets/data/exercises.json`.
@visibleForTesting
Future<void> mergeExerciseCatalog(AppDatabase db, String rawCatalogJson) async {
  final currentVersion = rawCatalogJson.hashCode.toString();

  final prefs = await SharedPreferences.getInstance();
  if (prefs.getString(_catalogVersionPrefsKey) == currentVersion) return;

  final list = (jsonDecode(rawCatalogJson) as List).cast<Map<String, dynamic>>();
  final existingBySlug = {
    for (final row in await db.select(db.exercises).get()) row.slug: row,
  };

  await db.batch((b) {
    for (final e in list) {
      final slug = e['slug'] as String;
      final detailJson = jsonEncode({
        'primary_muscles': e['primary_muscles'],
        'secondary_muscles': e['secondary_muscles'],
        'equipment': e['equipment'],
        'movement_type': e['movement_type'],
        'description': e['description'],
        'instructions': e['instructions'],
        'tips': e['tips'],
        'common_mistakes': e['common_mistakes'],
        'variants': e['variants'],
        'benefits': e['benefits'],
      });
      final existing = existingBySlug[slug];
      if (existing == null) {
        // Nuevo en el catálogo -- se inserta con el id que trae el JSON.
        b.insert(
          db.exercises,
          ExercisesCompanion.insert(
            id: Value(e['id'] as int),
            slug: slug,
            name: e['name'] as String,
            muscleGroup: e['muscle_group'] as String,
            difficulty: e['difficulty'] as String,
            imageUrl: Value(e['image_url'] as String?),
            detailJson: Value(detailJson),
          ),
        );
      } else {
        // Ya existía -- se actualizan los datos del catálogo, pero NUNCA el
        // id de la fila (`existing.id`, no `e['id']`): es lo que preserva
        // las series ya registradas contra este ejercicio.
        b.update(
          db.exercises,
          ExercisesCompanion(
            name: Value(e['name'] as String),
            muscleGroup: Value(e['muscle_group'] as String),
            difficulty: Value(e['difficulty'] as String),
            imageUrl: Value(e['image_url'] as String?),
            detailJson: Value(detailJson),
          ),
          where: (t) => t.id.equals(existing.id),
        );
      }
    }
  });

  await prefs.setString(_catalogVersionPrefsKey, currentVersion);
}
