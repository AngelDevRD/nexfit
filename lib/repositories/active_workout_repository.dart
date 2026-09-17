import 'package:drift/drift.dart';

import '../core/local/database.dart' as local;
import '../models/workout.dart';
import 'workout_repository.dart';

/// Duración restante de un descanso, calculada contra un instante absoluto
/// (`restEndsAt`), nunca contra un contador que decrece tick a tick. Por eso
/// sobrevive a que la app se cierre y se vuelva a abrir a mitad del descanso:
/// al reabrir, `remainingRest(restEndsAt, DateTime.now())` da el valor
/// correcto sin importar cuánto tiempo pasó. Nunca negativo.
Duration remainingRest(DateTime restEndsAt, DateTime now) {
  final diff = restEndsAt.difference(now);
  return diff.isNegative ? Duration.zero : diff;
}

/// Gestiona el entrenamiento activo: garantiza que exista a lo sumo uno
/// (fila única `ActiveWorkoutDrafts`, id fijo), y persiste el progreso
/// (ejercicio/serie actual, fin del descanso) para poder restaurarlo tal cual
/// tras cerrar y reabrir la app.
///
/// La fuente de verdad de "cuánto tiempo pasó" son siempre timestamps
/// absolutos (`WorkoutSessions.startedAt`, `restEndsAt`) -- el draft no
/// guarda duraciones ni contadores, solo el estado que un `Timer` no puede
/// reconstruir por sí solo.
class ActiveWorkoutRepository {
  static const _draftId = 1;

  final local.AppDatabase db;
  final WorkoutRepository workoutRepository;

  ActiveWorkoutRepository(this.db, this.workoutRepository);

  /// Id de la sesión activa, si hay una. `null` si no hay ningún
  /// entrenamiento en curso (pantalla de inicio debe mostrar el flujo normal).
  ///
  /// A3: si el draft apunta a una sesión que ya no existe (borrada por fuera
  /// de este repositorio, o por una migración vieja), el draft queda huérfano
  /// y se autolimpia acá -- así ninguna pantalla que dependa de este valor
  /// puede quedarse esperando una sesión que nunca va a cargar.
  Future<int?> currentSessionId() async {
    final draft = await (db.select(
      db.activeWorkoutDrafts,
    )..where((t) => t.id.equals(_draftId))).getSingleOrNull();
    if (draft == null) return null;
    if (await _sessionExists(draft.sessionId)) return draft.sessionId;
    await _deleteDraft();
    return null;
  }

  /// Igual que [currentSessionId] pero reactivo (N3): el shell lo escucha
  /// para mostrar/ocultar el banner de "entrenamiento en curso" sin tener
  /// que sondear -- emite de nuevo automáticamente cuando `begin`/`finish`
  /// escriben la fila del draft.
  Stream<int?> watchCurrentSessionId() {
    return (db.select(db.activeWorkoutDrafts)..where(
      (t) => t.id.equals(_draftId),
    )).watchSingleOrNull().asyncMap((draft) async {
      if (draft == null) return null;
      if (await _sessionExists(draft.sessionId)) return draft.sessionId;
      await _deleteDraft();
      return null;
    });
  }

  Future<bool> _sessionExists(int sessionId) async {
    final session = await (db.select(
      db.workoutSessions,
    )..where((t) => t.id.equals(sessionId))).getSingleOrNull();
    return session != null;
  }

  Future<void> _deleteDraft() {
    return (db.delete(
      db.activeWorkoutDrafts,
    )..where((t) => t.id.equals(_draftId))).go();
  }

  /// A1: `sessionId` del draft si lleva abierto más de [threshold] -- para
  /// que `StartWorkoutScreen` pueda avisar que el entrenamiento activo
  /// probablemente fue abandonado (la app se cerró/minimizó y nunca se
  /// finalizó). `null` si no hay draft o si todavía no pasó el umbral.
  Future<int?> staleSessionId({
    Duration threshold = const Duration(hours: 6),
  }) async {
    final draft = await (db.select(
      db.activeWorkoutDrafts,
    )..where((t) => t.id.equals(_draftId))).getSingleOrNull();
    if (draft == null) return null;
    final session = await (db.select(
      db.workoutSessions,
    )..where((t) => t.id.equals(draft.sessionId))).getSingleOrNull();
    if (session == null) return null;
    if (DateTime.now().difference(session.startedAt) > threshold) {
      return draft.sessionId;
    }
    return null;
  }

  /// Descarta un entrenamiento sin cerrarlo: borra sus series, sus
  /// operaciones de sync pendientes, la sesión y el draft. Distinto de
  /// [finish]: descartar no contamina el historial ni las estadísticas, para
  /// abandonar de verdad un entrenamiento viejo que no se va a completar.
  ///
  /// Las filas hijas se borran A MANO, no por el cascade: `WorkoutSets` y
  /// `PendingSetOps` declaran `onDelete: KeyAction.cascade` contra
  /// `WorkoutSessions`, pero SQLite **no aplica ninguna acción de clave
  /// foránea salvo que `PRAGMA foreign_keys = ON`**, y esta base nunca lo
  /// activa. Confiar en el cascade dejaba series huérfanas apuntando a una
  /// sesión inexistente (lo detectó el test de este método). Activar el
  /// pragma para toda la base es un cambio de otro alcance -- hay 5 acciones
  /// declaradas que hoy tampoco se aplican y bases ya instaladas que podrían
  /// tener filas huérfanas previas.
  Future<void> discard(int sessionId) async {
    await db.transaction(() async {
      await (db.delete(
        db.workoutSets,
      )..where((t) => t.sessionId.equals(sessionId))).go();
      await (db.delete(
        db.pendingSetOps,
      )..where((t) => t.sessionId.equals(sessionId))).go();
      await (db.delete(
        db.workoutSessions,
      )..where((t) => t.id.equals(sessionId))).go();
      await _deleteDraft();
    });
  }

  /// Inicia un entrenamiento nuevo y crea su draft. Lanza [StateError] si ya
  /// hay uno activo -- nunca se pisa un entrenamiento en curso; hay que
  /// finalizarlo o resumirlo primero (ver [currentSessionId]).
  Future<WorkoutSession> begin({
    int? routineId,
    int? routineDayId,
    String? title,
  }) async {
    final existing = await currentSessionId();
    if (existing != null) {
      throw StateError(
        'Ya hay un entrenamiento activo (sesión $existing). '
        'Finalizalo antes de iniciar uno nuevo.',
      );
    }
    final session = await workoutRepository.startSession(
      routineId: routineId,
      routineDayId: routineDayId,
      title: title,
    );
    await db
        .into(db.activeWorkoutDrafts)
        .insert(
          local.ActiveWorkoutDraftsCompanion.insert(
            id: const Value(_draftId),
            sessionId: session.id,
            updatedAt: DateTime.now(),
          ),
        );
    return session;
  }

  /// Actualiza el progreso persistido: ejercicio/serie en foco y el instante
  /// en que termina el descanso actual (`null` para "sin descanso activo").
  /// No hace nada si no hay draft (no debería llamarse sin sesión activa).
  Future<void> updateProgress({
    int? currentExerciseId,
    int? currentSetNumber,
    DateTime? restEndsAt,
    bool clearRest = false,
  }) async {
    final draft = await (db.select(
      db.activeWorkoutDrafts,
    )..where((t) => t.id.equals(_draftId))).getSingleOrNull();
    if (draft == null) return;

    await (db.update(
      db.activeWorkoutDrafts,
    )..where((t) => t.id.equals(_draftId))).write(
      local.ActiveWorkoutDraftsCompanion(
        currentExerciseId: currentExerciseId != null
            ? Value(currentExerciseId)
            : const Value.absent(),
        currentSetNumber: currentSetNumber != null
            ? Value(currentSetNumber)
            : const Value.absent(),
        restEndsAt: clearRest
            ? const Value(null)
            : (restEndsAt != null ? Value(restEndsAt) : const Value.absent()),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Fin del descanso persistido para la sesión activa, o `null` si no hay
  /// descanso en curso (o no hay sesión activa).
  Future<DateTime?> restEndsAt() async {
    final draft = await (db.select(
      db.activeWorkoutDrafts,
    )..where((t) => t.id.equals(_draftId))).getSingleOrNull();
    return draft?.restEndsAt;
  }

  /// Cierra la sesión y borra el draft. [endedAt] permite fijar la hora real
  /// de fin (usado por la importación); al terminar desde la UI en vivo se
  /// omite y se usa el momento actual.
  Future<void> finish(int sessionId, {DateTime? endedAt}) async {
    await workoutRepository.finishSession(sessionId, endedAt: endedAt);
    await (db.delete(
      db.activeWorkoutDrafts,
    )..where((t) => t.id.equals(_draftId))).go();
  }

  /// T-H7: cierra un entrenamiento abandonado (draft con actividad vieja)
  /// SIN perder sus series -- para eso está [discard]. A diferencia de
  /// [finish], acá no hay un `now` real de cuándo terminó: usar
  /// `DateTime.now()` registraría en el historial/estadísticas una duración
  /// absurda (p. ej. 20 horas) para un entrenamiento que en realidad se
  /// abandonó a los pocos minutos. El fin se estima como la última
  /// actividad conocida (`ActiveWorkoutDrafts.updatedAt`, que `begin`/
  /// `updateProgress` van actualizando), acotada a como mucho 3 horas
  /// después del inicio y nunca antes de él.
  Future<void> finishAbandoned(int sessionId) async {
    final draft = await (db.select(
      db.activeWorkoutDrafts,
    )..where((t) => t.id.equals(_draftId))).getSingleOrNull();
    final session = await workoutRepository.get(sessionId);
    final lastActivity = draft?.updatedAt ?? DateTime.now();
    final maxEndedAt = session.startedAt.add(const Duration(hours: 3));

    var endedAt = lastActivity;
    if (endedAt.isBefore(session.startedAt)) endedAt = session.startedAt;
    if (endedAt.isAfter(maxEndedAt)) endedAt = maxEndedAt;

    await finish(sessionId, endedAt: endedAt);
  }
}
