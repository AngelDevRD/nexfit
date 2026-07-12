import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/local/database.dart' as local;
import '../models/exercise.dart';
import '../models/workout.dart';

/// Reemplaza a `WorkoutService` como punto de acceso de las screens: lee y
/// escribe contra la base local. Cada mutación marca `dirty=true` en la
/// sesión padre (o encola un [local.PendingSetOps]) para que el `SyncEngine`
/// la suba cuando haya conexión. Los ids que devuelve son siempre LOCALES.
///
/// Nota: las clases generadas por Drift para las filas (`WorkoutSession`,
/// `WorkoutSet`, `PersonalRecord`) tienen el mismo nombre que los modelos de
/// dominio en `lib/models/workout.dart` -- por eso el import de la base
/// local va con prefijo `local.`.
///
/// Los récords personales se calculan localmente (max peso / max reps por
/// ejercicio, comparando contra los sets históricos ya guardados) -- no
/// replica el detector completo del backend (que también calcula volumen y
/// tonelaje semanal/mensual), pero cubre el caso principal sin necesitar red.
class WorkoutRepository {
  final local.AppDatabase db;

  WorkoutRepository(this.db);

  Future<WorkoutSession> startSession({
    int? routineId,
    DateTime? startedAt,
  }) async {
    final now = DateTime.now();
    final start = startedAt ?? now;
    final id = await db
        .into(db.workoutSessions)
        .insert(
          local.WorkoutSessionsCompanion.insert(
            routineId: Value(routineId),
            startedAt: start,
            updatedAt: now,
          ),
        );
    return WorkoutSession(
      id: id,
      routineId: routineId,
      startedAt: start,
      sets: const [],
    );
  }

  Future<WorkoutSession> get(int sessionId) async {
    final session = await (db.select(
      db.workoutSessions,
    )..where((t) => t.id.equals(sessionId))).getSingle();
    final setRows = await (db.select(
      db.workoutSets,
    )..where((t) => t.sessionId.equals(sessionId))).get();

    final sets = <WorkoutSet>[];
    for (final row in setRows) {
      sets.add(await _toWorkoutSet(row));
    }

    return WorkoutSession(
      id: session.id,
      routineId: session.routineId,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      notes: session.notes,
      sets: sets,
    );
  }

  Future<WorkoutSession> finishSession(int sessionId) async {
    final now = DateTime.now();
    await (db.update(
      db.workoutSessions,
    )..where((t) => t.id.equals(sessionId))).write(
      local.WorkoutSessionsCompanion(
        endedAt: Value(now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
    return get(sessionId);
  }

  Future<WorkoutSet> addSet(int sessionId, Map<String, dynamic> payload) async {
    final exerciseId = payload['exercise_id'] as int;
    final weightKg = (payload['weight_kg'] as num).toDouble();
    final reps = payload['reps'] as int;
    final isWarmup = payload['is_warmup'] as bool? ?? false;

    final setId = await db
        .into(db.workoutSets)
        .insert(
          local.WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: exerciseId,
            setNumber: payload['set_number'] as int,
            weightKg: Value(weightKg),
            reps: Value(reps),
            rpe: Value((payload['rpe'] as num?)?.toDouble()),
            rir: Value(payload['rir'] as int?),
            restSeconds: Value(payload['rest_seconds'] as int?),
            techniques: Value(jsonEncode(payload['techniques'] ?? const [])),
            isWarmup: Value(isWarmup),
            notes: Value(payload['notes'] as String?),
          ),
        );

    await db
        .into(db.pendingSetOps)
        .insert(
          local.PendingSetOpsCompanion.insert(
            sessionId: sessionId,
            op: 'insert',
            localSetId: Value(setId),
            payloadJson: Value(jsonEncode(payload)),
          ),
        );

    await _markSessionDirty(sessionId);
    if (!isWarmup) {
      await _checkPersonalRecords(exerciseId, weightKg, reps);
    }

    final row = await (db.select(
      db.workoutSets,
    )..where((t) => t.id.equals(setId))).getSingle();
    return _toWorkoutSet(row);
  }

  Future<WorkoutSet> updateSet(int setId, Map<String, dynamic> payload) async {
    final set = await (db.select(
      db.workoutSets,
    )..where((t) => t.id.equals(setId))).getSingle();

    await (db.update(db.workoutSets)..where((t) => t.id.equals(setId))).write(
      local.WorkoutSetsCompanion(
        weightKg: payload.containsKey('weight_kg')
            ? Value((payload['weight_kg'] as num).toDouble())
            : const Value.absent(),
        reps: payload.containsKey('reps')
            ? Value(payload['reps'] as int)
            : const Value.absent(),
        rpe: payload.containsKey('rpe')
            ? Value((payload['rpe'] as num?)?.toDouble())
            : const Value.absent(),
        rir: payload.containsKey('rir')
            ? Value(payload['rir'] as int?)
            : const Value.absent(),
        notes: payload.containsKey('notes')
            ? Value(payload['notes'] as String?)
            : const Value.absent(),
      ),
    );

    if (set.serverId != null) {
      await db
          .into(db.pendingSetOps)
          .insert(
            local.PendingSetOpsCompanion.insert(
              sessionId: set.sessionId,
              op: 'update',
              localSetId: Value(setId),
              serverSetId: Value(set.serverId),
              payloadJson: Value(jsonEncode(payload)),
            ),
          );
    } else {
      // Todavía no sincronizado -- el 'insert' pendiente ya va a viajar con
      // los valores actuales del row, no hace falta encolar un update aparte.
      await (db.update(db.pendingSetOps)
            ..where((t) => t.localSetId.equals(setId) & t.op.equals('insert')))
          .write(
            local.PendingSetOpsCompanion(
              payloadJson: Value(jsonEncode(payload)),
            ),
          );
    }
    await _markSessionDirty(set.sessionId);

    final updated = await (db.select(
      db.workoutSets,
    )..where((t) => t.id.equals(setId))).getSingle();
    return _toWorkoutSet(updated);
  }

  Future<void> deleteSet(int setId) async {
    final set = await (db.select(
      db.workoutSets,
    )..where((t) => t.id.equals(setId))).getSingle();

    if (set.serverId != null) {
      await db
          .into(db.pendingSetOps)
          .insert(
            local.PendingSetOpsCompanion.insert(
              sessionId: set.sessionId,
              op: 'delete',
              serverSetId: Value(set.serverId),
            ),
          );
    } else {
      // Nunca sincronizado -- basta con borrar el 'insert' pendiente.
      await (db.delete(
        db.pendingSetOps,
      )..where((t) => t.localSetId.equals(setId) & t.op.equals('insert'))).go();
    }

    await (db.delete(db.workoutSets)..where((t) => t.id.equals(setId))).go();
    await _markSessionDirty(set.sessionId);
  }

  Future<List<PersonalRecord>> sessionRecords(int sessionId) async {
    final session = await (db.select(
      db.workoutSessions,
    )..where((t) => t.id.equals(sessionId))).getSingle();
    final rows =
        await (db.select(db.personalRecords)..where(
              (t) => t.achievedAt.isBiggerOrEqualValue(session.startedAt),
            ))
            .get();
    return rows
        .map(
          (r) => PersonalRecord(
            id: r.id,
            exerciseId: r.exerciseId,
            recordType: r.recordType,
            value: r.value,
            previousValue: r.previousValue,
            achievedAt: r.achievedAt,
          ),
        )
        .toList();
  }

  Future<List<WorkoutSessionSummary>> history({
    int? exerciseId,
    String? muscleGroup,
    int? routineId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = db.select(db.workoutSessions)
      ..where((t) => t.deleted.equals(false))
      ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]);
    if (routineId != null) {
      query.where((t) => t.routineId.equals(routineId));
    }
    if (dateFrom != null) {
      query.where((t) => t.startedAt.isBiggerOrEqualValue(dateFrom));
    }
    if (dateTo != null) {
      query.where((t) => t.startedAt.isSmallerOrEqualValue(dateTo));
    }
    final rows = await query.get();

    var summaries = rows
        .map(
          (r) => WorkoutSessionSummary(
            id: r.id,
            routineId: r.routineId,
            startedAt: r.startedAt,
            endedAt: r.endedAt,
          ),
        )
        .toList();

    if (exerciseId != null || muscleGroup != null) {
      final filtered = <WorkoutSessionSummary>[];
      for (final summary in summaries) {
        final setRows = await (db.select(
          db.workoutSets,
        )..where((t) => t.sessionId.equals(summary.id))).get();
        for (final set in setRows) {
          if (exerciseId != null && set.exerciseId != exerciseId) continue;
          final exercise = await (db.select(
            db.exercises,
          )..where((t) => t.id.equals(set.exerciseId))).getSingleOrNull();
          if (muscleGroup != null && exercise?.muscleGroup != muscleGroup) {
            continue;
          }
          filtered.add(summary);
          break;
        }
      }
      summaries = filtered;
    }

    return summaries;
  }

  Future<void> _markSessionDirty(int sessionId) async {
    await (db.update(
      db.workoutSessions,
    )..where((t) => t.id.equals(sessionId))).write(
      local.WorkoutSessionsCompanion(
        dirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  Future<void> _checkPersonalRecords(
    int exerciseId,
    double weightKg,
    int reps,
  ) async {
    final past =
        await (db.select(db.workoutSets)..where(
              (t) => t.exerciseId.equals(exerciseId) & t.isWarmup.equals(false),
            ))
            .get();
    if (past.length <= 1) return; // el set recién insertado ya está en `past`

    final previousSets = past
        .where((s) => s.weightKg != weightKg || s.reps != reps)
        .toList();
    if (previousSets.isEmpty) return;

    final prevMaxWeight = previousSets
        .map((s) => s.weightKg)
        .fold<double>(0, (a, b) => a > b ? a : b);
    final prevMaxReps = previousSets
        .map((s) => s.reps)
        .fold<int>(0, (a, b) => a > b ? a : b);

    final now = DateTime.now();
    if (weightKg > prevMaxWeight) {
      await db
          .into(db.personalRecords)
          .insert(
            local.PersonalRecordsCompanion.insert(
              exerciseId: Value(exerciseId),
              recordType: 'max_weight',
              value: weightKg,
              previousValue: Value(prevMaxWeight),
              achievedAt: now,
            ),
          );
    }
    if (reps > prevMaxReps) {
      await db
          .into(db.personalRecords)
          .insert(
            local.PersonalRecordsCompanion.insert(
              exerciseId: Value(exerciseId),
              recordType: 'max_reps',
              value: reps.toDouble(),
              previousValue: Value(prevMaxReps.toDouble()),
              achievedAt: now,
            ),
          );
    }
  }

  Future<WorkoutSet> _toWorkoutSet(local.WorkoutSet row) async {
    final exerciseRow = await (db.select(
      db.exercises,
    )..where((t) => t.id.equals(row.exerciseId))).getSingle();
    return WorkoutSet(
      id: row.id,
      setNumber: row.setNumber,
      weightKg: row.weightKg,
      reps: row.reps,
      rpe: row.rpe,
      rir: row.rir,
      restSeconds: row.restSeconds,
      techniques: (jsonDecode(row.techniques) as List)
          .map((e) => e.toString())
          .toList(),
      supersetGroupId: row.supersetGroupId,
      tempo: row.tempo,
      isWarmup: row.isWarmup,
      notes: row.notes,
      exercise: ExerciseSummary(
        id: exerciseRow.id,
        slug: exerciseRow.slug,
        name: exerciseRow.name,
        muscleGroup: exerciseRow.muscleGroup,
        difficulty: exerciseRow.difficulty,
        imageUrl: exerciseRow.imageUrl,
      ),
    );
  }
}
