import 'package:drift/drift.dart';

import '../../../services/routine_service.dart';
import '../../api_client.dart';
import '../../local/database.dart';
import '../syncable.dart';

/// Sync de Rutinas: create-or-delete únicamente. El backend
/// (`/api/v1/routines`) no expone PATCH y la UI actual tampoco edita rutinas
/// ya guardadas, así que una rutina con `serverId != null` que vuelve a
/// quedar `dirty` simplemente se ignora (no hay forma de subir el diff hoy).
class RoutineSyncable implements SyncableEntity {
  final ApiClient client;
  late final RoutineService _service = RoutineService(client);

  RoutineSyncable(this.client);

  @override
  String get name => 'routines';

  @override
  Future<void> push(AppDatabase db) async {
    final dirty = await (db.select(
      db.routines,
    )..where((t) => t.dirty.equals(true))).get();

    for (final routine in dirty) {
      if (routine.deleted) {
        await _pushDelete(db, routine);
      } else if (routine.serverId == null) {
        await _pushCreate(db, routine);
      } else {
        // Ya sincronizada y sin soporte de edición -- limpiar el flag para
        // no reintentar en cada pasada.
        await (db.update(db.routines)..where((t) => t.id.equals(routine.id)))
            .write(const RoutinesCompanion(dirty: Value(false)));
      }
    }
  }

  Future<void> _pushCreate(AppDatabase db, Routine routine) async {
    final days = await (db.select(
      db.routineDays,
    )..where((t) => t.routineId.equals(routine.id))).get();
    days.sort((a, b) => a.dayIndex.compareTo(b.dayIndex));

    final dayPayloads = <Map<String, dynamic>>[];
    for (final day in days) {
      final exercises = await (db.select(
        db.routineExercises,
      )..where((t) => t.dayId.equals(day.id))).get();
      exercises.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      dayPayloads.add({
        'day_index': day.dayIndex,
        'name': day.name,
        'muscle_focus': day.muscleFocus,
        'exercises': [
          for (final ex in exercises)
            {
              'exercise_id': ex.exerciseId,
              'order': ex.orderIndex,
              'target_sets': ex.targetSets,
              'target_reps_min': ex.targetRepsMin,
              'target_reps_max': ex.targetRepsMax,
              'target_rest_seconds': ex.targetRestSeconds,
              'notes': ex.notes,
            },
        ],
      });
    }

    final payload = {
      'name': routine.name,
      'goal': routine.goal,
      'days_per_week': routine.daysPerWeek,
      'days': dayPayloads,
    };

    final created = await _service.create(payload);

    await (db.update(db.routines)..where((t) => t.id.equals(routine.id))).write(
      RoutinesCompanion(serverId: Value(created.id), dirty: const Value(false)),
    );
  }

  Future<void> _pushDelete(AppDatabase db, Routine routine) async {
    if (routine.serverId != null) {
      await _service.delete(routine.serverId!);
    }
    await (db.delete(db.routines)..where((t) => t.id.equals(routine.id))).go();
  }
}
