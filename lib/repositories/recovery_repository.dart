import 'package:drift/drift.dart';

import '../core/local/database.dart' as local;
import '../models/recovery.dart';

/// Reemplaza a `RecoveryService` (FastAPI) -- offline-first vía Drift. Un
/// check-in por día, mismo patrón upsert-por-fecha que Nutrition.
///
/// Fase 3a (ver docs/ARQUITECTURA_BACKEND.md): `compute_recovery_index`
/// (`legacy/backend_fastapi/app/services/recovery.py`) pondera sueño (40%) + fatiga
/// percibida (30%) + carga de entrenamiento vía tonelaje semanal (30%). Los
/// tres factores ahora se calculan acá leyendo `DailyCheckins`/`WorkoutSets`/
/// `WorkoutSessions` locales -- ya no depende de ningún backend.
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
    final loadScore = await _weeklyLoadScore();

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

  DateTime _weekStart(DateTime d) =>
      DateTime(d.year, d.month, d.day).subtract(Duration(days: d.weekday - 1));

  /// Espejo del componente `load_score` de `compute_recovery_index`: compara
  /// el tonelaje (peso × reps, sin warmups) de esta semana contra el
  /// promedio de las 4 anteriores -- misma ventana de 5 semanas que
  /// `get_tonnage_history(db, user_id, period="week", periods=5)`.
  Future<double> _weeklyLoadScore() async {
    final sessions = await db.select(db.workoutSessions).get();
    final startedAtBySession = {for (final s in sessions) s.id: s.startedAt};
    final sets = await (db.select(
      db.workoutSets,
    )..where((t) => t.isWarmup.equals(false))).get();

    final buckets = <DateTime, double>{};
    for (final set in sets) {
      final startedAt = startedAtBySession[set.sessionId];
      if (startedAt == null) continue;
      final key = _weekStart(startedAt);
      buckets[key] = (buckets[key] ?? 0) + set.weightKg * set.reps;
    }

    final today = _weekStart(DateTime.now());
    final tonnage = [
      for (var i = 4; i >= 0; i--)
        buckets[today.subtract(Duration(days: 7 * i))] ?? 0.0,
    ];

    final thisWeek = tonnage.last;
    final previousWeeks = tonnage
        .sublist(0, tonnage.length - 1)
        .where((t) => t > 0)
        .toList();
    if (previousWeeks.isEmpty) return 100.0;

    final avgPrevious =
        previousWeeks.reduce((a, b) => a + b) / previousWeeks.length;
    if (avgPrevious <= 0) return 100.0;

    final overloadRatio = thisWeek / avgPrevious;
    final overshoot = overloadRatio - 1;
    return _clamp(100 - (overshoot > 0 ? overshoot : 0) * 100);
  }
}
