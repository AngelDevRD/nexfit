import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/repositories/active_workout_repository.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late local.AppDatabase db;
  late WorkoutRepository workoutRepository;
  late ActiveWorkoutRepository repo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    workoutRepository = WorkoutRepository(db);
    repo = ActiveWorkoutRepository(db, workoutRepository);
  });

  tearDown(() async {
    await db.close();
  });

  group('remainingRest', () {
    test('descuenta contra "now", nunca acumula ticks', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final endsAt = now.add(const Duration(seconds: 90));
      expect(
        remainingRest(endsAt, now.add(const Duration(seconds: 30))),
        const Duration(seconds: 60),
      );
    });

    test('nunca da negativo aunque "now" pase el instante de fin', () {
      final now = DateTime(2026, 1, 1, 12, 0, 0);
      final endsAt = now.subtract(const Duration(seconds: 5));
      expect(remainingRest(endsAt, now), Duration.zero);
    });
  });

  group('ActiveWorkoutRepository', () {
    test('sin sesión activa, currentSessionId da null', () async {
      expect(await repo.currentSessionId(), isNull);
    });

    test('begin() crea la sesión y el draft', () async {
      final session = await repo.begin();
      expect(await repo.currentSessionId(), session.id);
    });

    test('begin() falla si ya hay una sesión activa', () async {
      await repo.begin();
      expect(() => repo.begin(), throwsStateError);
    });

    test('updateProgress persiste el fin del descanso', () async {
      await repo.begin();
      // Drift persiste DateTime con precisión de segundos (sqlite) -- se
      // trunca antes de comparar para no depender de esa precisión.
      final endsAt = DateTime.now().add(const Duration(minutes: 2));
      final truncated = DateTime.fromMillisecondsSinceEpoch(
        endsAt.millisecondsSinceEpoch ~/ 1000 * 1000,
      );
      await repo.updateProgress(
        currentExerciseId: 5,
        currentSetNumber: 3,
        restEndsAt: endsAt,
      );
      expect(await repo.restEndsAt(), truncated);
    });

    test('updateProgress con clearRest borra el descanso persistido', () async {
      await repo.begin();
      await repo.updateProgress(
        restEndsAt: DateTime.now().add(const Duration(minutes: 2)),
      );
      await repo.updateProgress(clearRest: true);
      expect(await repo.restEndsAt(), isNull);
    });

    test('finish() cierra la sesión y borra el draft', () async {
      final session = await repo.begin();
      await repo.finish(session.id);
      expect(await repo.currentSessionId(), isNull);
      final closed = await workoutRepository.get(session.id);
      expect(closed.endedAt, isNotNull);
    });

    test(
      'tras finish(), begin() puede arrancar una sesión nueva sin chocar',
      () async {
        final first = await repo.begin();
        await repo.finish(first.id);
        final second = await repo.begin();
        expect(second.id, isNot(first.id));
        expect(await repo.currentSessionId(), second.id);
      },
    );
  });
}
