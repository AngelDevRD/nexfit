import 'exercise.dart';

class RoutineExercise {
  final int id;
  final int order;
  final int targetSets;
  final int targetRepsMin;
  final int targetRepsMax;
  final int targetRestSeconds;
  final double? targetWeightKg;
  final String? notes;
  final ExerciseSummary exercise;

  RoutineExercise({
    required this.id,
    required this.order,
    required this.targetSets,
    required this.targetRepsMin,
    required this.targetRepsMax,
    required this.targetRestSeconds,
    this.targetWeightKg,
    this.notes,
    required this.exercise,
  });

  factory RoutineExercise.fromJson(Map<String, dynamic> json) =>
      RoutineExercise(
        id: json['id'],
        order: json['order'],
        targetSets: json['target_sets'],
        targetRepsMin: json['target_reps_min'],
        targetRepsMax: json['target_reps_max'],
        targetRestSeconds: json['target_rest_seconds'],
        targetWeightKg: (json['target_weight_kg'] as num?)?.toDouble(),
        notes: json['notes'],
        exercise: ExerciseSummary.fromJson(json['exercise']),
      );
}

class RoutineDay {
  final int id;
  final int dayIndex;
  final String name;
  final String? muscleFocus;
  final List<RoutineExercise> exercises;

  RoutineDay({
    required this.id,
    required this.dayIndex,
    required this.name,
    this.muscleFocus,
    required this.exercises,
  });

  factory RoutineDay.fromJson(Map<String, dynamic> json) => RoutineDay(
    id: json['id'],
    dayIndex: json['day_index'],
    name: json['name'],
    muscleFocus: json['muscle_focus'],
    exercises: (json['exercises'] as List)
        .map((e) => RoutineExercise.fromJson(e))
        .toList(),
  );
}

class Routine {
  final int id;
  final String name;
  final String? goal;
  final int daysPerWeek;
  final List<RoutineDay> days;

  Routine({
    required this.id,
    required this.name,
    this.goal,
    required this.daysPerWeek,
    required this.days,
  });

  factory Routine.fromJson(Map<String, dynamic> json) => Routine(
    id: json['id'],
    name: json['name'],
    goal: json['goal'],
    daysPerWeek: json['days_per_week'],
    days: (json['days'] as List).map((e) => RoutineDay.fromJson(e)).toList(),
  );
}

class RoutineSummary {
  final int id;
  final String name;
  final String? goal;
  final int daysPerWeek;
  final List<String> exerciseNames;

  RoutineSummary({
    required this.id,
    required this.name,
    this.goal,
    required this.daysPerWeek,
    this.exerciseNames = const [],
  });

  factory RoutineSummary.fromJson(Map<String, dynamic> json) => RoutineSummary(
    id: json['id'],
    name: json['name'],
    goal: json['goal'],
    daysPerWeek: json['days_per_week'],
  );
}
