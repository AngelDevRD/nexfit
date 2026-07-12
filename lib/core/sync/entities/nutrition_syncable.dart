import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../local/database.dart';
import '../syncable.dart';

/// Sync de Nutrición (Fase 2) contra Supabase. Upsert por `(user_id,
/// log_date)` -- coincide con el `unique` de la tabla y con el patrón
/// upsert-por-fecha de [NutritionRepository].
class NutritionSyncable implements SyncableEntity {
  final sb.SupabaseClient client;

  NutritionSyncable(this.client);

  @override
  String get name => 'nutrition_logs';

  @override
  Future<void> push(AppDatabase db) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final dirty = await (db.select(
      db.nutritionLogs,
    )..where((t) => t.dirty.equals(true))).get();

    for (final log in dirty) {
      final dateStr = log.logDate.toIso8601String().split('T').first;
      final upserted = await client
          .from('nutrition_logs')
          .upsert({
            'user_id': userId,
            'log_date': dateStr,
            'calories': log.calories,
            'protein_g': log.proteinG,
            'carbs_g': log.carbsG,
            'fat_g': log.fatG,
            'water_ml': log.waterMl,
            'notes': log.notes,
            'updated_at': log.updatedAt.toIso8601String(),
          }, onConflict: 'user_id,log_date')
          .select()
          .single();

      await (db.update(
        db.nutritionLogs,
      )..where((t) => t.id.equals(log.id))).write(
        NutritionLogsCompanion(
          serverId: Value(upserted['id'] as String),
          dirty: const Value(false),
        ),
      );
    }
  }
}
