import '../core/local/database.dart' as local;
import '../models/gamification.dart';
import 'stats_repository.dart';

const _xpPerSession = 10;
const _xpPerSet = 1;
const _xpPerRecord = 25;
const _xpPerLongestStreakDay = 2;
const _levelBands = [
  (20, 'elite'),
  (10, 'advanced'),
  (5, 'intermediate'),
  (1, 'novice'),
];

double _round1(double value) => (value * 10).round() / 10;

/// Reemplaza a `GamificationService` (FastAPI) -- port directo de
/// `backend/app/services/gamification.py`, ahora leyendo
/// `WorkoutSessions`/`WorkoutSets`/`PersonalRecords` locales. La app es
/// mono-usuario a nivel de Drift, así que no hace falta filtrar por
/// `user_id` como en el backend (todas las filas locales son del usuario
/// actual).
class GamificationRepository {
  final local.AppDatabase db;

  GamificationRepository(this.db);

  (int, double, double) _levelForXp(double totalXp) {
    var level = 1;
    while (100 * level * level <= totalXp) {
      level += 1;
    }
    final currentThreshold = 100 * (level - 1) * (level - 1);
    final nextThreshold = 100 * level * level;
    final progressPct = _round1(
      (totalXp - currentThreshold) / (nextThreshold - currentThreshold) * 100,
    );
    return (level, (nextThreshold - totalXp).toDouble(), progressPct);
  }

  String _bandForLevel(int level) {
    for (final (minLevel, band) in _levelBands) {
      if (level >= minLevel) return band;
    }
    return 'novice';
  }

  Future<GamificationProfile> profile() async {
    final sessions = await db.select(db.workoutSessions).get();
    final sessionsCompleted = sessions.where((s) => s.endedAt != null).length;

    final sets = await (db.select(
      db.workoutSets,
    )..where((t) => t.isWarmup.equals(false))).get();
    final setsLogged = sets.length;

    final records = await db.select(db.personalRecords).get();
    final recordsCount = records.length;

    final streak = await StatsRepository(db).streak();

    var lifetimeTonnage = 0.0;
    for (final set in sets) {
      lifetimeTonnage += set.weightKg * set.reps;
    }

    final totalXp =
        (sessionsCompleted * _xpPerSession +
                setsLogged * _xpPerSet +
                recordsCount * _xpPerRecord +
                streak.longestStreakDays * _xpPerLongestStreakDay)
            .toDouble();

    final (level, xpToNextLevel, progressPct) = _levelForXp(totalXp);

    final achievements = [
      Achievement(
        code: 'first_workout',
        title: 'Primer entrenamiento',
        unlocked: sessionsCompleted >= 1,
      ),
      Achievement(
        code: '100_workouts',
        title: '100 entrenamientos',
        unlocked: sessionsCompleted >= 100,
      ),
      Achievement(
        code: 'first_pr',
        title: 'Primer record personal',
        unlocked: recordsCount >= 1,
      ),
      Achievement(
        code: '100_prs',
        title: '100 records personales',
        unlocked: recordsCount >= 100,
      ),
      Achievement(
        code: '30_day_streak',
        title: '30 días consecutivos entrenando',
        unlocked: streak.longestStreakDays >= 30,
      ),
      Achievement(
        code: 'million_kg',
        title: '1,000,000 kg levantados en total',
        unlocked: lifetimeTonnage >= 1000000,
      ),
    ];

    return GamificationProfile(
      level: level,
      levelBand: _bandForLevel(level),
      totalXp: totalXp,
      xpToNextLevel: xpToNextLevel,
      progressPct: progressPct,
      sessionsCompleted: sessionsCompleted,
      recordsCount: recordsCount,
      longestStreakDays: streak.longestStreakDays,
      lifetimeTonnageKg: _round1(lifetimeTonnage),
      achievements: achievements,
    );
  }
}
