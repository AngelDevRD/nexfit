import 'package:drift/drift.dart';

import '../../core/local/database.dart' as local;
import '../../models/goal.dart';
import '../../models/gamification.dart';
import '../../models/profile.dart';
import '../../models/recovery.dart';
import '../../models/stats.dart';
import '../../repositories/gamification_repository.dart';
import '../../repositories/goal_repository.dart';
import '../../repositories/profile_repository.dart';
import '../../repositories/recovery_repository.dart';
import '../../repositories/stats_repository.dart';

/// Un entrenamiento reciente, en bruto -- sin resumir todavia (eso lo hace
/// `CoachContextBuilder`). Solo series que no son calentamiento.
class RawWorkoutSession {
  final DateTime date;
  final List<RawWorkoutSet> sets;

  const RawWorkoutSession({required this.date, required this.sets});
}

class RawWorkoutSet {
  final String exerciseName;
  final double weightKg;
  final int reps;

  const RawWorkoutSet({
    required this.exerciseName,
    required this.weightKg,
    required this.reps,
  });
}

class RawPersonalRecord {
  final String exerciseName;
  final String recordType;
  final double value;
  final DateTime achievedAt;

  const RawPersonalRecord({
    required this.exerciseName,
    required this.recordType,
    required this.value,
    required this.achievedAt,
  });
}

/// Interfaz de lectura del contexto -- `CoachContextBuilder` (puro, sin
/// conocer ningun repositorio) solo depende de esto, no de
/// `ProfileRepository`/`GoalRepository`/etc. directamente. Permite testear el
/// builder con un fake y, a futuro, construir el contexto desde otra fuente
/// sin tocarlo.
abstract class CoachContextSource {
  Future<Profile?> loadProfile();
  Future<List<Goal>> loadGoals();
  Future<RecoveryIndex?> loadRecovery();
  Future<StrengthProfile> loadStrengthProfile();
  Future<TrainingStreak> loadStreak();
  Future<GamificationProfile> loadGamification();
  Future<List<RawWorkoutSession>> loadRecentWorkoutSessions({
    required int maxSessions,
    required DateTime since,
  });
  Future<List<RawPersonalRecord>> loadPersonalRecords();

  /// Si `SocialRepository`/`SupabaseClient` no están disponibles en esta
  /// sesión (ver `main.dart`) -- alimenta `CoachContext.capabilities.social`.
  bool get socialAvailable;
}

/// Implementacion real -- combina los repositorios ya existentes de las
/// Fases 2/3, sin ninguna query nueva mas alla del detalle de
/// `recentWorkouts`/`personalRecords` (que sigue el mismo patron de lectura
/// directa de Drift que ya usa `StatsRepository`).
class DefaultCoachContextSource implements CoachContextSource {
  final local.AppDatabase db;
  final String userId;
  final ProfileRepository profileRepository;
  final GoalRepository goalRepository;
  final RecoveryRepository recoveryRepository;
  final StatsRepository statsRepository;
  final GamificationRepository gamificationRepository;
  @override
  final bool socialAvailable;

  DefaultCoachContextSource({
    required this.db,
    required this.userId,
    required this.profileRepository,
    required this.goalRepository,
    required this.recoveryRepository,
    required this.statsRepository,
    required this.gamificationRepository,
    required this.socialAvailable,
  });

  @override
  Future<Profile?> loadProfile() => profileRepository.get(userId);

  @override
  Future<List<Goal>> loadGoals() => goalRepository.list();

  @override
  Future<RecoveryIndex?> loadRecovery() => recoveryRepository.index();

  @override
  Future<StrengthProfile> loadStrengthProfile() =>
      statsRepository.strengthProfile();

  @override
  Future<TrainingStreak> loadStreak() => statsRepository.streak();

  @override
  Future<GamificationProfile> loadGamification() =>
      gamificationRepository.profile();

  @override
  Future<List<RawWorkoutSession>> loadRecentWorkoutSessions({
    required int maxSessions,
    required DateTime since,
  }) async {
    final sessions =
        await (db.select(db.workoutSessions)
              ..where((t) => t.startedAt.isBiggerOrEqualValue(since))
              ..orderBy([(t) => OrderingTerm.desc(t.startedAt)])
              ..limit(maxSessions))
            .get();
    if (sessions.isEmpty) return [];

    final exercises = await db.select(db.exercises).get();
    final exerciseNameById = {for (final e in exercises) e.id: e.name};

    final result = <RawWorkoutSession>[];
    for (final session in sessions) {
      final sets =
          await (db.select(db.workoutSets)..where(
                (t) =>
                    t.sessionId.equals(session.id) & t.isWarmup.equals(false),
              ))
              .get();
      result.add(
        RawWorkoutSession(
          date: session.startedAt,
          sets: [
            for (final set in sets)
              RawWorkoutSet(
                exerciseName: exerciseNameById[set.exerciseId] ?? 'Ejercicio',
                weightKg: set.weightKg,
                reps: set.reps,
              ),
          ],
        ),
      );
    }
    return result;
  }

  @override
  Future<List<RawPersonalRecord>> loadPersonalRecords() async {
    final records = await db.select(db.personalRecords).get();
    if (records.isEmpty) return [];

    final exercises = await db.select(db.exercises).get();
    final exerciseNameById = {for (final e in exercises) e.id: e.name};

    return [
      for (final r in records)
        if (r.exerciseId != null)
          RawPersonalRecord(
            exerciseName: exerciseNameById[r.exerciseId] ?? 'Ejercicio',
            recordType: r.recordType,
            value: r.value,
            achievedAt: r.achievedAt,
          ),
    ];
  }
}
