import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/repositories/exercise_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late local.AppDatabase db;
  late ExerciseRepository repo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    repo = ExerciseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> seedCatalogExercise(int id) => db
      .into(db.exercises)
      .insert(
        local.ExercisesCompanion.insert(
          id: Value(id),
          slug: 'catalog-$id',
          name: 'Ejercicio de catálogo $id',
          muscleGroup: 'Pecho',
          difficulty: 'beginner',
        ),
      );

  group('createExercise (E1)', () {
    test('asigna id desde customExerciseIdStart y slug custom-<id>', () async {
      final id = await repo.createExercise(
        name: 'Curl concentrado',
        muscleGroup: 'Bíceps',
        equipment: ['mancuerna'],
        movementType: 'isolation',
      );

      expect(id, customExerciseIdStart);
      final exercise = await repo.get(id);
      expect(exercise.slug, 'custom-$id');
      expect(exercise.name, 'Curl concentrado');
      expect(exercise.muscleGroup, 'Bíceps');
      expect(exercise.equipment, ['mancuerna']);
      expect(exercise.movementType, 'isolation');
      expect(exercise.instructions, isEmpty);
      expect(ExerciseRepository.isCustomExercise(id), isTrue);
    });

    test('no choca con ids del catálogo semilla', () async {
      await seedCatalogExercise(1);
      await seedCatalogExercise(2);

      final id = await repo.createExercise(
        name: 'Nuevo',
        muscleGroup: 'Core',
        equipment: const [],
        movementType: 'compound',
      );

      expect(id, customExerciseIdStart);
    });

    test('ids sucesivos no se repiten', () async {
      final firstId = await repo.createExercise(
        name: 'Uno',
        muscleGroup: 'Core',
        equipment: const [],
        movementType: 'compound',
      );
      final secondId = await repo.createExercise(
        name: 'Dos',
        muscleGroup: 'Core',
        equipment: const [],
        movementType: 'compound',
      );

      expect(secondId, firstId + 1);
    });
  });

  group('updateExercise (E1)', () {
    test('actualiza nombre, grupo, equipo y tipo de un ejercicio propio', () async {
      final id = await repo.createExercise(
        name: 'Original',
        muscleGroup: 'Core',
        equipment: const [],
        movementType: 'compound',
      );

      await repo.updateExercise(
        id,
        name: 'Editado',
        muscleGroup: 'Espalda',
        equipment: ['banco'],
        movementType: 'isolation',
      );

      final exercise = await repo.get(id);
      expect(exercise.name, 'Editado');
      expect(exercise.muscleGroup, 'Espalda');
      expect(exercise.equipment, ['banco']);
      expect(exercise.movementType, 'isolation');
    });

    test('rechaza editar un ejercicio del catálogo semilla', () async {
      await seedCatalogExercise(5);

      expect(
        () => repo.updateExercise(
          5,
          name: 'Hackeado',
          muscleGroup: 'Core',
          equipment: const [],
          movementType: 'compound',
        ),
        throwsArgumentError,
      );
    });
  });

  group('deleteExercise / hasLoggedSets (E1)', () {
    test('elimina un ejercicio propio sin series registradas', () async {
      final id = await repo.createExercise(
        name: 'Descartable',
        muscleGroup: 'Core',
        equipment: const [],
        movementType: 'compound',
      );

      expect(await repo.hasLoggedSets(id), isFalse);
      await repo.deleteExercise(id);

      expect(() => repo.get(id), throwsStateError);
    });

    test(
      'no borra un ejercicio propio con series registradas -- protege el historial',
      () async {
        final id = await repo.createExercise(
          name: 'Con historial',
          muscleGroup: 'Core',
          equipment: const [],
          movementType: 'compound',
        );
        final session = await db
            .into(db.workoutSessions)
            .insertReturning(
              local.WorkoutSessionsCompanion.insert(
                startedAt: DateTime.now(),
                updatedAt: DateTime.now(),
              ),
            );
        await db
            .into(db.workoutSets)
            .insert(
              local.WorkoutSetsCompanion.insert(
                sessionId: session.id,
                exerciseId: id,
                setNumber: 1,
              ),
            );

        expect(await repo.hasLoggedSets(id), isTrue);
        expect(() => repo.deleteExercise(id), throwsStateError);

        // el ejercicio y su serie siguen intactos
        final exercise = await repo.get(id);
        expect(exercise.name, 'Con historial');
      },
    );

    test('rechaza eliminar un ejercicio del catálogo semilla', () async {
      await seedCatalogExercise(7);

      expect(() => repo.deleteExercise(7), throwsArgumentError);
    });
  });
}
