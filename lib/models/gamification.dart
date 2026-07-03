class Achievement {
  final String code;
  final String title;
  final bool unlocked;

  Achievement({
    required this.code,
    required this.title,
    required this.unlocked,
  });

  factory Achievement.fromJson(Map<String, dynamic> json) => Achievement(
    code: json['code'],
    title: json['title'],
    unlocked: json['unlocked'],
  );
}

class GamificationProfile {
  final int level;
  final String levelBand;
  final double totalXp;
  final double xpToNextLevel;
  final double progressPct;
  final int sessionsCompleted;
  final int recordsCount;
  final int longestStreakDays;
  final double lifetimeTonnageKg;
  final List<Achievement> achievements;

  GamificationProfile({
    required this.level,
    required this.levelBand,
    required this.totalXp,
    required this.xpToNextLevel,
    required this.progressPct,
    required this.sessionsCompleted,
    required this.recordsCount,
    required this.longestStreakDays,
    required this.lifetimeTonnageKg,
    required this.achievements,
  });

  factory GamificationProfile.fromJson(Map<String, dynamic> json) =>
      GamificationProfile(
        level: json['level'],
        levelBand: json['level_band'],
        totalXp: (json['total_xp'] as num).toDouble(),
        xpToNextLevel: (json['xp_to_next_level'] as num).toDouble(),
        progressPct: (json['progress_pct'] as num).toDouble(),
        sessionsCompleted: json['sessions_completed'],
        recordsCount: json['records_count'],
        longestStreakDays: json['longest_streak_days'],
        lifetimeTonnageKg: (json['lifetime_tonnage_kg'] as num).toDouble(),
        achievements: (json['achievements'] as List)
            .map((e) => Achievement.fromJson(e))
            .toList(),
      );
}

const levelBandLabels = <String, String>{
  'novice': 'Novato',
  'intermediate': 'Intermedio',
  'advanced': 'Avanzado',
  'elite': 'Élite',
};
