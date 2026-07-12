import 'package:drift/drift.dart';

import '../core/local/database.dart' as local;
import '../models/stats.dart';

/// Umbrales de fuerza relativa por ejercicio/sexo -- portado tal cual de
/// `backend/app/data/strength_standards.py` (ver ese archivo para la nota
/// sobre su origen: referencia aproximada, no un dataset poblacional).
const _strengthStandards = <String, Map<String, List<double>>>{
  'press-banca-barra': {
    'male': [0.5, 0.75, 1.0, 1.5, 2.0],
    'female': [0.25, 0.4, 0.6, 0.9, 1.2],
  },
  'sentadilla-barra': {
    'male': [0.75, 1.0, 1.5, 2.0, 2.5],
    'female': [0.5, 0.75, 1.0, 1.5, 2.0],
  },
  'peso-muerto-convencional': {
    'male': [1.0, 1.25, 1.75, 2.25, 2.75],
    'female': [0.6, 0.9, 1.25, 1.75, 2.25],
  },
};
const _levelLabels = [
  'beginner',
  'novice',
  'intermediate',
  'advanced',
  'elite',
];
const _levelPercentiles = [5.0, 20.0, 50.0, 80.0, 95.0];

double _round(double value, int decimals) {
  final factor = decimals == 1 ? 10 : 100;
  return (value * factor).round() / factor;
}

/// Reemplaza a `StatsService` (FastAPI) -- todo el análisis se calcula acá
/// leyendo `WorkoutSessions`/`WorkoutSets`/`PersonalRecords`/`Profiles`
/// locales, sin ninguna llamada de red.
///
/// Fase 3b (ver docs/ARQUITECTURA_BACKEND.md): port directo de
/// `backend/app/services/stats.py`, `strength_standards.py` y
/// `predictions.py` -- mismas fórmulas, mismos umbrales, ahora on-device.
class StatsRepository {
  final local.AppDatabase db;

  StatsRepository(this.db);

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  int _floorDiv(int a, int b) => (a - (a % b)) ~/ b;

  String _dateKey(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-${d.month.toString().padLeft(2, '0')}-${d.day.toString().padLeft(2, '0')}';

  Future<List<MuscleVolumeEntry>> muscleAnalysis({int days = 30}) async {
    final cutoff = DateTime.now().subtract(Duration(days: days));
    final exercises = await db.select(db.exercises).get();
    final exerciseById = {for (final e in exercises) e.id: e};
    final sessions = await db.select(db.workoutSessions).get();
    final sessionById = {for (final s in sessions) s.id: s};
    final sets = await (db.select(
      db.workoutSets,
    )..where((t) => t.isWarmup.equals(false))).get();

    final totalSets = <String, int>{};
    final totalVolume = <String, double>{};
    final lastTrainedAt = <String, DateTime>{};

    for (final set in sets) {
      final session = sessionById[set.sessionId];
      if (session == null || session.startedAt.isBefore(cutoff)) continue;
      final exercise = exerciseById[set.exerciseId];
      if (exercise == null) continue;
      final muscleGroup = exercise.muscleGroup;
      totalSets[muscleGroup] = (totalSets[muscleGroup] ?? 0) + 1;
      totalVolume[muscleGroup] =
          (totalVolume[muscleGroup] ?? 0) + set.weightKg * set.reps;
      final current = lastTrainedAt[muscleGroup];
      if (current == null || session.startedAt.isAfter(current)) {
        lastTrainedAt[muscleGroup] = session.startedAt;
      }
    }

    final allMuscleGroups = exercises.map((e) => e.muscleGroup).toSet();
    final volumes = totalVolume.values.toList();

    String level(double volume) {
      if (volume <= 0) return 'muy_bajo';
      final rank = volumes.where((v) => v > volume).length / volumes.length;
      if (rank < 1 / 3) return 'alto';
      if (rank < 2 / 3) return 'medio';
      return 'bajo';
    }

    final result = <MuscleVolumeEntry>[
      for (final muscleGroup in allMuscleGroups)
        MuscleVolumeEntry(
          muscleGroup: muscleGroup,
          totalSets: totalSets[muscleGroup] ?? 0,
          totalVolume: totalVolume[muscleGroup] ?? 0.0,
          lastTrainedAt: lastTrainedAt[muscleGroup],
          level: level(totalVolume[muscleGroup] ?? 0.0),
        ),
    ];
    result.sort((a, b) => b.totalVolume.compareTo(a.totalVolume));
    return result;
  }

  Future<StrengthProfile> strengthProfile() async {
    final maxByExercise = <int, double>{};
    final records = await (db.select(
      db.personalRecords,
    )..where((t) => t.recordType.equals('max_weight'))).get();
    for (final r in records) {
      final exerciseId = r.exerciseId;
      if (exerciseId == null) continue;
      final current = maxByExercise[exerciseId];
      if (current == null || r.value > current) {
        maxByExercise[exerciseId] = r.value;
      }
    }

    final exercises = await db.select(db.exercises).get();
    final exerciseById = {for (final e in exercises) e.id: e};
    final maxStrength = [
      for (final entry in maxByExercise.entries)
        if (exerciseById[entry.key] != null)
          MaxStrengthEntry(
            exerciseId: entry.key,
            exerciseName: exerciseById[entry.key]!.name,
            maxWeightKg: entry.value,
          ),
    ];

    final cutoff = DateTime.now().subtract(const Duration(days: 7));
    final sessions = await db.select(db.workoutSessions).get();
    final sessionById = {for (final s in sessions) s.id: s};
    final sets = await (db.select(
      db.workoutSets,
    )..where((t) => t.isWarmup.equals(false))).get();

    double weeklyVolume = 0;
    final sessionsByMuscle = <String, Set<int>>{};
    for (final set in sets) {
      final session = sessionById[set.sessionId];
      if (session == null || session.startedAt.isBefore(cutoff)) continue;
      weeklyVolume += set.weightKg * set.reps;
      final exercise = exerciseById[set.exerciseId];
      if (exercise == null) continue;
      sessionsByMuscle
          .putIfAbsent(exercise.muscleGroup, () => {})
          .add(session.id);
    }

    return StrengthProfile(
      maxStrengthByExercise: maxStrength,
      weeklyVolumeKg: weeklyVolume,
      weeklyFrequencyByMuscle: [
        for (final entry in sessionsByMuscle.entries)
          MuscleFrequencyEntry(
            muscleGroup: entry.key,
            sessions: entry.value.length,
          ),
      ],
    );
  }

  Future<List<ExerciseProgressEntry>> exerciseProgress(int exerciseId) async {
    final sessions = await db.select(db.workoutSessions).get();
    final sessionById = {for (final s in sessions) s.id: s};
    final sets =
        await (db.select(db.workoutSets)..where(
              (t) => t.exerciseId.equals(exerciseId) & t.isWarmup.equals(false),
            ))
            .get();

    final bySession = <int, List<local.WorkoutSet>>{};
    for (final set in sets) {
      bySession.putIfAbsent(set.sessionId, () => []).add(set);
    }

    final entries = <ExerciseProgressEntry>[];
    for (final entry in bySession.entries) {
      final session = sessionById[entry.key];
      if (session == null) continue;
      final maxWeight = entry.value
          .map((s) => s.weightKg)
          .reduce((a, b) => a > b ? a : b);
      final volume = entry.value.fold<double>(
        0,
        (sum, s) => sum + s.weightKg * s.reps,
      );
      entries.add(
        ExerciseProgressEntry(
          sessionId: entry.key,
          date: session.startedAt,
          maxWeightKg: maxWeight,
          volumeKg: volume,
        ),
      );
    }
    entries.sort((a, b) => a.date.compareTo(b.date));
    return entries;
  }

  DateTime _periodStart(DateTime dt, String period) {
    final d = _dateOnly(dt);
    if (period == 'month') return DateTime(d.year, d.month, 1);
    return d.subtract(Duration(days: d.weekday - 1));
  }

  Future<List<TonnagePeriodEntry>> tonnage({
    String period = 'week',
    int periods = 12,
  }) async {
    final sessions = await db.select(db.workoutSessions).get();
    final sessionById = {for (final s in sessions) s.id: s};
    final sets = await (db.select(
      db.workoutSets,
    )..where((t) => t.isWarmup.equals(false))).get();

    final buckets = <String, double>{};
    for (final set in sets) {
      final session = sessionById[set.sessionId];
      if (session == null) continue;
      final key = _dateKey(_periodStart(session.startedAt, period));
      buckets[key] = (buckets[key] ?? 0) + set.weightKg * set.reps;
    }

    final today = _dateOnly(DateTime.now());
    final result = <TonnagePeriodEntry>[];
    for (var i = periods - 1; i >= 0; i--) {
      DateTime start;
      if (period == 'month') {
        final monthIndex = today.month - 1 - i;
        final year = today.year + _floorDiv(monthIndex, 12);
        final month = monthIndex % 12 + 1;
        start = DateTime(year, month, 1);
      } else {
        final weekStart = today.subtract(Duration(days: today.weekday - 1));
        start = weekStart.subtract(Duration(days: 7 * i));
      }
      result.add(
        TonnagePeriodEntry(
          periodStart: start,
          totalTonnageKg: _round(buckets[_dateKey(start)] ?? 0.0, 1),
        ),
      );
    }
    return result;
  }

  Future<TrainingStreak> streak() async {
    final sessions = await db.select(db.workoutSessions).get();
    final dates = sessions.map((s) => _dateOnly(s.startedAt)).toSet().toList()
      ..sort();

    if (dates.isEmpty) {
      return TrainingStreak(
        currentStreakDays: 0,
        longestStreakDays: 0,
        lastTrainedAt: null,
      );
    }

    var longest = 1;
    var run = 1;
    for (var i = 1; i < dates.length; i++) {
      if (dates[i].difference(dates[i - 1]).inDays == 1) {
        run += 1;
      } else {
        run = 1;
      }
      if (run > longest) longest = run;
    }

    final today = _dateOnly(DateTime.now());
    final lastDay = dates.last;
    var current = 0;
    if (today.difference(lastDay).inDays <= 1) {
      current = 1;
      for (var i = dates.length - 1; i > 0; i--) {
        if (dates[i].difference(dates[i - 1]).inDays == 1) {
          current += 1;
        } else {
          break;
        }
      }
    }

    return TrainingStreak(
      currentStreakDays: current,
      longestStreakDays: longest,
      lastTrainedAt: lastDay,
    );
  }

  double _interpolatePercentile(double ratio, List<double> thresholds) {
    if (ratio <= thresholds.first) {
      return thresholds.first > 0
          ? _round(_levelPercentiles.first * ratio / thresholds.first, 1)
          : 0.0;
    }
    if (ratio >= thresholds.last) return _levelPercentiles.last;

    for (var i = 0; i < thresholds.length - 1; i++) {
      final lower = thresholds[i];
      final upper = thresholds[i + 1];
      if (ratio >= lower && ratio <= upper) {
        final span = upper - lower;
        final fraction = span > 0 ? (ratio - lower) / span : 0.0;
        final percentile =
            _levelPercentiles[i] +
            fraction * (_levelPercentiles[i + 1] - _levelPercentiles[i]);
        return _round(percentile, 1);
      }
    }
    return _levelPercentiles.last;
  }

  String _levelLabel(double ratio, List<double> thresholds) {
    var level = _levelLabels.first;
    for (var i = 0; i < _levelLabels.length; i++) {
      if (ratio >= thresholds[i]) level = _levelLabels[i];
    }
    return level;
  }

  Future<StrengthStandard?> strengthStandards(int exerciseId) async {
    final exercise = await (db.select(
      db.exercises,
    )..where((t) => t.id.equals(exerciseId))).getSingleOrNull();
    if (exercise == null || !_strengthStandards.containsKey(exercise.slug)) {
      return null;
    }

    final profile = await db.select(db.profiles).getSingleOrNull();
    final weightKg = profile?.weightKg;
    final sex = profile?.sex;
    if (weightKg == null || sex == null) return null;

    final thresholds = _strengthStandards[exercise.slug]![sex];
    if (thresholds == null) return null;

    final records =
        await (db.select(db.personalRecords)..where(
              (t) =>
                  t.exerciseId.equals(exerciseId) &
                  t.recordType.equals('max_weight'),
            ))
            .get();
    if (records.isEmpty) return null;
    final best = records.reduce((a, b) => a.value >= b.value ? a : b);

    final ratio = best.value / weightKg;
    return StrengthStandard(
      exerciseId: exerciseId,
      exerciseName: exercise.name,
      liftKg: best.value,
      bodyweightKg: weightKg,
      ratio: _round(ratio, 2),
      percentile: _interpolatePercentile(ratio, thresholds),
      level: _levelLabel(ratio, thresholds),
    );
  }

  Future<RecordPrediction?> recordPrediction(
    int exerciseId, {
    int weeksAhead = 8,
  }) async {
    final exercise = await (db.select(
      db.exercises,
    )..where((t) => t.id.equals(exerciseId))).getSingleOrNull();
    if (exercise == null) return null;

    final records =
        await (db.select(db.personalRecords)
              ..where(
                (t) =>
                    t.exerciseId.equals(exerciseId) &
                    t.recordType.equals('max_weight'),
              )
              ..orderBy([(t) => OrderingTerm.asc(t.achievedAt)]))
            .get();
    if (records.length < 3) return null;

    final firstDate = records.first.achievedAt;
    final xs = records
        .map((r) => r.achievedAt.difference(firstDate).inDays.toDouble())
        .toList();
    final ys = records.map((r) => r.value).toList();
    final n = xs.length;

    final meanX = xs.reduce((a, b) => a + b) / n;
    final meanY = ys.reduce((a, b) => a + b) / n;
    var numerator = 0.0;
    var denominator = 0.0;
    for (var i = 0; i < n; i++) {
      numerator += (xs[i] - meanX) * (ys[i] - meanY);
      denominator += (xs[i] - meanX) * (xs[i] - meanX);
    }
    if (denominator == 0) return null;

    final slope = numerator / denominator;
    final intercept = meanY - slope * meanX;
    final targetX = xs.last + weeksAhead * 7;
    final predicted = intercept + slope * targetX;

    if (predicted <= ys.last) return null;

    return RecordPrediction(
      exerciseId: exerciseId,
      exerciseName: exercise.name,
      currentBestKg: ys.last,
      predictedKg: _round(predicted, 1),
      weeksAhead: weeksAhead,
      dataPoints: n,
    );
  }
}
