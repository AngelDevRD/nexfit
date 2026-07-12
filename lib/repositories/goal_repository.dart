import 'package:drift/drift.dart';

import '../core/local/database.dart' as local;
import '../models/goal.dart';

/// Reemplaza a `GoalService` (FastAPI) -- offline-first vía Drift, mismo
/// patrón create-or-delete que `RoutineRepository`. Los ids que devuelve son
/// siempre LOCALES; `GoalSyncable` traduce a `serverId` al sincronizar.
///
/// Fase 3a (ver docs/ARQUITECTURA_BACKEND.md): el progreso
/// (`current_value`/`progress_pct`/`achieved`), que en FastAPI calculaba
/// `compute_goal_progress` consultando `personal_records`/`profiles`, ahora
/// se calcula acá mismo leyendo `PersonalRecords`/`Profiles` locales -- ya no
/// depende de ningún backend. `PersonalRecords` ya se poblaba on-device
/// desde antes de esta fase (`WorkoutRepository._checkPersonalRecords`),
/// simplemente no se leía de vuelta todavía.
class GoalRepository {
  final local.AppDatabase db;

  GoalRepository(this.db);

  Future<List<Goal>> list() async {
    final rows = await (db.select(
      db.goals,
    )..where((t) => t.deleted.equals(false))).get();
    final goals = <Goal>[];
    for (final r in rows) {
      final current = await _currentValueFor(r.metric, r.exerciseId);
      goals.add(_toGoal(r, current));
    }
    return goals;
  }

  /// [payload] tiene la misma forma que ya arma `goals_screen.dart` para el
  /// backend (title/metric/exercise_id/target_value).
  Future<int> create(Map<String, dynamic> payload) async {
    final metric = payload['metric'] as String;
    final exerciseId = payload['exercise_id'] as int?;
    // Igual que `create_goal` en FastAPI: el punto de partida es el valor
    // actual del usuario al momento de crear el objetivo, no cero.
    final startingValue = (await _currentValueFor(metric, exerciseId)) ?? 0.0;

    return db
        .into(db.goals)
        .insert(
          local.GoalsCompanion.insert(
            title: payload['title'] as String,
            metric: metric,
            exerciseId: Value(exerciseId),
            startingValue: startingValue,
            targetValue: (payload['target_value'] as num).toDouble(),
            updatedAt: DateTime.now(),
          ),
        );
  }

  Future<void> delete(int id) async {
    await (db.update(db.goals)..where((t) => t.id.equals(id))).write(
      local.GoalsCompanion(
        deleted: const Value(true),
        dirty: const Value(true),
        updatedAt: Value(DateTime.now()),
      ),
    );
  }

  /// Espejo de `get_current_value` en `backend/app/services/goals.py`.
  Future<double?> _currentValueFor(String metric, int? exerciseId) async {
    switch (metric) {
      case 'body_weight_kg':
        final profile = await db.select(db.profiles).getSingleOrNull();
        return profile?.weightKg;
      case 'body_fat_pct':
        final profile = await db.select(db.profiles).getSingleOrNull();
        return profile?.bodyFatPct;
      case 'exercise_max_weight':
      case 'exercise_max_reps':
        if (exerciseId == null) return null;
        final recordType = metric == 'exercise_max_weight'
            ? 'max_weight'
            : 'max_reps';
        final records =
            await (db.select(db.personalRecords)..where(
                  (t) =>
                      t.exerciseId.equals(exerciseId) &
                      t.recordType.equals(recordType),
                ))
                .get();
        if (records.isEmpty) return null;
        return records.map((r) => r.value).reduce((a, b) => a > b ? a : b);
      default:
        return null;
    }
  }

  /// Espejo de `compute_goal_progress` en `backend/app/services/goals.py`.
  Goal _toGoal(local.Goal row, double? current) {
    final currentValue = current ?? row.startingValue;
    final increasing = row.targetValue >= row.startingValue;
    final span = (row.targetValue - row.startingValue).abs();

    double progressPct;
    if (span == 0) {
      progressPct = currentValue == row.targetValue ? 100.0 : 0.0;
    } else if (increasing) {
      progressPct = (((currentValue - row.startingValue) / span) * 100)
          .clamp(0.0, 100.0)
          .toDouble();
    } else {
      progressPct = (((row.startingValue - currentValue) / span) * 100)
          .clamp(0.0, 100.0)
          .toDouble();
    }

    final achieved = increasing
        ? currentValue >= row.targetValue
        : currentValue <= row.targetValue;

    return Goal(
      id: row.id,
      title: row.title,
      metric: row.metric,
      exerciseId: row.exerciseId,
      startingValue: row.startingValue,
      targetValue: row.targetValue,
      targetDate: row.targetDate,
      achievedAt: row.achievedAt,
      currentValue: currentValue,
      progressPct: progressPct,
      achieved: achieved,
    );
  }
}
