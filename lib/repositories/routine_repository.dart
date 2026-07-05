import 'package:drift/drift.dart';

import '../core/local/database.dart' as local;
import '../models/exercise.dart';
import '../models/routine.dart';

/// Reemplaza a `RoutineService` como punto de acceso de las screens: lee y
/// escribe contra la base local (fuente de verdad offline-first). Cada
/// mutación marca `dirty=true` para que el `SyncEngine` la suba cuando haya
/// conexión. Los ids que devuelve son siempre LOCALES (autoincrement de
/// Drift) -- la traducción a `serverId` pasa solo dentro de la capa de sync.
///
/// Nota: las clases generadas por Drift para las filas (`Routine`,
/// `RoutineDay`, `RoutineExercise`) tienen el mismo nombre que los modelos de
/// dominio en `lib/models/routine.dart` -- por eso el import de la base local
/// va con prefijo `local.`.
class RoutineRepository {
  final local.AppDatabase db;

  RoutineRepository(this.db);

  Future<List<RoutineSummary>> list() async {
    final rows = await (db.select(
      db.routines,
    )..where((t) => t.deleted.equals(false))).get();
    return rows
        .map(
          (r) => RoutineSummary(
            id: r.id,
            name: r.name,
            goal: r.goal,
            daysPerWeek: r.daysPerWeek,
          ),
        )
        .toList();
  }

  Future<Routine> get(int id) async {
    final routine = await (db.select(
      db.routines,
    )..where((t) => t.id.equals(id))).getSingle();
    final dayRows = await (db.select(
      db.routineDays,
    )..where((t) => t.routineId.equals(id))).get();
    dayRows.sort((a, b) => a.dayIndex.compareTo(b.dayIndex));

    final days = <RoutineDay>[];
    for (final day in dayRows) {
      final exerciseRows = await (db.select(
        db.routineExercises,
      )..where((t) => t.dayId.equals(day.id))).get();
      exerciseRows.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      final exercises = <RoutineExercise>[];
      for (final ex in exerciseRows) {
        final exerciseRow = await (db.select(
          db.exercises,
        )..where((t) => t.id.equals(ex.exerciseId))).getSingle();
        exercises.add(
          RoutineExercise(
            id: ex.id,
            order: ex.orderIndex,
            targetSets: ex.targetSets,
            targetRepsMin: ex.targetRepsMin,
            targetRepsMax: ex.targetRepsMax,
            targetRestSeconds: ex.targetRestSeconds,
            notes: ex.notes,
            exercise: ExerciseSummary(
              id: exerciseRow.id,
              slug: exerciseRow.slug,
              name: exerciseRow.name,
              muscleGroup: exerciseRow.muscleGroup,
              difficulty: exerciseRow.difficulty,
              imageUrl: exerciseRow.imageUrl,
            ),
          ),
        );
      }

      days.add(
        RoutineDay(
          id: day.id,
          dayIndex: day.dayIndex,
          name: day.name,
          muscleFocus: day.muscleFocus,
          exercises: exercises,
        ),
      );
    }

    return Routine(
      id: routine.id,
      name: routine.name,
      goal: routine.goal,
      daysPerWeek: routine.daysPerWeek,
      days: days,
    );
  }

  /// [payload] tiene la misma forma que ya arma `routine_builder_screen.dart`
  /// para el backend (name/goal/days_per_week/days[].exercises[]...).
  Future<int> create(Map<String, dynamic> payload) async {
    return db.transaction(() async {
      final routineId = await db
          .into(db.routines)
          .insert(
            local.RoutinesCompanion.insert(
              name: payload['name'] as String,
              goal: Value(payload['goal'] as String?),
              daysPerWeek: Value((payload['days'] as List).length),
              updatedAt: DateTime.now(),
            ),
          );

      for (final dayPayload in (payload['days'] as List)) {
        final day = dayPayload as Map<String, dynamic>;
        final dayId = await db
            .into(db.routineDays)
            .insert(
              local.RoutineDaysCompanion.insert(
                routineId: routineId,
                dayIndex: day['day_index'] as int,
                name: day['name'] as String,
                muscleFocus: Value(day['muscle_focus'] as String?),
              ),
            );

        for (final exPayload in (day['exercises'] as List)) {
          final ex = exPayload as Map<String, dynamic>;
          await db
              .into(db.routineExercises)
              .insert(
                local.RoutineExercisesCompanion.insert(
                  dayId: dayId,
                  exerciseId: ex['exercise_id'] as int,
                  orderIndex: ex['order'] as int,
                  targetSets: Value(ex['target_sets'] as int? ?? 3),
                  targetRepsMin: Value(ex['target_reps_min'] as int? ?? 8),
                  targetRepsMax: Value(ex['target_reps_max'] as int? ?? 12),
                  targetRestSeconds: Value(
                    ex['target_rest_seconds'] as int? ?? 90,
                  ),
                  notes: Value(ex['notes'] as String?),
                ),
              );
        }
      }

      return routineId;
    });
  }

  Future<void> delete(int id) async {
    await (db.update(db.routines)..where((t) => t.id.equals(id))).write(
      local.RoutinesCompanion(
        deleted: const Value(true),
        dirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }
}
