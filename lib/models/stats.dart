class MuscleVolumeEntry {
  final String muscleGroup;
  final int totalSets;
  final double totalVolume;
  final DateTime? lastTrainedAt;
  final String level;

  MuscleVolumeEntry({
    required this.muscleGroup,
    required this.totalSets,
    required this.totalVolume,
    this.lastTrainedAt,
    required this.level,
  });

  factory MuscleVolumeEntry.fromJson(Map<String, dynamic> json) =>
      MuscleVolumeEntry(
        muscleGroup: json['muscle_group'],
        totalSets: json['total_sets'],
        totalVolume: (json['total_volume'] as num).toDouble(),
        lastTrainedAt: json['last_trained_at'] != null
            ? DateTime.parse(json['last_trained_at'])
            : null,
        level: json['level'],
      );
}

class MaxStrengthEntry {
  final int exerciseId;
  final String exerciseName;
  final double maxWeightKg;

  MaxStrengthEntry({
    required this.exerciseId,
    required this.exerciseName,
    required this.maxWeightKg,
  });

  factory MaxStrengthEntry.fromJson(Map<String, dynamic> json) =>
      MaxStrengthEntry(
        exerciseId: json['exercise_id'],
        exerciseName: json['exercise_name'],
        maxWeightKg: (json['max_weight_kg'] as num).toDouble(),
      );
}

class MuscleFrequencyEntry {
  final String muscleGroup;
  final int sessions;

  MuscleFrequencyEntry({required this.muscleGroup, required this.sessions});

  factory MuscleFrequencyEntry.fromJson(Map<String, dynamic> json) =>
      MuscleFrequencyEntry(
        muscleGroup: json['muscle_group'],
        sessions: json['sessions'],
      );
}

class StrengthProfile {
  final List<MaxStrengthEntry> maxStrengthByExercise;
  final double weeklyVolumeKg;
  final List<MuscleFrequencyEntry> weeklyFrequencyByMuscle;

  StrengthProfile({
    required this.maxStrengthByExercise,
    required this.weeklyVolumeKg,
    required this.weeklyFrequencyByMuscle,
  });

  factory StrengthProfile.fromJson(Map<String, dynamic> json) =>
      StrengthProfile(
        maxStrengthByExercise: (json['max_strength_by_exercise'] as List)
            .map((e) => MaxStrengthEntry.fromJson(e))
            .toList(),
        weeklyVolumeKg: (json['weekly_volume_kg'] as num).toDouble(),
        weeklyFrequencyByMuscle: (json['weekly_frequency_by_muscle'] as List)
            .map((e) => MuscleFrequencyEntry.fromJson(e))
            .toList(),
      );
}

class ExerciseProgressEntry {
  final int sessionId;
  final DateTime date;
  final double maxWeightKg;
  final double volumeKg;

  ExerciseProgressEntry({
    required this.sessionId,
    required this.date,
    required this.maxWeightKg,
    required this.volumeKg,
  });

  factory ExerciseProgressEntry.fromJson(Map<String, dynamic> json) =>
      ExerciseProgressEntry(
        sessionId: json['session_id'],
        date: DateTime.parse(json['date']),
        maxWeightKg: (json['max_weight_kg'] as num).toDouble(),
        volumeKg: (json['volume_kg'] as num).toDouble(),
      );
}

class TonnagePeriodEntry {
  final DateTime periodStart;
  final double totalTonnageKg;

  TonnagePeriodEntry({required this.periodStart, required this.totalTonnageKg});

  factory TonnagePeriodEntry.fromJson(Map<String, dynamic> json) =>
      TonnagePeriodEntry(
        periodStart: DateTime.parse(json['period_start']),
        totalTonnageKg: (json['total_tonnage_kg'] as num).toDouble(),
      );
}

class TrainingStreak {
  final int currentStreakDays;
  final int longestStreakDays;
  final DateTime? lastTrainedAt;

  TrainingStreak({
    required this.currentStreakDays,
    required this.longestStreakDays,
    this.lastTrainedAt,
  });

  factory TrainingStreak.fromJson(Map<String, dynamic> json) => TrainingStreak(
    currentStreakDays: json['current_streak_days'],
    longestStreakDays: json['longest_streak_days'],
    lastTrainedAt: json['last_trained_at'] != null
        ? DateTime.parse(json['last_trained_at'])
        : null,
  );
}
