import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../local/database.dart';
import '../syncable.dart';

/// Sync de Recovery (check-ins diarios, Fase 2) contra Supabase. Upsert por
/// `(user_id, checkin_date)`, mismo patrón que Nutrition.
class RecoverySyncable implements SyncableEntity {
  final sb.SupabaseClient client;

  RecoverySyncable(this.client);

  @override
  String get name => 'daily_checkins';

  @override
  Future<void> push(AppDatabase db) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final dirty = await (db.select(
      db.dailyCheckins,
    )..where((t) => t.dirty.equals(true))).get();

    for (final checkin in dirty) {
      final dateStr = checkin.checkinDate.toIso8601String().split('T').first;
      final upserted = await client
          .from('nexfit_daily_checkins')
          .upsert({
            'user_id': userId,
            'checkin_date': dateStr,
            'sleep_hours': checkin.sleepHours,
            'perceived_fatigue': checkin.perceivedFatigue,
          }, onConflict: 'user_id,checkin_date')
          .select()
          .single();

      await (db.update(
        db.dailyCheckins,
      )..where((t) => t.id.equals(checkin.id))).write(
        DailyCheckinsCompanion(
          serverId: Value(upserted['id'] as String),
          dirty: const Value(false),
        ),
      );
    }
  }
}
