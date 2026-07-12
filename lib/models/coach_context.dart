/// Modelo de datos puro del contrato `CoachContext` v1 -- ver
/// docs/COACH_CONTEXT.md. Solo transporta datos y sabe serializarse a JSON;
/// no conoce HTTP, Supabase ni ningun repositorio (eso es responsabilidad de
/// `CoachContextBuilder`/`CoachContextSource`, ver lib/core/coach/).
library;

const coachContextVersion = 1;

class CoachContext {
  final int version;
  final String sessionId;
  final DateTime generatedAt;
  final CoachAppMetadata app;
  final CoachProfile profile;
  final CoachPreferences preferences;
  final CoachSettings settings;
  final CoachCapabilities capabilities;
  final List<CoachGoal> goals;
  final CoachRecovery? recovery;
  final CoachStats stats;
  final List<CoachRecentWorkout> recentWorkouts;
  final List<CoachPersonalRecord> personalRecords;
  final CoachAchievements achievements;
  final Map<String, dynamic> extensions;

  const CoachContext({
    this.version = coachContextVersion,
    required this.sessionId,
    required this.generatedAt,
    required this.app,
    required this.profile,
    required this.preferences,
    required this.settings,
    required this.capabilities,
    required this.goals,
    this.recovery,
    required this.stats,
    required this.recentWorkouts,
    required this.personalRecords,
    required this.achievements,
    this.extensions = const {},
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'sessionId': sessionId,
    'generatedAt': generatedAt.toIso8601String(),
    'app': app.toJson(),
    'profile': profile.toJson(),
    'preferences': preferences.toJson(),
    'settings': settings.toJson(),
    'capabilities': capabilities.toJson(),
    'goals': goals.map((g) => g.toJson()).toList(),
    'recovery': recovery?.toJson(),
    'stats': stats.toJson(),
    'recentWorkouts': recentWorkouts.map((w) => w.toJson()).toList(),
    'personalRecords': personalRecords.map((r) => r.toJson()).toList(),
    'achievements': achievements.toJson(),
    'extensions': extensions,
  };

  /// Copia con listas recortadas -- usado por `CoachContextBuilder` para
  /// aplicar el orden de recorte del presupuesto de tamaño (ver
  /// docs/COACH_CONTEXT.md "Presupuesto de tokens / tamaño").
  CoachContext copyWith({
    List<CoachRecentWorkout>? recentWorkouts,
    List<CoachPersonalRecord>? personalRecords,
  }) => CoachContext(
    version: version,
    sessionId: sessionId,
    generatedAt: generatedAt,
    app: app,
    profile: profile,
    preferences: preferences,
    settings: settings,
    capabilities: capabilities,
    goals: goals,
    recovery: recovery,
    stats: stats,
    recentWorkouts: recentWorkouts ?? this.recentWorkouts,
    personalRecords: personalRecords ?? this.personalRecords,
    achievements: achievements,
    extensions: extensions,
  );
}

class CoachAppMetadata {
  final String version;
  final String platform;
  final String timezone;

  const CoachAppMetadata({
    required this.version,
    required this.platform,
    required this.timezone,
  });

  Map<String, dynamic> toJson() => {
    'version': version,
    'platform': platform,
    'timezone': timezone,
  };
}

class CoachProfile {
  final String name;
  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;
  final double? bodyFatPct;

  const CoachProfile({
    required this.name,
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.bodyFatPct,
  });

  Map<String, dynamic> toJson() => {
    'name': name,
    'age': age,
    'sex': sex,
    'heightCm': heightCm,
    'weightKg': weightKg,
    'bodyFatPct': bodyFatPct,
  };
}

class CoachPreferences {
  final String? goal;
  final String? experienceLevel;
  final int? trainingDaysPerWeek;

  const CoachPreferences({
    this.goal,
    this.experienceLevel,
    this.trainingDaysPerWeek,
  });

  Map<String, dynamic> toJson() => {
    'goal': goal,
    'experienceLevel': experienceLevel,
    'trainingDaysPerWeek': trainingDaysPerWeek,
  };
}

class CoachSettings {
  final String language;
  final String units;
  final bool? notificationsEnabled;

  const CoachSettings({
    required this.language,
    required this.units,
    this.notificationsEnabled,
  });

  Map<String, dynamic> toJson() => {
    'language': language,
    'units': units,
    'notificationsEnabled': notificationsEnabled,
  };
}

class CoachCapabilities {
  final bool nutrition;
  final bool recovery;
  final bool social;
  final bool coach;

  const CoachCapabilities({
    this.nutrition = true,
    this.recovery = true,
    required this.social,
    this.coach = true,
  });

  Map<String, dynamic> toJson() => {
    'nutrition': nutrition,
    'recovery': recovery,
    'social': social,
    'coach': coach,
  };
}

class CoachGoal {
  final String title;
  final String metric;
  final double progressPct;
  final bool achieved;
  final DateTime? targetDate;

  const CoachGoal({
    required this.title,
    required this.metric,
    required this.progressPct,
    required this.achieved,
    this.targetDate,
  });

  Map<String, dynamic> toJson() => {
    'title': title,
    'metric': metric,
    'progressPct': progressPct,
    'achieved': achieved,
    'targetDate': targetDate?.toIso8601String(),
  };
}

class CoachRecovery {
  final int recoveryIndex;
  final String level;
  final double sleepHours;
  final int perceivedFatigue;
  final DateTime checkinDate;

  const CoachRecovery({
    required this.recoveryIndex,
    required this.level,
    required this.sleepHours,
    required this.perceivedFatigue,
    required this.checkinDate,
  });

  Map<String, dynamic> toJson() => {
    'recoveryIndex': recoveryIndex,
    'level': level,
    'sleepHours': sleepHours,
    'perceivedFatigue': perceivedFatigue,
    'checkinDate': checkinDate.toIso8601String().split('T').first,
  };
}

class CoachMaxStrengthEntry {
  final String exerciseName;
  final double maxWeightKg;

  const CoachMaxStrengthEntry({
    required this.exerciseName,
    required this.maxWeightKg,
  });

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'maxWeightKg': maxWeightKg,
  };
}

class CoachStats {
  final double weeklyVolumeKg;
  final int currentStreakDays;
  final int longestStreakDays;
  final List<CoachMaxStrengthEntry> maxStrengthByExercise;

  const CoachStats({
    required this.weeklyVolumeKg,
    required this.currentStreakDays,
    required this.longestStreakDays,
    required this.maxStrengthByExercise,
  });

  Map<String, dynamic> toJson() => {
    'weeklyVolumeKg': weeklyVolumeKg,
    'currentStreakDays': currentStreakDays,
    'longestStreakDays': longestStreakDays,
    'maxStrengthByExercise': maxStrengthByExercise
        .map((e) => e.toJson())
        .toList(),
  };
}

class CoachRecentWorkout {
  final DateTime date;
  final double totalVolumeKg;
  final List<String> exerciseSummaries;

  const CoachRecentWorkout({
    required this.date,
    required this.totalVolumeKg,
    required this.exerciseSummaries,
  });

  Map<String, dynamic> toJson() => {
    'date': date.toIso8601String().split('T').first,
    'totalVolumeKg': totalVolumeKg,
    'exerciseSummaries': exerciseSummaries,
  };
}

class CoachPersonalRecord {
  final String exerciseName;
  final String recordType;
  final double value;
  final DateTime achievedAt;

  const CoachPersonalRecord({
    required this.exerciseName,
    required this.recordType,
    required this.value,
    required this.achievedAt,
  });

  Map<String, dynamic> toJson() => {
    'exerciseName': exerciseName,
    'recordType': recordType,
    'value': value,
    'achievedAt': achievedAt.toIso8601String().split('T').first,
  };
}

class CoachAchievements {
  final int level;
  final String levelBand;
  final double totalXp;
  final List<String> unlocked;

  const CoachAchievements({
    required this.level,
    required this.levelBand,
    required this.totalXp,
    required this.unlocked,
  });

  Map<String, dynamic> toJson() => {
    'level': level,
    'levelBand': levelBand,
    'totalXp': totalXp,
    'unlocked': unlocked,
  };
}
