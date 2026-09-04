import 'dart:convert';

import 'package:drift/drift.dart' show Value;

import '../core/local/database.dart' as local;
import '../models/exercise.dart';

/// Id a partir del cual arrancan los ejercicios creados por el usuario (desde
/// la app o desde una importación CSV/Excel sin correspondencia). Fuera del
/// rango del catálogo semilla (`assets/data/exercises.json`) para que nunca
/// choque con ids nuevos que llegue a agregar ese catálogo (ver E2).
const customExerciseIdStart = 1000000;

/// Reemplaza a `ExerciseService` (FastAPI) -- el catálogo ya vivía completo
/// en `Exercises.detailJson` desde que se sembró localmente
/// (`syncExerciseCatalog`, ver `local_bootstrap.dart`); esto solo corta la
/// llamada de red residual que `exercise_list_screen.dart`/
/// `exercise_detail_screen.dart` seguían haciendo pese a que el dato ya
/// estaba en el dispositivo (Fase 3c).
///
/// Punto único de escritura del catálogo (E1): antes solo el flujo de
/// importación podía crear ejercicios (`ExerciseResolver.createExercise`,
/// que ahora delegra acá). Editar/eliminar está restringido a ejercicios
/// propios (`isCustomExercise`) -- el catálogo semilla no se toca desde la
/// app.
class ExerciseRepository {
  final local.AppDatabase db;

  ExerciseRepository(this.db);

  static bool isCustomExercise(int id) => id >= customExerciseIdStart;

  static List<String> _strList(dynamic value) =>
      value == null ? [] : (value as List).map((e) => e.toString()).toList();

  Future<List<ExerciseSummary>> list({String? muscleGroup}) async {
    final query = db.select(db.exercises);
    if (muscleGroup != null) {
      query.where((t) => t.muscleGroup.equals(muscleGroup));
    }
    final rows = await query.get();
    return rows
        .map(
          (r) => ExerciseSummary(
            id: r.id,
            slug: r.slug,
            name: r.name,
            muscleGroup: r.muscleGroup,
            difficulty: r.difficulty,
            imageUrl: r.imageUrl,
          ),
        )
        .toList();
  }

  Future<Exercise> get(int id) async {
    final row = await (db.select(
      db.exercises,
    )..where((t) => t.id.equals(id))).getSingle();
    final detail = jsonDecode(row.detailJson) as Map<String, dynamic>;
    return Exercise(
      id: row.id,
      slug: row.slug,
      name: row.name,
      muscleGroup: row.muscleGroup,
      primaryMuscles: _strList(detail['primary_muscles']),
      secondaryMuscles: _strList(detail['secondary_muscles']),
      equipment: _strList(detail['equipment']),
      difficulty: row.difficulty,
      movementType: detail['movement_type'] as String? ?? '',
      imageUrl: row.imageUrl,
      animationUrl: detail['animation_url'] as String?,
      description: detail['description'] as String? ?? '',
      instructions: _strList(detail['instructions']),
      tips: _strList(detail['tips']),
      commonMistakes: _strList(detail['common_mistakes']),
      variants: _strList(detail['variants']),
      benefits: _strList(detail['benefits']),
    );
  }

  Future<int> _nextCustomId() async {
    final rows = await db.select(db.exercises).get();
    final ids = rows.map((r) => r.id).toSet();
    var nextId = customExerciseIdStart;
    while (ids.contains(nextId)) {
      nextId++;
    }
    return nextId;
  }

  /// Crea un ejercicio propio. Misma estrategia de ids que usaba
  /// `ExerciseResolver.createExercise`: id desde [customExerciseIdStart],
  /// slug `custom-<id>` -- no cambiar, evita choques cuando se amplíe el
  /// catálogo semilla (E2).
  Future<int> createExercise({
    required String name,
    required String muscleGroup,
    required List<String> equipment,
    required String movementType,
  }) async {
    final id = await _nextCustomId();
    await db
        .into(db.exercises)
        .insert(
          local.ExercisesCompanion.insert(
            id: Value(id),
            slug: 'custom-$id',
            name: name,
            muscleGroup: muscleGroup,
            difficulty: 'beginner',
            detailJson: Value(
              jsonEncode({
                'primary_muscles': const [],
                'secondary_muscles': const [],
                'equipment': equipment,
                'movement_type': movementType,
                'description': '',
                'instructions': const [],
                'tips': const [],
                'common_mistakes': const [],
                'variants': const [],
                'benefits': const [],
              }),
            ),
          ),
        );
    return id;
  }

  /// Solo para ejercicios propios -- el catálogo semilla no se edita desde
  /// la app.
  Future<void> updateExercise(
    int id, {
    required String name,
    required String muscleGroup,
    required List<String> equipment,
    required String movementType,
  }) async {
    if (!isCustomExercise(id)) {
      throw ArgumentError('Solo se pueden editar ejercicios propios.');
    }
    final row = await (db.select(
      db.exercises,
    )..where((t) => t.id.equals(id))).getSingle();
    final detail = jsonDecode(row.detailJson) as Map<String, dynamic>;
    detail['equipment'] = equipment;
    detail['movement_type'] = movementType;
    await (db.update(db.exercises)..where((t) => t.id.equals(id))).write(
      local.ExercisesCompanion(
        name: Value(name),
        muscleGroup: Value(muscleGroup),
        detailJson: Value(jsonEncode(detail)),
      ),
    );
  }

  /// True si ya hay series registradas contra este ejercicio -- eliminarlo
  /// rompería el historial, así que la UI debe avisar en vez de borrar.
  Future<bool> hasLoggedSets(int exerciseId) async {
    final row = await (db.select(db.workoutSets)
          ..where((t) => t.exerciseId.equals(exerciseId))
          ..limit(1))
        .getSingleOrNull();
    return row != null;
  }

  /// Solo para ejercicios propios sin series registradas (ver
  /// [hasLoggedSets]) -- el catálogo semilla no se borra desde la app.
  Future<void> deleteExercise(int id) async {
    if (!isCustomExercise(id)) {
      throw ArgumentError('Solo se pueden eliminar ejercicios propios.');
    }
    if (await hasLoggedSets(id)) {
      throw StateError(
        'No se puede eliminar: tiene series registradas en el historial.',
      );
    }
    await (db.delete(db.exercises)..where((t) => t.id.equals(id))).go();
  }
}
