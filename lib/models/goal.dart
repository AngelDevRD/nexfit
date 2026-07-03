class Goal {
  final int id;
  final String title;
  final String metric;
  final int? exerciseId;
  final double startingValue;
  final double targetValue;
  final DateTime? targetDate;
  final DateTime? achievedAt;
  final double currentValue;
  final double progressPct;
  final bool achieved;

  Goal({
    required this.id,
    required this.title,
    required this.metric,
    this.exerciseId,
    required this.startingValue,
    required this.targetValue,
    this.targetDate,
    this.achievedAt,
    required this.currentValue,
    required this.progressPct,
    required this.achieved,
  });

  factory Goal.fromJson(Map<String, dynamic> json) => Goal(
    id: json['id'],
    title: json['title'],
    metric: json['metric'],
    exerciseId: json['exercise_id'],
    startingValue: (json['starting_value'] as num).toDouble(),
    targetValue: (json['target_value'] as num).toDouble(),
    targetDate: json['target_date'] != null
        ? DateTime.parse(json['target_date'])
        : null,
    achievedAt: json['achieved_at'] != null
        ? DateTime.parse(json['achieved_at'])
        : null,
    currentValue: (json['current_value'] as num).toDouble(),
    progressPct: (json['progress_pct'] as num).toDouble(),
    achieved: json['achieved'],
  );
}

const goalMetricLabels = <String, String>{
  'exercise_max_weight': 'Peso máximo en ejercicio',
  'exercise_max_reps': 'Repeticiones máximas en ejercicio',
  'body_weight_kg': 'Peso corporal',
  'body_fat_pct': '% Grasa corporal',
};
