import 'package:drift/drift.dart';

import '../core/local/database.dart' as local;
import '../models/nutrition.dart';

/// Reemplaza a `NutritionService` (FastAPI) -- offline-first vía Drift. Un
/// registro por día: `upsert` busca la fila existente de esa fecha y la
/// actualiza, o crea una nueva. `NutritionSyncable` sube los cambios a
/// Supabase (tabla `nutrition_logs`, `unique(user_id, log_date)`).
class NutritionRepository {
  final local.AppDatabase db;

  NutritionRepository(this.db);

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<List<NutritionLog>> list() async {
    final rows = await db.select(db.nutritionLogs).get();
    rows.sort((a, b) => b.logDate.compareTo(a.logDate));
    return rows.map(_toModel).toList();
  }

  /// [payload] tiene la misma forma que ya arma `nutrition_screen.dart` para
  /// el backend (log_date/calories/protein_g/carbs_g/fat_g/water_ml).
  Future<void> upsert(Map<String, dynamic> payload) async {
    final date = _dateOnly(DateTime.parse(payload['log_date'] as String));
    final existing = await (db.select(
      db.nutritionLogs,
    )..where((t) => t.logDate.equals(date))).getSingleOrNull();

    final companion = local.NutritionLogsCompanion(
      logDate: Value(date),
      calories: Value((payload['calories'] as num).toDouble()),
      proteinG: Value((payload['protein_g'] as num).toDouble()),
      carbsG: Value((payload['carbs_g'] as num).toDouble()),
      fatG: Value((payload['fat_g'] as num).toDouble()),
      waterMl: Value((payload['water_ml'] as num).toDouble()),
      updatedAt: Value(DateTime.now()),
      dirty: const Value(true),
    );

    if (existing == null) {
      await db.into(db.nutritionLogs).insert(companion);
    } else {
      await (db.update(
        db.nutritionLogs,
      )..where((t) => t.id.equals(existing.id))).write(companion);
    }
  }

  NutritionLog _toModel(local.NutritionLog r) => NutritionLog(
    id: r.id,
    logDate: r.logDate,
    calories: r.calories,
    proteinG: r.proteinG,
    carbsG: r.carbsG,
    fatG: r.fatG,
    waterMl: r.waterMl,
    notes: r.notes,
  );
}
