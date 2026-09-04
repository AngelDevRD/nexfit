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

  Future<int> addSession(DateTime startedAt, {DateTime? endedAt}) => db
      .into(db.workoutSessions)
      .insert(
        local.WorkoutSessionsCompanion.insert(
          startedAt: startedAt,
          endedAt: Value(endedAt),
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
      final session = await addSession(
        now,
        endedAt: now.add(const Duration(minutes: 45)),
      );
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

  test(
    'muscleAnalysis excluye sesiones sin terminar (T5)',
    () async {
      await addExercise(1, 'sentadilla', 'legs');
      final open = await addSession(DateTime.now()); // sin endedAt
      await addSet(open, 1, 100, 10);

      final entries = await repo.muscleAnalysis();
      final legs = entries.firstWhere((e) => e.muscleGroup == 'legs');
      expect(legs.totalVolume, 0.0);
      expect(legs.totalSets, 0);
    },
  );

  test(
    'muscleAnalysis excluye series placeholder en 0/0 (T5)',
    () async {
      await addExercise(1, 'sentadilla', 'legs');
      final now = DateTime.now();
      final session = await addSession(
        now,
        endedAt: now.add(const Duration(minutes: 30)),
      );
      await addSet(session, 1, 0, 0);
      await addSet(session, 1, 100, 10);

      final entries = await repo.muscleAnalysis();
      final legs = entries.firstWhere((e) => e.muscleGroup == 'legs');
      expect(legs.totalVolume, 1000.0);
      expect(legs.totalSets, 1);
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
    final s2 = await addSession(
      day2,
      endedAt: day2.add(const Duration(hours: 1)),
    );
    final s1 = await addSession(
      day1,
      endedAt: day1.add(const Duration(hours: 1)),
    );
    await addSet(s1, 1, 80, 5);
    await addSet(s2, 1, 90, 5);

    final progress = await repo.exerciseProgress(1);
    expect(progress, hasLength(2));
    expect(progress.first.date, day1);
    expect(progress.first.maxWeightKg, 80.0);
    expect(progress.last.maxWeightKg, 90.0);
  });

  test(
    'trainedLast7Days marca los días reales entrenados, no alturas fijas',
    () async {
      final today = DateTime.now();
      await addSession(today, endedAt: today.add(const Duration(hours: 1)));
      final twoAgo = today.subtract(const Duration(days: 2));
      await addSession(twoAgo, endedAt: twoAgo.add(const Duration(hours: 1)));
      final tenAgo = today.subtract(const Duration(days: 10));
      await addSession(
        tenAgo,
        endedAt: tenAgo.add(const Duration(hours: 1)),
      ); // fuera de rango

      final days = await repo.trainedLast7Days();
      expect(days, hasLength(7));
      expect(days.last, isTrue, reason: 'hoy (último elemento) entrenado');
      expect(days[4], isTrue, reason: 'hace 2 días entrenado');
      expect(days.where((d) => d).length, 2, reason: 'solo 2 de los 7 días');
    },
  );

  test(
    'U4: trainedLast7Days no cuenta una sesión sin terminar ni una borrada',
    () async {
      final today = DateTime.now();
      // Sin terminar (endedAt null, default de addSession).
      await addSession(today);
      // Borrada.
      final deletedId = await addSession(
        today,
        endedAt: today.add(const Duration(hours: 1)),
      );
      await (db.update(
        db.workoutSessions,
      )..where((t) => t.id.equals(deletedId))).write(
        const local.WorkoutSessionsCompanion(deleted: Value(true)),
      );

      final days = await repo.trainedLast7Days();
      expect(days.where((d) => d), isEmpty);
    },
  );

  test('streak cuenta días consecutivos y corta en el primer salto', () async {
    final today = DateTime.now();
    Future<void> addFinished(DateTime day) =>
        addSession(day, endedAt: day.add(const Duration(hours: 1)));
    await addFinished(today);
    await addFinished(today.subtract(const Duration(days: 1)));
    await addFinished(today.subtract(const Duration(days: 2)));
    // Salto: sin sesión el día -3, pero sí el -4 (no debe sumar a la racha actual).
    await addFinished(today.subtract(const Duration(days: 4)));

    final streak = await repo.streak();
    expect(streak.currentStreakDays, 3);
    expect(streak.longestStreakDays, 3);
  });

  test(
    'U4: streak no cuenta una sesión sin terminar ni una borrada -- antes '
    'empezar y abandonar un entrenamiento sumaba día de racha, y borrar una '
    'sesión no la sacaba',
    () async {
      final today = DateTime.now();
      final yesterday = today.subtract(const Duration(days: 1));

      // Ayer: sesión real, terminada -- SÍ cuenta.
      await addSession(yesterday, endedAt: yesterday.add(const Duration(hours: 1)));

      // Hoy: una sesión abandonada (sin terminar) y una borrada -- NINGUNA
      // debería extender la racha a 2.
      await addSession(today); // endedAt null
      final deletedTodayId = await addSession(
        today,
        endedAt: today.add(const Duration(hours: 1)),
      );
      await (db.update(
        db.workoutSessions,
      )..where((t) => t.id.equals(deletedTodayId))).write(
        const local.WorkoutSessionsCompanion(deleted: Value(true)),
      );

      final streak = await repo.streak();
      expect(streak.currentStreakDays, 1, reason: 'solo cuenta ayer');
      expect(
        streak.lastTrainedAt,
        DateTime(yesterday.year, yesterday.month, yesterday.day),
      );
    },
  );

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

  test(
    'deloadRecommendation recomienda descarga cuando el volumen reciente supera el baseline x1.3',
    () async {
      await addExercise(1, 'sentadilla', 'legs');
      // Baseline: semanas -4, -3, -2 con 1000kg de volumen cada una.
      for (final weeksAgo in [4, 3, 2]) {
        final start = DateTime.now().subtract(Duration(days: 7 * weeksAgo));
        final session = await addSession(
          start,
          endedAt: start.add(const Duration(hours: 1)),
        );
        await addSet(session, 1, 100, 10);
      }
      // Reciente: semanas -1 y actual con 2000kg de volumen cada una.
      for (final weeksAgo in [1, 0]) {
        final start = DateTime.now().subtract(Duration(days: 7 * weeksAgo));
        final session = await addSession(
          start,
          endedAt: start.add(const Duration(hours: 1)),
        );
        await addSet(session, 1, 200, 10);
      }

      final deload = await repo.deloadRecommendation();
      expect(deload.recommended, true);
    },
  );

  test(
    'deloadRecommendation no recomienda descarga sin historial de tonelaje',
    () async {
      final deload = await repo.deloadRecommendation();
      expect(deload.recommended, false);
    },
  );

  test(
    'upcomingRecordPredictions incluye solo ejercicios con historial suficiente',
    () async {
      await addExercise(1, 'press-banca', 'chest');
      await addExercise(2, 'sentadilla', 'legs');

      // Ejercicio 1: 3 PRs -> predicción válida.
      final start = DateTime.now().subtract(const Duration(days: 60));
      for (var i = 0; i < 3; i++) {
        await db
            .into(db.personalRecords)
            .insert(
              local.PersonalRecordsCompanion.insert(
                exerciseId: const Value(1),
                recordType: 'max_weight',
                value: 80.0 + i * 5,
                achievedAt: start.add(Duration(days: 30 * i)),
              ),
            );
      }
      // Ejercicio 2: 1 solo PR -> sin predicción.
      await db
          .into(db.personalRecords)
          .insert(
            local.PersonalRecordsCompanion.insert(
              exerciseId: const Value(2),
              recordType: 'max_weight',
              value: 100.0,
              achievedAt: DateTime.now(),
            ),
          );

      final predictions = await repo.upcomingRecordPredictions();
      expect(predictions, hasLength(1));
      expect(predictions.single.exerciseId, 1);
    },
  );

  test(
    'U2: currentRecordsFor toma el mayor valor de peso y de reps por '
    'separado, cada uno con su propia fecha',
    () async {
      await db
          .into(db.personalRecords)
          .insert(
            local.PersonalRecordsCompanion.insert(
              exerciseId: const Value(1),
              recordType: 'max_weight',
              value: 80.0,
              achievedAt: DateTime(2026, 1, 1),
            ),
          );
      await db
          .into(db.personalRecords)
          .insert(
            local.PersonalRecordsCompanion.insert(
              exerciseId: const Value(1),
              recordType: 'max_weight',
              value: 100.0,
              achievedAt: DateTime(2026, 2, 1),
            ),
          );
      await db
          .into(db.personalRecords)
          .insert(
            local.PersonalRecordsCompanion.insert(
              exerciseId: const Value(1),
              recordType: 'max_reps',
              value: 12.0,
              achievedAt: DateTime(2026, 1, 15),
            ),
          );

      final records = await repo.currentRecordsFor(1);

      expect(records.maxWeightKg, 100.0);
      expect(records.maxWeightAt, DateTime(2026, 2, 1));
      expect(records.maxReps, 12);
      expect(records.maxRepsAt, DateTime(2026, 1, 15));
    },
  );

  test(
    'U2: currentRecordsFor devuelve vacío si el ejercicio nunca tuvo récords',
    () async {
      final records = await repo.currentRecordsFor(999);
      expect(records.isEmpty, isTrue);
    },
  );
}
