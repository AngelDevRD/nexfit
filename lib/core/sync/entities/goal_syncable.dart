import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../local/database.dart';
import '../syncable.dart';

/// Sync de Objetivos (Fase 2) contra Supabase. Mismo patrón create-or-delete
/// que [RoutineSyncable] -- sin edición una vez creado, que hoy tampoco
/// ofrece la UI (`goals_screen.dart` solo crea y borra).
class GoalSyncable implements SyncableEntity {
  final sb.SupabaseClient client;

  GoalSyncable(this.client);

  @override
  String get name => 'goals';

  @override
  Future<void> push(AppDatabase db) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final dirty = await (db.select(
      db.goals,
    )..where((t) => t.dirty.equals(true))).get();

    for (final goal in dirty) {
      if (goal.deleted) {
        if (goal.serverId != null) {
          await client.from('goals').delete().eq('id', goal.serverId!);
        }
        await (db.delete(db.goals)..where((t) => t.id.equals(goal.id))).go();
        continue;
      }
      if (goal.serverId == null) {
        final created = await client
            .from('goals')
            .insert({
              'user_id': userId,
              'title': goal.title,
              'metric': goal.metric,
              'exercise_id': goal.exerciseId,
              'starting_value': goal.startingValue,
              'target_value': goal.targetValue,
              'target_date': goal.targetDate
                  ?.toIso8601String()
                  .split('T')
                  .first,
            })
            .select()
            .single();
        await (db.update(db.goals)..where((t) => t.id.equals(goal.id))).write(
          GoalsCompanion(
            serverId: Value(created['id'] as String),
            dirty: const Value(false),
          ),
        );
      } else {
        await (db.update(db.goals)..where((t) => t.id.equals(goal.id))).write(
          const GoalsCompanion(dirty: Value(false)),
        );
      }
    }
  }
}
