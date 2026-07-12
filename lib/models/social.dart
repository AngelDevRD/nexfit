class LeaderboardEntry {
  final String userId;
  final String name;
  final double value;
  final int rank;
  final bool isMe;

  LeaderboardEntry({
    required this.userId,
    required this.name,
    required this.value,
    required this.rank,
    required this.isMe,
  });
}

class ChallengeSummary {
  final String id;
  final String name;
  final String metric;
  final DateTime startsOn;
  final DateTime endsOn;
  final String inviteCode;
  final int participantCount;
  final bool isOwner;

  ChallengeSummary({
    required this.id,
    required this.name,
    required this.metric,
    required this.startsOn,
    required this.endsOn,
    required this.inviteCode,
    required this.participantCount,
    required this.isOwner,
  });
}

class ChallengeDetail extends ChallengeSummary {
  final String? description;
  final List<LeaderboardEntry> leaderboard;

  ChallengeDetail({
    required super.id,
    required super.name,
    required super.metric,
    required super.startsOn,
    required super.endsOn,
    required super.inviteCode,
    required super.participantCount,
    required super.isOwner,
    required this.description,
    required this.leaderboard,
  });
}

/// Metricas disponibles al crear un reto (value backend -> etiqueta ES + unidad).
const challengeMetrics = <String, String>{
  'total_volume_kg': 'Volumen total (kg)',
  'total_sessions': 'Sesiones entrenadas',
  'total_reps': 'Repeticiones totales',
};

String challengeMetricUnit(String metric) => switch (metric) {
  'total_volume_kg' => 'kg',
  'total_sessions' => 'sesiones',
  'total_reps' => 'reps',
  _ => '',
};
