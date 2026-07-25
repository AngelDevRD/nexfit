import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../local/database.dart';
import '../syncable.dart';

/// Sync de Rutinas contra Supabase (Fase 2, ver docs/ARQUITECTURA_BACKEND.md
/// -- antes apuntaba a FastAPI vía `RoutineService`/`ApiClient`). Solo
/// create-or-delete: la tabla `routines` de Supabase no soporta edición
/// parcial desde acá y la UI actual tampoco edita rutinas ya guardadas, así
/// que una rutina con `serverId != null` que vuelve a quedar `dirty`
/// simplemente se ignora (no hay forma de subir el diff hoy).
class RoutineSyncable implements SyncableEntity {
  final sb.SupabaseClient client;

  RoutineSyncable(this.client);

  @override
  String get name => 'routines';

  @override
  Future<void> push(AppDatabase db) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return; // sin sesión, nada que sincronizar todavía.

    final dirty = await (db.select(
      db.routines,
    )..where((t) => t.dirty.equals(true))).get();

    for (final routine in dirty) {
      if (routine.deleted) {
        await _pushDelete(db, routine);
      } else if (routine.serverId == null) {
        await _pushCreate(db, routine, userId);
      } else {
        // Ya sincronizada y sin soporte de edición -- limpiar el flag para
        // no reintentar en cada pasada.
        await (db.update(db.routines)..where((t) => t.id.equals(routine.id)))
            .write(const RoutinesCompanion(dirty: Value(false)));
      }
    }
  }

  Future<void> _pushCreate(
    AppDatabase db,
    Routine routine,
    String userId,
  ) async {
    final createdRoutine = await client
        .from('nexfit_routines')
        .insert({
          'user_id': userId,
          'name': routine.name,
          'goal': routine.goal,
          'days_per_week': routine.daysPerWeek,
        })
        .select()
        .single();
    final routineServerId = createdRoutine['id'] as String;

    final days = await (db.select(
      db.routineDays,
    )..where((t) => t.routineId.equals(routine.id))).get();
    days.sort((a, b) => a.dayIndex.compareTo(b.dayIndex));

    for (final day in days) {
      final createdDay = await client
          .from('nexfit_routine_days')
          .insert({
            'routine_id': routineServerId,
            'day_index': day.dayIndex,
            'name': day.name,
            'muscle_focus': day.muscleFocus,
          })
          .select()
          .single();
      final dayServerId = createdDay['id'] as String;

      final exercises = await (db.select(
        db.routineExercises,
      )..where((t) => t.dayId.equals(day.id))).get();
      exercises.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      if (exercises.isNotEmpty) {
        await client.from('nexfit_routine_exercises').insert([
          for (final ex in exercises)
            {
              'routine_day_id': dayServerId,
              'exercise_id': ex.exerciseId,
              'order_index': ex.orderIndex,
              'target_sets': ex.targetSets,
              'target_reps_min': ex.targetRepsMin,
              'target_reps_max': ex.targetRepsMax,
              'target_rest_seconds': ex.targetRestSeconds,
              'notes': ex.notes,
            },
        ]);
      }
    }

    await (db.update(db.routines)..where((t) => t.id.equals(routine.id))).write(
      RoutinesCompanion(
        serverId: Value(routineServerId),
        dirty: const Value(false),
      ),
    );
  }

  Future<void> _pushDelete(AppDatabase db, Routine routine) async {
    if (routine.serverId != null) {
      // Cascade en Supabase se encarga de routine_days/routine_exercises.
      await client.from('nexfit_routines').delete().eq('id', routine.serverId!);
    }
    await (db.delete(db.routines)..where((t) => t.id.equals(routine.id))).go();
  }
}
