import 'dart:convert';

import '../core/local/database.dart' as local;
import '../models/exercise.dart';

/// Reemplaza a `ExerciseService` (FastAPI) -- el catálogo ya vivía completo
/// en `Exercises.detailJson` desde que se sembró localmente
/// (`seedExercisesIfEmpty`, ver `local_bootstrap.dart`); esto solo corta la
/// llamada de red residual que `exercise_list_screen.dart`/
/// `exercise_detail_screen.dart` seguían haciendo pese a que el dato ya
/// estaba en el dispositivo (Fase 3c).
class ExerciseRepository {
  final local.AppDatabase db;

  ExerciseRepository(this.db);

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
}
