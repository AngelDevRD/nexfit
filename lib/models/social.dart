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

  // Usado solo por `services/social_service.dart` (FastAPI, sin conectar
  // desde ninguna pantalla tras la Fase 2 -- ver docs/ARQUITECTURA_BACKEND.md).
  factory LeaderboardEntry.fromJson(Map<String, dynamic> json) =>
      LeaderboardEntry(
        userId: json['user_id'].toString(),
        name: json['name'],
        value: (json['value'] as num).toDouble(),
        rank: json['rank'],
        isMe: json['is_me'],
      );
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

  // Usado solo por `services/social_service.dart` (FastAPI, sin conectar
  // desde ninguna pantalla tras la Fase 2 -- ver docs/ARQUITECTURA_BACKEND.md).
  factory ChallengeSummary.fromJson(Map<String, dynamic> json) =>
      ChallengeSummary(
        id: json['id'].toString(),
        name: json['name'],
        metric: json['metric'],
        startsOn: DateTime.parse(json['starts_on']),
        endsOn: DateTime.parse(json['ends_on']),
        inviteCode: json['invite_code'],
        participantCount: json['participant_count'],
        isOwner: json['is_owner'],
      );
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

  // Usado solo por `services/social_service.dart` (FastAPI, sin conectar
  // desde ninguna pantalla tras la Fase 2 -- ver docs/ARQUITECTURA_BACKEND.md).
  factory ChallengeDetail.fromJson(Map<String, dynamic> json) =>
      ChallengeDetail(
        id: json['id'].toString(),
        name: json['name'],
        metric: json['metric'],
        startsOn: DateTime.parse(json['starts_on']),
        endsOn: DateTime.parse(json['ends_on']),
        inviteCode: json['invite_code'],
        participantCount: json['participant_count'],
        isOwner: json['is_owner'],
        description: json['description'],
        leaderboard: (json['leaderboard'] as List)
            .map((e) => LeaderboardEntry.fromJson(e))
            .toList(),
      );
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
