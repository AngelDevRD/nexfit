import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/repositories/recovery_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late local.AppDatabase db;
  late RecoveryRepository repo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    repo = RecoveryRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> addExercise() => db
      .into(db.exercises)
      .insert(
        local.ExercisesCompanion.insert(
          id: const Value(1),
          slug: 'squat',
          name: 'Sentadilla',
          muscleGroup: 'legs',
          difficulty: 'intermediate',
        ),
      );

  Future<void> addSession(DateTime startedAt, double weightKg, int reps) async {
    final sessionId = await db
        .into(db.workoutSessions)
        .insert(
          local.WorkoutSessionsCompanion.insert(
            startedAt: startedAt,
            updatedAt: startedAt,
          ),
        );
    await db
        .into(db.workoutSets)
        .insert(
          local.WorkoutSetsCompanion.insert(
            sessionId: sessionId,
            exerciseId: 1,
            setNumber: 1,
            weightKg: Value(weightKg),
            reps: Value(reps),
          ),
        );
  }

  test(
    'sin ningún entrenamiento previo, el factor de carga es neutro (100)',
    () async {
      await repo.upsertCheckIn(DateTime.now(), 8, 5);

      final index = await repo.index();

      // sleepScore=100, fatigueScore=50, loadScore=100 (sin historial)
      // -> round(0.4*100 + 0.3*50 + 0.3*100) = round(40+15+30) = 85
      expect(index!.recoveryIndex, 85);
      expect(index.level, 'recovered');
    },
  );

  test(
    'una semana con el doble de tonelaje que el promedio anterior baja el factor de carga a 0',
    () async {
      await addExercise();
      final now = DateTime.now();

      // 4 semanas previas con 1000kg de tonelaje cada una (100kg x 10 reps).
      for (var i = 1; i <= 4; i++) {
        await addSession(now.subtract(Duration(days: 7 * i)), 100, 10);
      }
      // Semana actual: el doble (200kg x 10 reps = 2000kg).
      await addSession(now, 200, 10);

      await repo.upsertCheckIn(now, 8, 5);
      final index = await repo.index();

      // overloadRatio = 2000/1000 = 2 -> overshoot = 1 -> loadScore = 0
      // round(0.4*100 + 0.3*50 + 0.3*0) = round(40+15+0) = 55
      expect(index!.recoveryIndex, 55);
      expect(index.level, 'medium');
    },
  );

  test('sin check-ins todavía, index() devuelve null', () async {
    expect(await repo.index(), null);
  });
}
