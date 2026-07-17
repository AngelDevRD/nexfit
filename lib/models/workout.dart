import 'exercise.dart';

class WorkoutSet {
  final int id;
  final int setNumber;
  final double weightKg;
  final int reps;
  final double? rpe;
  final int? rir;
  final int? restSeconds;
  final List<String> techniques;
  final int? supersetGroupId;
  final String? tempo;
  final bool isWarmup;
  final String? notes;
  final ExerciseSummary exercise;

  WorkoutSet({
    required this.id,
    required this.setNumber,
    required this.weightKg,
    required this.reps,
    this.rpe,
    this.rir,
    this.restSeconds,
    required this.techniques,
    this.supersetGroupId,
    this.tempo,
    required this.isWarmup,
    this.notes,
    required this.exercise,
  });

  factory WorkoutSet.fromJson(Map<String, dynamic> json) => WorkoutSet(
    id: json['id'],
    setNumber: json['set_number'],
    weightKg: (json['weight_kg'] as num).toDouble(),
    reps: json['reps'],
    rpe: (json['rpe'] as num?)?.toDouble(),
    rir: json['rir'],
    restSeconds: json['rest_seconds'],
    techniques: (json['techniques'] as List).map((e) => e.toString()).toList(),
    supersetGroupId: json['superset_group_id'],
    tempo: json['tempo'],
    isWarmup: json['is_warmup'] ?? false,
    notes: json['notes'],
    exercise: ExerciseSummary.fromJson(json['exercise']),
  );
}

class WorkoutSession {
  final int id;
  final int? routineId;
  final DateTime startedAt;
  final DateTime? endedAt;
  final String? notes;
  final List<WorkoutSet> sets;

  WorkoutSession({
    required this.id,
    this.routineId,
    required this.startedAt,
    this.endedAt,
    this.notes,
    required this.sets,
  });

  factory WorkoutSession.fromJson(Map<String, dynamic> json) => WorkoutSession(
    id: json['id'],
    routineId: json['routine_id'],
    startedAt: DateTime.parse(json['started_at']),
    endedAt: json['ended_at'] != null ? DateTime.parse(json['ended_at']) : null,
    notes: json['notes'],
    sets: (json['sets'] as List).map((e) => WorkoutSet.fromJson(e)).toList(),
  );
}

class WorkoutSessionSummary {
  final int id;
  final int? routineId;
  final String? title;
  final DateTime startedAt;
  final DateTime? endedAt;
  final double totalVolumeKg;
  final int exerciseCount;
  final int setCount;

  WorkoutSessionSummary({
    required this.id,
    this.routineId,
    this.title,
    required this.startedAt,
    this.endedAt,
    this.totalVolumeKg = 0,
    this.exerciseCount = 0,
    this.setCount = 0,
  });

  /// Duración real del entrenamiento (`ended_at - started_at`), o `null` si la
  /// sesión sigue en curso o el `ended_at` es claramente corrupto (más de 12 h,
  /// típico de sesiones importadas con el bug viejo). Nunca devuelve un valor
  /// absurdo: en la duda, `null` y la UI muestra "—".
  Duration? get duration {
    if (endedAt == null) return null;
    final d = endedAt!.difference(startedAt);
    if (d.isNegative || d.inHours > 12) return null;
    return d;
  }

  factory WorkoutSessionSummary.fromJson(Map<String, dynamic> json) =>
      WorkoutSessionSummary(
        id: json['id'],
        routineId: json['routine_id'],
        title: json['title'],
        startedAt: DateTime.parse(json['started_at']),
        endedAt: json['ended_at'] != null
            ? DateTime.parse(json['ended_at'])
            : null,
      );
}

/// Formatea una duración como "1 h 12 min" / "48 min" / "—" (nunca en miles de
/// minutos). Pura, para poder testearla sin widgets.
String formatWorkoutDuration(Duration? d) {
  if (d == null) return '—';
  final h = d.inHours;
  final m = d.inMinutes.remainder(60);
  if (h > 0) return '$h h $m min';
  return '$m min';
}

class PersonalRecord {
  final int id;
  final int? exerciseId;
  final String recordType;
  final double value;
  final double? previousValue;
  final DateTime achievedAt;

  PersonalRecord({
    required this.id,
    this.exerciseId,
    required this.recordType,
    required this.value,
    this.previousValue,
    required this.achievedAt,
  });

  factory PersonalRecord.fromJson(Map<String, dynamic> json) => PersonalRecord(
    id: json['id'],
    exerciseId: json['exercise_id'],
    recordType: json['record_type'],
    value: (json['value'] as num).toDouble(),
    previousValue: (json['previous_value'] as num?)?.toDouble(),
    achievedAt: DateTime.parse(json['achieved_at']),
  );
}

const recordTypeLabels = <String, String>{
  'max_weight': 'Mayor peso',
  'max_reps': 'Mayor repeticiones',
  'max_volume': 'Mayor volumen',
};

const availableTechniques = <String, String>{
  'drop_set': 'Drop Set',
  'rest_pause': 'Rest Pause',
  'myo_reps': 'Myo Reps',
  'cluster_set': 'Cluster Set',
  'forced_reps': 'Repeticiones forzadas',
  'to_failure': 'Al fallo',
  'isometric_pause': 'Pausa isométrica',
};
