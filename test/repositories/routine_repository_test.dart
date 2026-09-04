import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/repositories/routine_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// A6: la lista de rutinas no mostraba qué ejercicios tenía cada una, y no
/// existía forma de editar una rutina ya creada (solo borrar y rehacer).
void main() {
  late local.AppDatabase db;
  late RoutineRepository repository;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    repository = RoutineRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> addExercise(String slug, String name) => db
      .into(db.exercises)
      .insert(
        local.ExercisesCompanion.insert(
          slug: slug,
          name: name,
          muscleGroup: 'Pecho',
          difficulty: 'intermediate',
        ),
      );

  test(
    'A6: list() trae los nombres de ejercicios de cada rutina en una sola tanda de queries',
    () async {
      final benchId = await addExercise('press-banca', 'Press banca');
      final squatId = await addExercise('sentadilla', 'Sentadilla');

      await repository.create({
        'name': 'Full body',
        'days': [
          {
            'day_index': 1,
            'name': 'Día 1',
            'exercises': [
              {'exercise_id': benchId, 'order': 0},
              {'exercise_id': squatId, 'order': 1},
            ],
          },
        ],
      });

      final list = await repository.list();
      expect(list, hasLength(1));
      expect(list.first.exerciseNames, ['Press banca', 'Sentadilla']);
    },
  );

  test(
    'A6: update() modifica la rutina existente en vez de crear una duplicada -- la cantidad de rutinas no aumenta',
    () async {
      final benchId = await addExercise('press-banca', 'Press banca');
      final squatId = await addExercise('sentadilla', 'Sentadilla');

      final routineId = await repository.create({
        'name': 'Rutina original',
        'days': [
          {
            'day_index': 1,
            'name': 'Día 1',
            'exercises': [
              {'exercise_id': benchId, 'order': 0},
            ],
          },
        ],
      });

      final beforeCount = (await repository.list()).length;

      await repository.update(routineId, {
        'name': 'Rutina renombrada',
        'days': [
          {
            'day_index': 1,
            'name': 'Día 1',
            'exercises': [
              {'exercise_id': squatId, 'order': 0},
            ],
          },
        ],
      });

      final afterList = await repository.list();
      expect(afterList.length, beforeCount);
      expect(afterList.first.id, routineId);
      expect(afterList.first.name, 'Rutina renombrada');
      expect(afterList.first.exerciseNames, ['Sentadilla']);

      final full = await repository.get(routineId);
      expect(full.days, hasLength(1));
      expect(full.days.first.exercises, hasLength(1));
      expect(full.days.first.exercises.first.exercise.name, 'Sentadilla');
    },
  );
}
