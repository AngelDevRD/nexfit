import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../local/database.dart';
import '../syncable.dart';

/// Sync de sesiones de entrenamiento contra Supabase (Fase 2, ver
/// docs/ARQUITECTURA_BACKEND.md -- antes apuntaba a FastAPI vía
/// `WorkoutService`/`ApiClient`). A diferencia de Routines, Supabase sí
/// soporta actualizar la sesión (marcar `ended_at`) y CRUD incremental de
/// sets, así que una sesión ya sincronizada puede seguir recibiendo cambios:
/// se drena la cola [PendingSetOps] set por set en vez de reenviar el árbol
/// completo.
///
/// Requiere que [RoutineSyncable] haya corrido antes en la misma pasada de
/// sync: si la sesión referencia una rutina (`routineId`, id LOCAL) que
/// todavía no tiene `serverId`, se deja la sesión `dirty` para reintentar en
/// la próxima pasada en vez de romper la referencia.
class WorkoutSessionSyncable implements SyncableEntity {
  final sb.SupabaseClient client;

  WorkoutSessionSyncable(this.client);

  @override
  String get name => 'workout_sessions';

  @override
  Future<void> push(AppDatabase db) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final dirty = await (db.select(
      db.workoutSessions,
    )..where((t) => t.dirty.equals(true))).get();

    for (final session in dirty) {
      if (session.deleted) {
        await _pushDelete(db, session);
        continue;
      }

      String? serverRoutineId;
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

      String? serverId = session.serverId;
      if (serverId == null) {
        serverId = await _pushStart(db, session, userId, serverRoutineId);
      } else if (session.endedAt != null) {
        await client
            .from('workout_sessions')
            .update({'ended_at': session.endedAt!.toIso8601String()})
            .eq('id', serverId);
      }
      await _drainPendingOps(db, session.id, serverId);
      await (db.update(db.workoutSessions)
            ..where((t) => t.id.equals(session.id)))
          .write(const WorkoutSessionsCompanion(dirty: Value(false)));
    }
  }

  Future<String> _pushStart(
    AppDatabase db,
    WorkoutSession session,
    String userId,
    String? serverRoutineId,
  ) async {
    final created = await client
        .from('workout_sessions')
        .insert({
          'user_id': userId,
          'routine_id': serverRoutineId,
          'started_at': session.startedAt.toIso8601String(),
          if (session.endedAt != null)
            'ended_at': session.endedAt!.toIso8601String(),
          'notes': session.notes,
        })
        .select()
        .single();
    final serverId = created['id'] as String;
    await (db.update(db.workoutSessions)..where((t) => t.id.equals(session.id)))
        .write(WorkoutSessionsCompanion(serverId: Value(serverId)));
    return serverId;
  }

  Future<void> _pushDelete(AppDatabase db, WorkoutSession session) async {
    if (session.serverId != null) {
      // Cascade en Supabase se encarga de workout_sets.
      await client
          .from('workout_sessions')
          .delete()
          .eq('id', session.serverId!);
    }
    await (db.delete(
      db.workoutSessions,
    )..where((t) => t.id.equals(session.id))).go();
  }

  Future<void> _drainPendingOps(
    AppDatabase db,
    int localSessionId,
    String serverSessionId,
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
          final createdSet = await client
              .from('workout_sets')
              .insert({'session_id': serverSessionId, ...payload})
              .select()
              .single();
          if (pending.localSetId != null) {
            await (db.update(
              db.workoutSets,
            )..where((t) => t.id.equals(pending.localSetId!))).write(
              WorkoutSetsCompanion(serverId: Value(createdSet['id'] as String)),
            );
          }
          break;
        case 'update':
          if (pending.serverSetId != null) {
            await client
                .from('workout_sets')
                .update(payload)
                .eq('id', pending.serverSetId!);
          }
          break;
        case 'delete':
          if (pending.serverSetId != null) {
            await client
                .from('workout_sets')
                .delete()
                .eq('id', pending.serverSetId!);
          }
          break;
      }
      await (db.delete(
        db.pendingSetOps,
      )..where((t) => t.id.equals(pending.id))).go();
    }
  }
}
