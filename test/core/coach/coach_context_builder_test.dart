import 'package:appgym/core/coach/coach_context_builder.dart';
import 'package:appgym/core/coach/coach_context_source.dart';
import 'package:appgym/models/gamification.dart';
import 'package:appgym/models/goal.dart';
import 'package:appgym/models/profile.dart';
import 'package:appgym/models/recovery.dart';
import 'package:appgym/models/stats.dart';
import 'package:flutter_test/flutter_test.dart';

class _FakeCoachContextSource implements CoachContextSource {
  Profile? profile;
  List<Goal> goals = [];
  RecoveryIndex? recovery;
  StrengthProfile strengthProfile = StrengthProfile(
    maxStrengthByExercise: const [],
    weeklyVolumeKg: 0,
    weeklyFrequencyByMuscle: const [],
  );
  TrainingStreak streak = TrainingStreak(
    currentStreakDays: 0,
    longestStreakDays: 0,
  );
  GamificationProfile gamification = GamificationProfile(
    level: 1,
    levelBand: 'novice',
    totalXp: 0,
    xpToNextLevel: 100,
    progressPct: 0,
    sessionsCompleted: 0,
    recordsCount: 0,
    longestStreakDays: 0,
    lifetimeTonnageKg: 0,
    achievements: const [],
  );
  List<RawWorkoutSession> recentSessions = [];
  List<RawPersonalRecord> personalRecords = [];
  @override
  bool socialAvailable = true;

  @override
  Future<Profile?> loadProfile() async => profile;

  @override
  Future<List<Goal>> loadGoals() async => goals;

  @override
  Future<RecoveryIndex?> loadRecovery() async => recovery;

  @override
  Future<StrengthProfile> loadStrengthProfile() async => strengthProfile;

  @override
  Future<TrainingStreak> loadStreak() async => streak;

  @override
  Future<GamificationProfile> loadGamification() async => gamification;

  @override
  Future<List<RawWorkoutSession>> loadRecentWorkoutSessions({
    required int maxSessions,
    required DateTime since,
  }) async {
    final filtered = recentSessions
        .where((s) => !s.date.isBefore(since))
        .toList();
    return filtered.take(maxSessions).toList();
  }

  @override
  Future<List<RawPersonalRecord>> loadPersonalRecords() async =>
      personalRecords;
}

void main() {
  late _FakeCoachContextSource source;
  late DateTime fixedNow;

  setUp(() {
    source = _FakeCoachContextSource();
    fixedNow = DateTime(2026, 7, 12, 18, 0, 0);
  });

  CoachContextBuilder builder() => CoachContextBuilder(
    source: source,
    now: () => fixedNow,
    platformName: () => 'android',
  );

  test('version y metadatos basicos', () async {
    final context = await builder().build(sessionId: 'session-1');

    expect(context.version, 1);
    expect(context.sessionId, 'session-1');
    expect(context.generatedAt, fixedNow);
    expect(context.app.platform, 'android');
    expect(context.extensions, isEmpty);
  });

  test('perfil y preferencias se dividen del mismo Profile', () async {
    source.profile = const Profile(
      id: 'user-1',
      name: 'Angel',
      age: 28,
      sex: 'male',
      heightCm: 175,
      weightKg: 78.5,
      goal: 'hypertrophy',
      experienceLevel: 'intermediate',
    );

    final context = await builder().build(sessionId: 's');

    expect(context.profile.name, 'Angel');
    expect(context.profile.age, 28);
    expect(context.preferences.goal, 'hypertrophy');
    expect(context.preferences.experienceLevel, 'intermediate');
  });

  test('capabilities.social refleja el CoachContextSource', () async {
    source.socialAvailable = false;
    final context = await builder().build(sessionId: 's');
    expect(context.capabilities.social, false);
    expect(context.capabilities.coach, true);
  });

  test(
    'recentWorkouts excluye sesiones fuera de la ventana de 14 dias',
    () async {
      source.recentSessions = [
        RawWorkoutSession(
          date: fixedNow.subtract(const Duration(days: 1)),
          sets: const [
            RawWorkoutSet(exerciseName: 'Sentadilla', weightKg: 100, reps: 5),
          ],
        ),
        RawWorkoutSession(
          date: fixedNow.subtract(const Duration(days: 20)), // fuera de ventana
          sets: const [
            RawWorkoutSet(exerciseName: 'Press banca', weightKg: 80, reps: 5),
          ],
        ),
      ];

      final context = await builder().build(sessionId: 's');

      expect(context.recentWorkouts, hasLength(1));
      expect(
        context.recentWorkouts.first.exerciseSummaries.first,
        'Sentadilla 100kg x 5 reps',
      );
    },
  );

  test(
    'exerciseSummaries condensa varias series del mismo ejercicio en una linea (el set de mayor peso)',
    () async {
      source.recentSessions = [
        RawWorkoutSession(
          date: fixedNow,
          sets: const [
            RawWorkoutSet(exerciseName: 'Sentadilla', weightKg: 80, reps: 8),
            RawWorkoutSet(exerciseName: 'Sentadilla', weightKg: 100, reps: 5),
            RawWorkoutSet(exerciseName: 'Sentadilla', weightKg: 90, reps: 6),
          ],
        ),
      ];

      final context = await builder().build(sessionId: 's');

      expect(context.recentWorkouts.single.exerciseSummaries, [
        'Sentadilla 100kg x 5 reps',
      ]);
      // 80*8 + 100*5 + 90*6 = 640+500+540 = 1680
      expect(context.recentWorkouts.single.totalVolumeKg, 1680.0);
    },
  );

  test('recovery es null cuando el usuario nunca hizo check-in', () async {
    source.recovery = null;
    final context = await builder().build(sessionId: 's');
    expect(context.recovery, isNull);
  });

  test('achievements solo incluye los codigos desbloqueados', () async {
    source.gamification = GamificationProfile(
      level: 3,
      levelBand: 'intermediate',
      totalXp: 500,
      xpToNextLevel: 400,
      progressPct: 50,
      sessionsCompleted: 10,
      recordsCount: 2,
      longestStreakDays: 5,
      lifetimeTonnageKg: 10000,
      achievements: [
        Achievement(code: 'first_workout', title: 'x', unlocked: true),
        Achievement(code: '100_workouts', title: 'y', unlocked: false),
        Achievement(code: 'first_pr', title: 'z', unlocked: true),
      ],
    );

    final context = await builder().build(sessionId: 's');

    expect(context.achievements.unlocked, ['first_workout', 'first_pr']);
  });

  test(
    'presupuesto de tamaño: recorta recentWorkouts si el contexto supera 15KB',
    () async {
      // 10 sesiones con muchos ejercicios distintos (nombres largos, sin
      // repetirse dentro de la sesion) para forzar de sobra el recorte.
      source.recentSessions = [
        for (var day = 0; day < 14; day++)
          RawWorkoutSession(
            date: fixedNow.subtract(Duration(days: day)),
            sets: [
              for (var i = 0; i < 40; i++)
                RawWorkoutSet(
                  exerciseName:
                      'Ejercicio de fuerza con nombre bastante largo numero $i',
                  weightKg: 50 + i.toDouble(),
                  reps: 8,
                ),
            ],
          ),
      ];

      final context = await builder().build(sessionId: 's');

      // Con 14 sesiones x 15 resumenes cada una el JSON supera 15KB de sobra
      // -- debe haber recortado a <= 5 sesiones y <= 3 resumenes por sesion.
      expect(context.recentWorkouts.length, lessThanOrEqualTo(5));
      for (final workout in context.recentWorkouts) {
        expect(workout.exerciseSummaries.length, lessThanOrEqualTo(3));
      }
    },
  );
}
