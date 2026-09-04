import 'dart:convert';

import 'package:drift/drift.dart';

import '../core/local/database.dart' as local;
import '../models/exercise.dart';
import '../models/workout.dart';
import 'personal_records_service.dart';

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
  final PersonalRecordsService _records;

  WorkoutRepository(this.db) : _records = PersonalRecordsService(db);

  Future<WorkoutSession> startSession({
    int? routineId,
    int? routineDayId,
    DateTime? startedAt,
    String? title,
  }) async {
    final now = DateTime.now();
    final start = startedAt ?? now;
    final id = await db
        .into(db.workoutSessions)
        .insert(
          local.WorkoutSessionsCompanion.insert(
            routineId: Value(routineId),
            routineDayId: Value(routineDayId),
            title: Value(title),
            startedAt: start,
            updatedAt: now,
          ),
        );
    return WorkoutSession(
      id: id,
      routineId: routineId,
      routineDayId: routineDayId,
      startedAt: start,
      sets: const [],
    );
  }

  /// T1: antes resolvía el ejercicio de cada set con una query aparte (N+1 --
  /// una sesión de 20 series hacía 20 consultas extra en cada `_load()`).
  /// Ahora carga el catálogo de los ejercicios presentes UNA vez y resuelve
  /// en memoria, igual que ya hacía `history()`.
  Future<WorkoutSession> get(int sessionId) async {
    final session = await (db.select(
      db.workoutSessions,
    )..where((t) => t.id.equals(sessionId))).getSingle();
    final setRows = await (db.select(
      db.workoutSets,
    )..where((t) => t.sessionId.equals(sessionId))).get();

    final exerciseIds = setRows.map((r) => r.exerciseId).toSet();
    final exerciseRows = exerciseIds.isEmpty
        ? const <local.Exercise>[]
        : await (db.select(
            db.exercises,
          )..where((t) => t.id.isIn(exerciseIds))).get();
    final exerciseById = {for (final e in exerciseRows) e.id: e};

    final sets = [
      for (final row in setRows)
        _toWorkoutSetFromCatalog(row, exerciseById[row.exerciseId]!),
    ];

    return WorkoutSession(
      id: session.id,
      routineId: session.routineId,
      routineDayId: session.routineDayId,
      startedAt: session.startedAt,
      endedAt: session.endedAt,
      notes: session.notes,
      sets: sets,
    );
  }

  /// La última serie real (no calentamiento, peso y reps > 0) de este
  /// ejercicio en una sesión ya terminada -- "última vez" para prefill (C6)
  /// y como referencia de peso al precargar una rutina (C4). `null` si el
  /// ejercicio nunca se entrenó (o solo en sesiones abiertas/con series en
  /// 0, que no cuentan -- mismo criterio que T5).
  Future<WorkoutSet?> lastSetFor(
    int exerciseId, {
    int? excludeSessionId,
  }) async {
    final sessions = await (db.select(
      db.workoutSessions,
    )..where((t) => t.endedAt.isNotNull())).get();
    final sessionById = {
      for (final s in sessions)
        if (s.id != excludeSessionId) s.id: s,
    };
    if (sessionById.isEmpty) return null;

    final sets =
        await (db.select(db.workoutSets)..where(
              (t) =>
                  t.exerciseId.equals(exerciseId) &
                  t.isWarmup.equals(false) &
                  t.sessionId.isIn(sessionById.keys),
            ))
            .get();

    local.WorkoutSet? latest;
    DateTime? latestStartedAt;
    for (final set in sets) {
      if (set.weightKg <= 0 || set.reps <= 0) continue;
      final startedAt = sessionById[set.sessionId]!.startedAt;
      if (latestStartedAt == null || startedAt.isAfter(latestStartedAt)) {
        latest = set;
        latestStartedAt = startedAt;
      }
    }
    return latest == null ? null : _toWorkoutSet(latest);
  }

  /// La sesión terminada más reciente en la que se entrenó este ejercicio,
  /// con TODAS sus series (no solo la mejor) -- "última vez" completa para
  /// el detalle del ejercicio (U2), a diferencia de [lastSetFor] que solo
  /// da un set suelto para prefill.
  Future<ExerciseLastSession?> lastSessionFor(int exerciseId) async {
    final history = await exerciseHistory(exerciseId, limit: 1);
    if (history.isEmpty) return null;
    final entry = history.first;
    return ExerciseLastSession(startedAt: entry.startedAt, sets: entry.sets);
  }

  /// A1: todas las sesiones terminadas donde se entrenó este ejercicio, más
  /// recientes primero, con sus series completas -- la pestaña "Historial"
  /// del detalle de ejercicio necesita el historial COMPLETO, no solo la
  /// última vez (que ya cubría [lastSessionFor], reescrito arriba en
  /// términos de este método para no duplicar la consulta).
  ///
  /// Una sola consulta a `workout_sets` filtrada por `exerciseId` (sin
  /// filtrar por sesión) en vez de una consulta por sesión -- evita el N+1
  /// que tendría iterar sesión por sesión.
  Future<List<ExerciseSessionEntry>> exerciseHistory(
    int exerciseId, {
    int? limit,
  }) async {
    final sessions =
        await (db.select(db.workoutSessions)
              ..where((t) => t.endedAt.isNotNull() & t.deleted.equals(false))
              ..orderBy([(t) => OrderingTerm.desc(t.startedAt)]))
            .get();
    if (sessions.isEmpty) return const [];

    final exerciseRow = await (db.select(
      db.exercises,
    )..where((t) => t.id.equals(exerciseId))).getSingle();

    final sessionIds = sessions.map((s) => s.id).toSet();
    final setRows =
        await (db.select(db.workoutSets)..where(
              (t) =>
                  t.exerciseId.equals(exerciseId) &
                  t.sessionId.isIn(sessionIds),
            ))
            .get();
    final setsBySession = <int, List<local.WorkoutSet>>{};
    for (final row in setRows) {
      setsBySession.putIfAbsent(row.sessionId, () => []).add(row);
    }

    final entries = <ExerciseSessionEntry>[];
    for (final session in sessions) {
      final rows = setsBySession[session.id];
      if (rows == null || rows.isEmpty) continue;
      rows.sort((a, b) => a.setNumber.compareTo(b.setNumber));
      entries.add(
        ExerciseSessionEntry(
          sessionId: session.id,
          startedAt: session.startedAt,
          sets: [
            for (final row in rows) _toWorkoutSetFromCatalog(row, exerciseRow),
          ],
        ),
      );
      if (limit != null && entries.length >= limit) break;
    }
    return entries;
  }

  /// Cierra la sesión. [endedAt] permite fijar la hora real de fin (la trae el
  /// export de Hevy en `end_time`); si se omite, se usa el momento actual, que
  /// es lo correcto para una sesión que se termina en vivo desde la UI. Nunca
  /// se usa `DateTime.now()` para datos importados -- ese era el bug que hacía
  /// "duración = momento de importar - medianoche".
  ///
  /// Al cerrar, reconstruye toda la bitácora de récords ([rebuildPersonalRecords])
  /// como red de seguridad: series corregidas con el editor avanzado después
  /// de completadas (que no pasan por [setCompleted]) igual quedan evaluadas
  /// al finalizar. Es O(sets totales de la app), aceptable en un evento que
  /// ocurre una vez por entrenamiento, no por toque.
  Future<WorkoutSession> finishSession(
    int sessionId, {
    DateTime? endedAt,
  }) async {
    final now = DateTime.now();
    await (db.update(
      db.workoutSessions,
    )..where((t) => t.id.equals(sessionId))).write(
      local.WorkoutSessionsCompanion(
        endedAt: Value(endedAt ?? now),
        updatedAt: Value(now),
        dirty: const Value(true),
      ),
    );
    await _records.rebuildAll();
    return get(sessionId);
  }

  /// Inserta un set y evalúa récords. Devuelve el set creado y los récords
  /// nuevos que ese set haya roto (peso y/o reps), para que la UI los muestre.
  /// La detección la hace [PersonalRecordsService] con upsert sobre la clave
  /// única (exerciseId, recordType) -> no acumula duplicados.
  Future<({WorkoutSet set, List<ResolvedRecord> newRecords})> addSet(
    int sessionId,
    Map<String, dynamic> payload,
  ) async {
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
            supersetGroupId: Value(payload['superset_group_id'] as int?),
            tempo: Value(payload['tempo'] as String?),
            isWarmup: Value(isWarmup),
            notes: Value(payload['notes'] as String?),
            completed: Value(payload['completed'] as bool? ?? false),
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

    var newRecords = const <ResolvedRecord>[];
    // No evaluar récords con la serie placeholder en 0/0 (C2): toda serie
    // nueva del flujo rápido nace así y el peso/reps real llega después por
    // `updateSet`, que es quien evalúa de verdad (ver más abajo).
    if (!isWarmup && weightKg > 0 && reps > 0) {
      final session = await (db.select(
        db.workoutSessions,
      )..where((t) => t.id.equals(sessionId))).getSingle();
      newRecords = await _records.evaluateSet(
        exerciseId: exerciseId,
        weightKg: weightKg,
        reps: reps,
        sessionId: sessionId,
        setId: setId,
        achievedAt: session.startedAt,
      );
    }

    final row = await (db.select(
      db.workoutSets,
    )..where((t) => t.id.equals(setId))).getSingle();
    return (set: await _toWorkoutSet(row), newRecords: newRecords);
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
        completed: payload.containsKey('completed')
            ? Value(payload['completed'] as bool)
            : const Value.absent(),
        isWarmup: payload.containsKey('is_warmup')
            ? Value(payload['is_warmup'] as bool)
            : const Value.absent(),
        techniques: payload.containsKey('techniques')
            ? Value(jsonEncode(payload['techniques']))
            : const Value.absent(),
        restSeconds: payload.containsKey('rest_seconds')
            ? Value(payload['rest_seconds'] as int?)
            : const Value.absent(),
        exerciseId: payload.containsKey('exercise_id')
            ? Value(payload['exercise_id'] as int)
            : const Value.absent(),
        exerciseNotes: payload.containsKey('exercise_notes')
            ? Value(payload['exercise_notes'] as String?)
            : const Value.absent(),
        exerciseOrder: payload.containsKey('exercise_order')
            ? Value(payload['exercise_order'] as int?)
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
      // C1: el payload nuevo se MEZCLA sobre el del insert pendiente en vez
      // de reemplazarlo -- si no, cada `updateSet` (peso, después reps) borra
      // las claves cargadas por la llamada anterior y el insert que viaja al
      // server queda incompleto (sin exercise_id/set_number/weight_kg).
      final pending =
          await (db.select(db.pendingSetOps)..where(
                (t) => t.localSetId.equals(setId) & t.op.equals('insert'),
              ))
              .getSingleOrNull();
      if (pending != null) {
        final merged = Map<String, dynamic>.from(
          jsonDecode(pending.payloadJson) as Map,
        )..addAll(payload);
        await (db.update(
          db.pendingSetOps,
        )..where((t) => t.id.equals(pending.id))).write(
          local.PendingSetOpsCompanion(payloadJson: Value(jsonEncode(merged))),
        );
      }
    }
    await _markSessionDirty(set.sessionId);

    final updated = await (db.select(
      db.workoutSets,
    )..where((t) => t.id.equals(setId))).getSingle();

    // Deliberadamente NO se evalúan récords acá (regresión encontrada en
    // revisión, ver docs/AUDITORIA_2026-09-03.md): `StepperField` llama a
    // `updateSet` por CADA toque de +/-, así que subir una serie de 0 a 80kg
    // en pasos de 2.5 son 32 llamadas -- evaluar en cada una generaba 32 filas
    // en `personalRecords` para una sola serie (825 XP fantasma incluidos).
    // La evaluación real pasa a [setCompleted] (una vez, al marcar la serie)
    // y a `finishSession` (red de seguridad vía `rebuildPersonalRecords`).
    return _toWorkoutSet(updated);
  }

  /// Marca (o desmarca) una serie como completada y, solo al completar,
  /// evalúa récords contra el peso/reps que tenga la serie EN ESE MOMENTO.
  /// Es el único punto del flujo normal donde se evalúan récords -- una vez
  /// por serie, no una vez por toque de stepper (ver comentario en
  /// [updateSet]). Devuelve los récords nuevos para que la UI muestre el
  /// banner, igual que [addSet].
  Future<List<ResolvedRecord>> setCompleted(int setId, bool completed) async {
    await updateSet(setId, {'completed': completed});
    if (!completed) return const [];

    final set = await (db.select(
      db.workoutSets,
    )..where((t) => t.id.equals(setId))).getSingle();
    if (set.isWarmup || set.weightKg <= 0 || set.reps <= 0) return const [];

    final session = await (db.select(
      db.workoutSessions,
    )..where((t) => t.id.equals(set.sessionId))).getSingle();
    return _records.evaluateSet(
      exerciseId: set.exerciseId,
      weightKg: set.weightKg,
      reps: set.reps,
      sessionId: set.sessionId,
      setId: set.id,
      achievedAt: session.startedAt,
    );
  }

  /// Marca todas las series de un ejercicio, dentro de una sesión, como
  /// completadas de una sola vez (ver botón "Marcar como completado" en
  /// `ActiveWorkoutScreen`). Es un estado de presentación local -- no encola
  /// nada en `pendingSetOps`, no viaja a Supabase. No evalúa récords acá (la
  /// red de seguridad de `finishSession` los cubre al cerrar la sesión).
  Future<void> markExerciseCompleted(int sessionId, int exerciseId) async {
    await (db.update(db.workoutSets)..where(
          (t) =>
              t.sessionId.equals(sessionId) & t.exerciseId.equals(exerciseId),
        ))
        .write(const local.WorkoutSetsCompanion(completed: Value(true)));
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

  /// A4: "Reemplazar ejercicio" -- mueve todas las series de
  /// [oldExerciseId] a [newExerciseId] dentro de la sesión, conservando
  /// peso/reps/serie tal cual (cambiar de máquina no debería perder lo ya
  /// cargado). Reusa [updateSet] serie por serie para no duplicar la
  /// lógica de sync (pendingSetOps/dirty).
  Future<void> replaceExerciseInSession(
    int sessionId,
    int oldExerciseId,
    int newExerciseId,
  ) async {
    final sets =
        await (db.select(db.workoutSets)..where(
              (t) =>
                  t.sessionId.equals(sessionId) &
                  t.exerciseId.equals(oldExerciseId),
            ))
            .get();
    for (final set in sets) {
      await updateSet(set.id, {'exercise_id': newExerciseId});
    }
  }

  /// A4: nota a nivel EJERCICIO (distinta de la nota por serie) -- se
  /// aplica a todas las series de ese ejercicio en la sesión, igual que
  /// `ActiveWorkoutScreen._editExerciseRest` hace con `rest_seconds`.
  Future<void> updateExerciseNotes(
    int sessionId,
    int exerciseId,
    String? notes,
  ) async {
    final sets =
        await (db.select(db.workoutSets)..where(
              (t) =>
                  t.sessionId.equals(sessionId) &
                  t.exerciseId.equals(exerciseId),
            ))
            .get();
    for (final set in sets) {
      await updateSet(set.id, {'exercise_notes': notes});
    }
  }

  /// A4: "Reordenar ejercicios" -- persiste el orden elegido por el
  /// usuario escribiendo el índice en todas las series de cada ejercicio.
  Future<void> reorderExercisesInSession(
    int sessionId,
    List<int> exerciseIdsInOrder,
  ) async {
    for (var i = 0; i < exerciseIdsInOrder.length; i++) {
      final sets =
          await (db.select(db.workoutSets)..where(
                (t) =>
                    t.sessionId.equals(sessionId) &
                    t.exerciseId.equals(exerciseIdsInOrder[i]),
              ))
              .get();
      for (final set in sets) {
        await updateSet(set.id, {'exercise_order': i});
      }
    }
  }

  /// A4: "Eliminar ejercicio" -- borra todas sus series de la sesión.
  /// Reusa [deleteSet] serie por serie para conservar la lógica de sync.
  Future<void> deleteExerciseFromSession(int sessionId, int exerciseId) async {
    final sets =
        await (db.select(db.workoutSets)..where(
              (t) =>
                  t.sessionId.equals(sessionId) &
                  t.exerciseId.equals(exerciseId),
            ))
            .get();
    for (final set in sets) {
      await deleteSet(set.id);
    }
  }

  /// Récords logrados en una sesión. Filtra por `sessionId` (columna agregada
  /// en el esquema v6), no por `achievedAt >= startedAt` como antes: aquel
  /// filtro colgaba de una sesión todos los récords con fecha posterior, y tras
  /// una importación (donde `achievedAt` era el momento de importar) atribuía
  /// cientos de récords históricos a la última sesión importada.
  Future<List<PersonalRecord>> sessionRecords(int sessionId) async {
    final rows = await (db.select(
      db.personalRecords,
    )..where((t) => t.sessionId.equals(sessionId))).get();
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

  /// Para cada músculo en [muscleGroups], el volumen (kg, sin calentamientos)
  /// de la sesión terminada más reciente -- distinta de [excludeSessionId]--
  /// que haya trabajado ese músculo. Un músculo sin ninguna sesión anterior
  /// simplemente no aparece en el mapa devuelto.
  ///
  /// T3: reemplaza lo que hacía `WorkoutSummaryScreen._loadComparisons` --
  /// una llamada a `history(muscleGroup:)` (sesiones+sets+catálogo enteros)
  /// MÁS un `get()` por cada músculo entrenado en la sesión. Acá es UNA sola
  /// pasada sobre sessions/sets/exercises sin importar cuántos músculos se
  /// estén comparando.
  Future<Map<String, double>> previousVolumeByMuscle({
    required Set<String> muscleGroups,
    required int excludeSessionId,
  }) async {
    if (muscleGroups.isEmpty) return const {};

    final sessions = await (db.select(
      db.workoutSessions,
    )..where((t) => t.deleted.equals(false) & t.endedAt.isNotNull())).get();
    final relevantSessionIds = [
      for (final s in sessions)
        if (s.id != excludeSessionId) s.id,
    ];
    if (relevantSessionIds.isEmpty) return const {};

    final setRows =
        await (db.select(db.workoutSets)..where(
              (t) =>
                  t.sessionId.isIn(relevantSessionIds) &
                  t.isWarmup.equals(false),
            ))
            .get();
    final exercises = await db.select(db.exercises).get();
    final muscleById = {for (final e in exercises) e.id: e.muscleGroup};
    final startedById = {for (final s in sessions) s.id: s.startedAt};

    // Volumen por (sessionId, músculo), solo para los músculos que interesan.
    final volumeBySession = <int, Map<String, double>>{};
    for (final set in setRows) {
      final muscle = muscleById[set.exerciseId];
      if (muscle == null || !muscleGroups.contains(muscle)) continue;
      final perMuscle = volumeBySession.putIfAbsent(set.sessionId, () => {});
      perMuscle[muscle] = (perMuscle[muscle] ?? 0) + set.weightKg * set.reps;
    }

    // Para cada músculo, la sesión más reciente (por startedAt) que lo tenga.
    final result = <String, double>{};
    for (final muscle in muscleGroups) {
      int? bestSessionId;
      DateTime? bestStartedAt;
      for (final entry in volumeBySession.entries) {
        if (!entry.value.containsKey(muscle)) continue;
        final startedAt = startedById[entry.key];
        if (startedAt == null) continue;
        if (bestStartedAt == null || startedAt.isAfter(bestStartedAt)) {
          bestStartedAt = startedAt;
          bestSessionId = entry.key;
        }
      }
      if (bestSessionId != null) {
        result[muscle] = volumeBySession[bestSessionId]![muscle]!;
      }
    }
    return result;
  }

  /// U3: [limit]/[offset] paginan a nivel de consulta -- antes se traía TODO
  /// el historial (con TODOS sus sets) en un solo `get()`, que con un
  /// historial importado de Hevy son miles de filas en memoria solo para
  /// pintar la lista.
  ///
  /// [exerciseId]/[muscleGroup] filtran con un subquery SQL (`isInQuery`)
  /// contra `workout_sets` (y `exercises` para el grupo muscular), no en
  /// Dart después de traer la página -- si el filtro fuera posterior a
  /// `limit`/`offset`, ambos contarían cosas distintas: el offset avanza
  /// sobre sesiones SIN filtrar, pero la lista que ve el usuario está
  /// filtrada. Con pocas sesiones viejas del músculo buscado detrás de
  /// muchas sesiones recientes de otro músculo, esto hacía que la primera
  /// página viniera vacía (`hasMore=false` con sesiones reales sin mostrar
  /// nunca) y que "cargar más" pidiera offsets que no correspondían a nada
  /// -- bug reportado tras cerrar U3, corregido acá. Con el filtro en SQL,
  /// `limit`/`offset` y el resultado filtrado son la misma unidad.
  Future<List<WorkoutSessionSummary>> history({
    int? exerciseId,
    String? muscleGroup,
    int? routineId,
    DateTime? dateFrom,
    DateTime? dateTo,
    int? limit,
    int? offset,
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
    if (exerciseId != null) {
      final matchingSessions = db.selectOnly(db.workoutSets)
        ..addColumns([db.workoutSets.sessionId])
        ..where(db.workoutSets.exerciseId.equals(exerciseId));
      query.where((t) => t.id.isInQuery(matchingSessions));
    }
    if (muscleGroup != null) {
      final matchingSessions = db.selectOnly(db.workoutSets)
        ..addColumns([db.workoutSets.sessionId])
        ..join([
          innerJoin(
            db.exercises,
            db.exercises.id.equalsExp(db.workoutSets.exerciseId),
          ),
        ])
        ..where(db.exercises.muscleGroup.equals(muscleGroup));
      query.where((t) => t.id.isInQuery(matchingSessions));
    }
    if (limit != null) {
      query.limit(limit, offset: offset);
    }
    final rows = await query.get();
    if (rows.isEmpty) return const [];

    // Sets de todas las sesiones devueltas en UNA sola consulta -> se evita
    // el N+1 (antes: una query por sesión más una por set para resolver el
    // grupo muscular). El filtro por músculo/ejercicio ya se aplicó en SQL
    // arriba, así que acá no hace falta el catálogo de ejercicios.
    final sessionIds = rows.map((r) => r.id).toList();
    final setRows = await (db.select(
      db.workoutSets,
    )..where((t) => t.sessionId.isIn(sessionIds))).get();

    final setsBySession = <int, List<local.WorkoutSet>>{};
    for (final set in setRows) {
      setsBySession.putIfAbsent(set.sessionId, () => []).add(set);
    }

    final summaries = <WorkoutSessionSummary>[];
    for (final r in rows) {
      final sets = setsBySession[r.id] ?? const [];

      var volume = 0.0;
      final distinctExercises = <int>{};
      for (final s in sets) {
        distinctExercises.add(s.exerciseId);
        if (!s.isWarmup) volume += s.weightKg * s.reps;
      }

      summaries.add(
        WorkoutSessionSummary(
          id: r.id,
          routineId: r.routineId,
          title: r.title,
          startedAt: r.startedAt,
          endedAt: r.endedAt,
          totalVolumeKg: volume,
          exerciseCount: distinctExercises.length,
          setCount: sets.length,
        ),
      );
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

  /// Reconstruye la tabla de récords desde los sets guardados. Lo llama la
  /// importación (Fase 4) tras escribir todo el historial de una vez.
  Future<void> rebuildPersonalRecords() => _records.rebuildAll();

  /// Para un solo set (`addSet`/`updateSet`/`lastSetFor`): resuelve su
  /// ejercicio con una query propia. Para varios sets a la vez usar
  /// [_toWorkoutSetFromCatalog] con el catálogo ya cargado (ver [get] -- T1).
  Future<WorkoutSet> _toWorkoutSet(local.WorkoutSet row) async {
    final exerciseRow = await (db.select(
      db.exercises,
    )..where((t) => t.id.equals(row.exerciseId))).getSingle();
    return _toWorkoutSetFromCatalog(row, exerciseRow);
  }

  WorkoutSet _toWorkoutSetFromCatalog(
    local.WorkoutSet row,
    local.Exercise exerciseRow,
  ) {
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
      completed: row.completed,
      exerciseNotes: row.exerciseNotes,
      exerciseOrder: row.exerciseOrder,
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
