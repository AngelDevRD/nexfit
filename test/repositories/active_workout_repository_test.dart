import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/repositories/active_workout_repository.dart';
import 'package:appgym/repositories/workout_repository.dart';
// `isNull`/`isNotNull` de drift (constructores de expresiones SQL) chocan con
// los matchers homónimos de `flutter_test`, que son los que usa este archivo.
import 'package:drift/drift.dart' hide isNotNull, isNull;
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

  Future<int> addExercise(int id, String name) => db
      .into(db.exercises)
      .insert(
        local.ExercisesCompanion.insert(
          id: Value(id),
          slug: name,
          name: name,
          muscleGroup: 'chest',
          difficulty: 'intermediate',
        ),
      );

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

    test(
      'A3: currentSessionId() da null y borra el draft si la sesión que '
      'referencia ya no existe (draft huérfano)',
      () async {
        final session = await repo.begin();
        // Simula una sesión borrada por fuera del repositorio (o una
        // instalación afectada por A1 antes de esta corrección) -- el draft
        // queda apuntando a un sessionId que ya no existe en la base.
        await (db.delete(
          db.workoutSessions,
        )..where((t) => t.id.equals(session.id))).go();

        expect(await repo.currentSessionId(), isNull);
        final draft = await db.select(db.activeWorkoutDrafts).getSingleOrNull();
        expect(draft, isNull, reason: 'el draft huérfano debe autolimpiarse');
      },
    );

    test(
      'A3: watchCurrentSessionId() también autolimpia un draft huérfano',
      () async {
        final session = await repo.begin();
        await (db.delete(
          db.workoutSessions,
        )..where((t) => t.id.equals(session.id))).go();

        expect(await repo.watchCurrentSessionId().first, isNull);
      },
    );

    test(
      'discard() borra la sesión, sus series y el draft -- sin tocar el '
      'historial (a diferencia de finish())',
      () async {
        await addExercise(1, 'Press banca');
        final session = await repo.begin();
        await workoutRepository.addSet(session.id, {
          'exercise_id': 1,
          'set_number': 1,
          'weight_kg': 40.0,
          'reps': 10,
        });

        await repo.discard(session.id);

        expect(await repo.currentSessionId(), isNull);
        final sessions = await db.select(db.workoutSessions).get();
        expect(sessions, isEmpty);
        final sets = await db.select(db.workoutSets).get();
        expect(
          sets,
          isEmpty,
          reason:
              'discard() borra las series a mano: el cascade declarado no se '
              'aplica sin PRAGMA foreign_keys = ON',
        );
      },
    );

    group('staleSessionId', () {
      test('sin draft, da null', () async {
        expect(await repo.staleSessionId(), isNull);
      });

      test('con un draft reciente (dentro del umbral), da null', () async {
        final session = await repo.begin();
        expect(
          await repo.staleSessionId(threshold: const Duration(hours: 6)),
          isNull,
          reason: 'recién empezada -- no es "vieja" para ningún umbral '
              'razonable',
        );
        expect(session.id, isNotNull);
      });

      test(
        'con un draft más viejo que el umbral, da el sessionId',
        () async {
          final started = DateTime.now().subtract(const Duration(hours: 10));
          final session = await workoutRepository.startSession(
            startedAt: started,
          );
          await db
              .into(db.activeWorkoutDrafts)
              .insert(
                local.ActiveWorkoutDraftsCompanion.insert(
                  id: const Value(1),
                  sessionId: session.id,
                  updatedAt: DateTime.now(),
                ),
              );

          expect(
            await repo.staleSessionId(threshold: const Duration(hours: 6)),
            session.id,
          );
          expect(
            await repo.staleSessionId(threshold: const Duration(hours: 12)),
            isNull,
            reason: 'con un umbral más largo, 10 horas ya no es "vieja"',
          );
        },
      );
    });
  });
}
