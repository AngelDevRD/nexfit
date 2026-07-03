class RecoveryIndex {
  final int recoveryIndex;
  final String level;
  final double sleepHours;
  final int perceivedFatigue;
  final DateTime checkinDate;

  RecoveryIndex({
    required this.recoveryIndex,
    required this.level,
    required this.sleepHours,
    required this.perceivedFatigue,
    required this.checkinDate,
  });

  factory RecoveryIndex.fromJson(Map<String, dynamic> json) => RecoveryIndex(
    recoveryIndex: json['recovery_index'],
    level: json['level'],
    sleepHours: (json['sleep_hours'] as num).toDouble(),
    perceivedFatigue: json['perceived_fatigue'],
    checkinDate: DateTime.parse(json['checkin_date']),
  );
}

const recoveryLevelLabels = <String, String>{
  'recovered': '🟢 Recuperado',
  'medium': '🟡 Recuperación media',
  'high_fatigue_risk': '🔴 Alto riesgo de fatiga',
};
