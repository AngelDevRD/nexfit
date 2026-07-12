import 'package:drift/drift.dart';

import '../core/local/database.dart' as local;
import '../models/recovery.dart';

/// Reemplaza a `RecoveryService` (FastAPI) -- offline-first vía Drift. Un
/// check-in por día, mismo patrón upsert-por-fecha que Nutrition.
///
/// Nota (Fase 2, ver docs/ARQUITECTURA_BACKEND.md): `compute_recovery_index`
/// en FastAPI pondera sueño+fatiga+carga de entrenamiento (tonelaje semanal
/// vía `personal_records`/`workout_sets`). La carga de entrenamiento es
/// estadística que recién se calcula on-device en la Fase 3 -- por ahora se
/// usa el mismo valor neutro que el propio backend usa cuando no hay
/// historial previo (`load_score = 100`), documentado explícitamente en vez
/// de omitir el factor en silencio. El índice se recalcula por completo en
/// la Fase 3 cuando el tonelaje esté disponible localmente.
class RecoveryRepository {
  final local.AppDatabase db;

  static const _sleepTargetHours = 8.0;

  RecoveryRepository(this.db);

  double _clamp(double value, [double low = 0, double high = 100]) =>
      value.clamp(low, high);

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<void> upsertCheckIn(
    DateTime date,
    double sleepHours,
    int perceivedFatigue,
  ) async {
    final day = _dateOnly(date);
    final existing = await (db.select(
      db.dailyCheckins,
    )..where((t) => t.checkinDate.equals(day))).getSingleOrNull();

    final companion = local.DailyCheckinsCompanion(
      checkinDate: Value(day),
      sleepHours: Value(sleepHours),
      perceivedFatigue: Value(perceivedFatigue),
      updatedAt: Value(DateTime.now()),
      dirty: const Value(true),
    );

    if (existing == null) {
      await db.into(db.dailyCheckins).insert(companion);
    } else {
      await (db.update(
        db.dailyCheckins,
      )..where((t) => t.id.equals(existing.id))).write(companion);
    }
  }

  Future<RecoveryIndex?> index() async {
    final rows = await db.select(db.dailyCheckins).get();
    if (rows.isEmpty) return null;
    rows.sort((a, b) => b.checkinDate.compareTo(a.checkinDate));
    final latest = rows.first;

    final sleepScore = _clamp((latest.sleepHours / _sleepTargetHours) * 100);
    final fatigueScore = _clamp((10 - latest.perceivedFatigue) * 10);
    const loadScore = 100.0; // ver nota de clase: pendiente de Fase 3.

    final recoveryIndex =
        (0.4 * sleepScore + 0.3 * fatigueScore + 0.3 * loadScore).round();
    final String level;
    if (recoveryIndex >= 80) {
      level = 'recovered';
    } else if (recoveryIndex >= 50) {
      level = 'medium';
    } else {
      level = 'high_fatigue_risk';
    }

    return RecoveryIndex(
      recoveryIndex: recoveryIndex,
      level: level,
      sleepHours: latest.sleepHours,
      perceivedFatigue: latest.perceivedFatigue,
      checkinDate: latest.checkinDate,
    );
  }
}
