import 'package:appgym/core/local/database.dart' as local;
// `isNull`/`isNotNull` de drift (constructores de expresiones SQL) chocan
// con los matchers homónimos de `flutter_test`.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A25, paso 1: mide el daño REAL de que las 5 acciones `onDelete` declaradas
/// en `lib/core/local/database.dart` no se apliquen -- SQLite las ignora
/// salvo `PRAGMA foreign_keys = ON`, que esta base nunca activa (ver el
/// comentario de `ActiveWorkoutRepository.discard`).
///
/// `RoutineRepository.delete()` es un soft-delete (`deleted = true`) y
/// `RoutineRepository.update()`/`ActiveWorkoutRepository.discard()` ya
/// borran las filas hijas a mano -- esos caminos NO generan huérfanos.
///
/// Los que sí generaban huérfanos (confirmado acá borrando exactamente como
/// hacían esos métodos ANTES del fix, sin pasar por Supabase -- no hace
/// falta para medir el daño LOCAL):
/// - `RoutineSyncable._pushDelete` (lib/core/sync/entities/routine_syncable.dart):
///   borraba `Routines` sin tocar `RoutineDays`/`RoutineExercises`.
/// - `WorkoutSessionSyncable._pushDelete`
///   (lib/core/sync/entities/workout_session_syncable.dart): borraba
///   `WorkoutSessions` sin tocar `WorkoutSets`/`PendingSetOps`.
///
/// Se disparan cuando una rutina/sesión soft-deleted (`deleted = true`,
/// `dirty = true`) se sincroniza: el `SyncEngine` la recoge y llama al
/// `_pushDelete` correspondiente.
///
/// Paso 3 (decisión tomada): borrado explícito en esos dos métodos, mismo
/// patrón que `discard()`. Los primeros dos tests de este archivo quedan
/// como reproducción del defecto YA CORREGIDO (documentan el daño medido);
/// los dos siguientes reproducen la secuencia de borrado que ahora usan
/// `_pushDelete` y confirman que no deja huérfanos.
void main() {
  late local.AppDatabase db;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'defecto medido: borrar solo Routines (como antes del fix) deja RoutineDays/RoutineExercises huérfanos',
    () async {
      final routineId = await db
          .into(db.routines)
          .insert(
            local.RoutinesCompanion.insert(
              name: 'Rutina de prueba',
              updatedAt: DateTime.now(),
            ),
          );
      final dayId = await db
          .into(db.routineDays)
          .insert(
            local.RoutineDaysCompanion.insert(
              routineId: routineId,
              dayIndex: 0,
              name: 'Día 1',
            ),
          );
      await db
          .into(db.routineExercises)
          .insert(
            local.RoutineExercisesCompanion.insert(
              dayId: dayId,
              exerciseId: 1,
              orderIndex: 0,
            ),
          );

      // Reproduce exactamente lo que hace RoutineSyncable._pushDelete: borra
      // SOLO la fila padre, tal como ocurre tras sincronizar una rutina
      // marcada `deleted = true`.
      await (db.delete(
        db.routines,
      )..where((t) => t.id.equals(routineId))).go();

      final orphanedDays = await (db.select(
        db.routineDays,
      )..where((t) => t.routineId.equals(routineId))).get();
      final orphanedExercises = await (db.select(
        db.routineExercises,
      )..where((t) => t.dayId.equals(dayId))).get();

      expect(
        orphanedDays.length,
        1,
        reason:
            'RoutineDays debería quedar huérfano: SQLite no aplica '
            'onDelete: cascade sin PRAGMA foreign_keys = ON.',
      );
      expect(orphanedExercises.length, 1);
    },
  );

  test(
    'defecto medido: borrar solo WorkoutSessions (como antes del fix) deja WorkoutSets/PendingSetOps huérfanos',
    () async {
      final sessionId = await db
          .into(db.workoutSessions)
          .insert(
            local.WorkoutSessionsCompanion.insert(
              startedAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      await db
          .into(db.workoutSets)
          .insert(
            local.WorkoutSetsCompanion.insert(
              sessionId: sessionId,
              exerciseId: 1,
              setNumber: 1,
            ),
          );
      await db
          .into(db.pendingSetOps)
          .insert(
            local.PendingSetOpsCompanion.insert(sessionId: sessionId, op: 'insert'),
          );

      // Reproduce exactamente lo que hace WorkoutSessionSyncable._pushDelete:
      // borra SOLO la fila padre, tal como ocurre tras sincronizar una
      // sesión marcada `deleted = true`.
      await (db.delete(
        db.workoutSessions,
      )..where((t) => t.id.equals(sessionId))).go();

      final orphanedSets = await (db.select(
        db.workoutSets,
      )..where((t) => t.sessionId.equals(sessionId))).get();
      final orphanedPendingOps = await (db.select(
        db.pendingSetOps,
      )..where((t) => t.sessionId.equals(sessionId))).get();

      expect(
        orphanedSets.length,
        1,
        reason:
            'WorkoutSets debería quedar huérfano: SQLite no aplica '
            'onDelete: cascade sin PRAGMA foreign_keys = ON.',
      );
      expect(orphanedPendingOps.length, 1);
    },
  );

  test(
    'fix: la secuencia de borrado de RoutineSyncable._pushDelete no deja huérfanos',
    () async {
      final routineId = await db
          .into(db.routines)
          .insert(
            local.RoutinesCompanion.insert(
              name: 'Rutina de prueba',
              updatedAt: DateTime.now(),
            ),
          );
      final dayId = await db
          .into(db.routineDays)
          .insert(
            local.RoutineDaysCompanion.insert(
              routineId: routineId,
              dayIndex: 0,
              name: 'Día 1',
            ),
          );
      await db
          .into(db.routineExercises)
          .insert(
            local.RoutineExercisesCompanion.insert(
              dayId: dayId,
              exerciseId: 1,
              orderIndex: 0,
            ),
          );

      // Misma secuencia que RoutineSyncable._pushDelete tras el fix.
      final dayIds = await (db.select(db.routineDays)
            ..where((t) => t.routineId.equals(routineId)))
          .map((d) => d.id)
          .get();
      await (db.delete(
        db.routineExercises,
      )..where((t) => t.dayId.isIn(dayIds))).go();
      await (db.delete(
        db.routineDays,
      )..where((t) => t.routineId.equals(routineId))).go();
      await (db.delete(
        db.routines,
      )..where((t) => t.id.equals(routineId))).go();

      final remainingDays = await (db.select(
        db.routineDays,
      )..where((t) => t.routineId.equals(routineId))).get();
      final remainingExercises = await (db.select(
        db.routineExercises,
      )..where((t) => t.dayId.equals(dayId))).get();

      expect(remainingDays, isEmpty);
      expect(remainingExercises, isEmpty);
    },
  );

  test(
    'fix: la secuencia de borrado de WorkoutSessionSyncable._pushDelete no deja huérfanos',
    () async {
      final sessionId = await db
          .into(db.workoutSessions)
          .insert(
            local.WorkoutSessionsCompanion.insert(
              startedAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      await db
          .into(db.workoutSets)
          .insert(
            local.WorkoutSetsCompanion.insert(
              sessionId: sessionId,
              exerciseId: 1,
              setNumber: 1,
            ),
          );
      await db
          .into(db.pendingSetOps)
          .insert(
            local.PendingSetOpsCompanion.insert(sessionId: sessionId, op: 'insert'),
          );

      // Misma secuencia que WorkoutSessionSyncable._pushDelete tras el fix.
      await (db.delete(
        db.workoutSets,
      )..where((t) => t.sessionId.equals(sessionId))).go();
      await (db.delete(
        db.pendingSetOps,
      )..where((t) => t.sessionId.equals(sessionId))).go();
      await (db.delete(
        db.workoutSessions,
      )..where((t) => t.id.equals(sessionId))).go();

      final remainingSets = await (db.select(
        db.workoutSets,
      )..where((t) => t.sessionId.equals(sessionId))).get();
      final remainingPendingOps = await (db.select(
        db.pendingSetOps,
      )..where((t) => t.sessionId.equals(sessionId))).get();

      expect(remainingSets, isEmpty);
      expect(remainingPendingOps, isEmpty);
    },
  );

  test(
    'RoutineRepository.delete() (soft-delete) NO genera huérfanos por sí solo',
    () async {
      // Documenta el contraste: el soft-delete que usa la UI hoy no borra
      // ninguna fila hija -- solo marca `deleted = true` en la rutina. El
      // huérfano aparece recién si esa fila soft-deleted se sincroniza (ver
      // el test de arriba).
      final routineId = await db
          .into(db.routines)
          .insert(
            local.RoutinesCompanion.insert(
              name: 'Rutina de prueba',
              updatedAt: DateTime.now(),
            ),
          );
      await db
          .into(db.routineDays)
          .insert(
            local.RoutineDaysCompanion.insert(
              routineId: routineId,
              dayIndex: 0,
              name: 'Día 1',
            ),
          );

      await (db.update(db.routines)..where((t) => t.id.equals(routineId)))
          .write(const local.RoutinesCompanion(deleted: Value(true)));

      final routine = await (db.select(
        db.routines,
      )..where((t) => t.id.equals(routineId))).getSingle();
      final days = await (db.select(
        db.routineDays,
      )..where((t) => t.routineId.equals(routineId))).get();

      expect(routine.deleted, isTrue);
      expect(days.length, 1); // sigue existiendo -- no es huérfano todavía.
    },
  );
}
