import 'dart:convert';

import 'package:drift/drift.dart';

import '../../../services/workout_service.dart';
import '../../api_client.dart';
import '../../local/database.dart';
import '../syncable.dart';

/// Sync de sesiones de entrenamiento. A diferencia de Routines, el backend sí
/// soporta PATCH de la sesión y CRUD incremental de sets, así que una sesión
/// ya sincronizada puede seguir recibiendo cambios: se drena la cola
/// [PendingSetOps] set por set en vez de reenviar el árbol completo.
///
/// Requiere que [RoutineSyncable] haya corrido antes en la misma pasada de
/// sync: si la sesión referencia una rutina (`routineId`, id LOCAL) que
/// todavía no tiene `serverId`, se deja la sesión `dirty` para reintentar en
/// la próxima pasada en vez de romper la referencia.
class WorkoutSessionSyncable implements SyncableEntity {
  final ApiClient client;
  late final WorkoutService _service = WorkoutService(client);

  WorkoutSessionSyncable(this.client);

  @override
  String get name => 'workout_sessions';

  @override
  Future<void> push(AppDatabase db) async {
    final dirty = await (db.select(
      db.workoutSessions,
    )..where((t) => t.dirty.equals(true))).get();

    for (final session in dirty) {
      if (session.deleted) {
        await _pushDelete(db, session);
        continue;
      }

      int? serverRoutineId;
      if (session.routineId != null) {
        final routine = await (db.select(
          db.routines,
        )..where((t) => t.id.equals(session.routineId!))).getSingleOrNull();
        if (routine == null || routine.serverId == null) {
          // La rutina todavía no sincronizó -- reintentar esta sesión más
          // adelante en vez de mandarla sin rutina.
          continue;
        }
        serverRoutineId = routine.serverId;
      }

      int? serverId = session.serverId;
      if (serverId == null) {
        serverId = await _pushStart(db, session, serverRoutineId);
      } else if (session.endedAt != null) {
        await _service.finishSession(serverId);
      }
      await _drainPendingOps(db, session.id, serverId);
      await (db.update(db.workoutSessions)
            ..where((t) => t.id.equals(session.id)))
          .write(const WorkoutSessionsCompanion(dirty: Value(false)));
    }
  }

  Future<int> _pushStart(
    AppDatabase db,
    WorkoutSession session,
    int? serverRoutineId,
  ) async {
    final created = await _service.startSession(routineId: serverRoutineId);
    await (db.update(db.workoutSessions)..where((t) => t.id.equals(session.id)))
        .write(WorkoutSessionsCompanion(serverId: Value(created.id)));
    if (session.endedAt != null) {
      await _service.finishSession(created.id);
    }
    return created.id;
  }

  Future<void> _pushDelete(AppDatabase db, WorkoutSession session) async {
    // El backend no expone DELETE de sesión completa hoy -- se borra local
    // nomás. Si en el futuro se agrega, este es el lugar para llamarlo.
    await (db.delete(
      db.workoutSessions,
    )..where((t) => t.id.equals(session.id))).go();
  }

  Future<void> _drainPendingOps(
    AppDatabase db,
    int localSessionId,
    int serverSessionId,
  ) async {
    final ops = await (db.select(
      db.pendingSetOps,
    )..where((t) => t.sessionId.equals(localSessionId))).get();

    for (final pending in ops) {
      final payload = pending.payloadJson.isEmpty
          ? <String, dynamic>{}
          : jsonDecode(pending.payloadJson) as Map<String, dynamic>;

      switch (pending.op) {
        case 'insert':
          final createdSet = await _service.addSet(serverSessionId, payload);
          if (pending.localSetId != null) {
            await (db.update(db.workoutSets)
                  ..where((t) => t.id.equals(pending.localSetId!)))
                .write(WorkoutSetsCompanion(serverId: Value(createdSet.id)));
          }
          break;
        case 'update':
          if (pending.serverSetId != null) {
            await _service.updateSet(pending.serverSetId!, payload);
          }
          break;
        case 'delete':
          if (pending.serverSetId != null) {
            await _service.deleteSet(pending.serverSetId!);
          }
          break;
      }
      await (db.delete(
        db.pendingSetOps,
      )..where((t) => t.id.equals(pending.id))).go();
    }
  }
}
