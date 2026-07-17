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
  Future<int?> currentSessionId() async {
    final draft = await (db.select(
      db.activeWorkoutDrafts,
    )..where((t) => t.id.equals(_draftId))).getSingleOrNull();
    return draft?.sessionId;
  }

  /// Inicia un entrenamiento nuevo y crea su draft. Lanza [StateError] si ya
  /// hay uno activo -- nunca se pisa un entrenamiento en curso; hay que
  /// finalizarlo o resumirlo primero (ver [currentSessionId]).
  Future<WorkoutSession> begin({int? routineId, String? title}) async {
    final existing = await currentSessionId();
    if (existing != null) {
      throw StateError(
        'Ya hay un entrenamiento activo (sesión $existing). '
        'Finalizalo antes de iniciar uno nuevo.',
      );
    }
    final session = await workoutRepository.startSession(
      routineId: routineId,
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
}
