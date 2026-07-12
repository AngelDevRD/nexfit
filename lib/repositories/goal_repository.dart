import 'package:drift/drift.dart';

import '../core/local/database.dart' as local;
import '../models/goal.dart';

/// Reemplaza a `GoalService` (FastAPI) -- offline-first vía Drift, mismo
/// patrón create-or-delete que `RoutineRepository`. Los ids que devuelve son
/// siempre LOCALES; `GoalSyncable` traduce a `serverId` al sincronizar.
///
/// Nota (Fase 2, ver docs/ARQUITECTURA_BACKEND.md): el cálculo de progreso
/// (`current_value`/`progress_pct`/`achieved`) que antes hacía FastAPI
/// consultando `personal_records`/`profiles` queda deliberadamente sin
/// portar todavía -- depende de las estadísticas locales que llegan recién
/// en la Fase 3. Por ahora se muestra el objetivo sin progreso calculado
/// (`currentValue = startingValue`, `progressPct = 0`) en vez de simular un
/// valor que no es real.
class GoalRepository {
  final local.AppDatabase db;

  GoalRepository(this.db);

  Future<List<Goal>> list() async {
    final rows = await (db.select(
      db.goals,
    )..where((t) => t.deleted.equals(false))).get();
    return rows
        .map(
          (r) => Goal(
            id: r.id,
            title: r.title,
            metric: r.metric,
            exerciseId: r.exerciseId,
            startingValue: r.startingValue,
            targetValue: r.targetValue,
            targetDate: r.targetDate,
            achievedAt: r.achievedAt,
            currentValue: r.startingValue,
            progressPct: 0,
            achieved: r.achievedAt != null,
          ),
        )
        .toList();
  }

  /// [payload] tiene la misma forma que ya arma `goals_screen.dart` para el
  /// backend (title/metric/exercise_id/target_value).
  Future<int> create(Map<String, dynamic> payload) async {
    return db
        .into(db.goals)
        .insert(
          local.GoalsCompanion.insert(
            title: payload['title'] as String,
            metric: payload['metric'] as String,
            exerciseId: Value(payload['exercise_id'] as int?),
            startingValue: 0,
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
}
