import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/repositories/stats_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late local.AppDatabase db;
  late StatsRepository repo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    repo = StatsRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> addExercise(
    int id,
    String slug,
    String muscleGroup, {
    String difficulty = 'intermediate',
  }) => db
      .into(db.exercises)
      .insert(
        local.ExercisesCompanion.insert(
          id: Value(id),
          slug: slug,
          name: slug,
          muscleGroup: muscleGroup,
          difficulty: difficulty,
        ),
      );

  Future<int> addSession(DateTime startedAt) => db
      .into(db.workoutSessions)
      .insert(
        local.WorkoutSessionsCompanion.insert(
          startedAt: startedAt,
          updatedAt: startedAt,
        ),
      );

  Future<void> addSet(
    int sessionId,
    int exerciseId,
    double weightKg,
    int reps,
  ) => db
      .into(db.workoutSets)
      .insert(
        local.WorkoutSetsCompanion.insert(
          sessionId: sessionId,
          exerciseId: exerciseId,
          setNumber: 1,
          weightKg: Value(weightKg),
          reps: Value(reps),
        ),
      );

  test(
    'muscleAnalysis clasifica el nivel de volumen entre grupos musculares',
    () async {
      await addExercise(1, 'sentadilla', 'legs');
      await addExercise(2, 'press-banca', 'chest');
      await addExercise(3, 'curl-biceps', 'arms');
      final now = DateTime.now();
      final session = await addSession(now);
      // legs: 1500 (mayor a todo) -- chest: 1000 (medio) -- arms: 100 (menor a todo).
      await addSet(session, 1, 150, 10);
      await addSet(session, 2, 100, 10);
      await addSet(session, 3, 10, 10);

      final entries = await repo.muscleAnalysis();
      final legs = entries.firstWhere((e) => e.muscleGroup == 'legs');
      final chest = entries.firstWhere((e) => e.muscleGroup == 'chest');
      final arms = entries.firstWhere((e) => e.muscleGroup == 'arms');

      expect(legs.totalVolume, 1500.0);
      expect(legs.level, 'alto');
      expect(chest.totalVolume, 1000.0);
      expect(chest.level, 'medio');
      expect(arms.totalVolume, 100.0);
      expect(arms.level, 'bajo');
    },
  );

  test('exerciseProgress ordena por fecha y calcula máximos/volumen', () async {
    await addExercise(1, 'sentadilla', 'legs');
    // Drift almacena DateTime con resolución de segundos -- se trunca acá
    // para comparar contra lo que vuelve a leerse de la base.
    DateTime truncate(DateTime d) => DateTime.fromMillisecondsSinceEpoch(
      1000 * (d.millisecondsSinceEpoch ~/ 1000),
    );
    final day1 = truncate(DateTime.now().subtract(const Duration(days: 2)));
    final day2 = truncate(DateTime.now().subtract(const Duration(days: 1)));
    final s2 = await addSession(day2);
    final s1 = await addSession(day1);
    await addSet(s1, 1, 80, 5);
    await addSet(s2, 1, 90, 5);

    final progress = await repo.exerciseProgress(1);
    expect(progress, hasLength(2));
    expect(progress.first.date, day1);
    expect(progress.first.maxWeightKg, 80.0);
    expect(progress.last.maxWeightKg, 90.0);
  });

  test('streak cuenta días consecutivos y corta en el primer salto', () async {
    final today = DateTime.now();
    await addSession(today);
    await addSession(today.subtract(const Duration(days: 1)));
    await addSession(today.subtract(const Duration(days: 2)));
    // Salto: sin sesión el día -3, pero sí el -4 (no debe sumar a la racha actual).
    await addSession(today.subtract(const Duration(days: 4)));

    final streak = await repo.streak();
    expect(streak.currentStreakDays, 3);
    expect(streak.longestStreakDays, 3);
  });

  test(
    'strengthStandards compara el mejor PR contra el peso corporal',
    () async {
      await addExercise(1, 'press-banca-barra', 'chest');
      await db
          .into(db.profiles)
          .insert(
            local.ProfilesCompanion.insert(
              id: 'user-1',
              updatedAt: DateTime.now(),
              weightKg: const Value(80.0),
              sex: const Value('male'),
            ),
          );
      await db
          .into(db.personalRecords)
          .insert(
            local.PersonalRecordsCompanion.insert(
              exerciseId: const Value(1),
              recordType: 'max_weight',
              value: 100.0, // ratio 1.25x -> banda "intermediate" (umbral 1.0)
              achievedAt: DateTime.now(),
            ),
          );

      final standard = await repo.strengthStandards(1);
      expect(standard, isNot(null));
      expect(standard!.ratio, 1.25);
      expect(standard.level, 'intermediate');
    },
  );

  test(
    'recordPrediction exige al menos 3 puntos y proyecta con regresión lineal',
    () async {
      await addExercise(1, 'press-banca', 'chest');
      final start = DateTime.now().subtract(const Duration(days: 60));
      for (var i = 0; i < 3; i++) {
        await db
            .into(db.personalRecords)
            .insert(
              local.PersonalRecordsCompanion.insert(
                exerciseId: const Value(1),
                recordType: 'max_weight',
                value: 80.0 + i * 5, // +5kg cada 30 días
                achievedAt: start.add(Duration(days: 30 * i)),
              ),
            );
      }

      final prediction = await repo.recordPrediction(1, weeksAhead: 4);
      expect(prediction, isNot(null));
      expect(prediction!.dataPoints, 3);
      expect(prediction.currentBestKg, 90.0);
      expect(prediction.predictedKg, greaterThan(90.0));
    },
  );

  test('recordPrediction devuelve null con menos de 3 registros', () async {
    await addExercise(1, 'press-banca', 'chest');
    await db
        .into(db.personalRecords)
        .insert(
          local.PersonalRecordsCompanion.insert(
            exerciseId: const Value(1),
            recordType: 'max_weight',
            value: 80.0,
            achievedAt: DateTime.now(),
          ),
        );

    expect(await repo.recordPrediction(1), null);
  });
}
