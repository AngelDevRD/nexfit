// T-H2 -- Tests escritos por el SUPERVISOR (Opus) ANTES de la implementación.
// Hallazgo H2 de docs/AUDITORIA_2026-09-16_SUPERVISOR.md: borrar un ejercicio
// propio usado en una rutina (sin series registradas) está permitido; tras el
// sync `ExerciseSyncable` borra la fila local y `RoutineRepository.get` hace
// `.getSingle()` sobre el ejercicio -> StateError -> la rutina no abre y no se
// puede empezar un entrenamiento desde ella.
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'package:appgym/core/exercise_animation/animation_repository.dart';
import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/providers/weight_unit_provider.dart';
import 'package:appgym/repositories/active_workout_repository.dart';
import 'package:appgym/repositories/exercise_repository.dart';
import 'package:appgym/repositories/routine_repository.dart';
import 'package:appgym/repositories/stats_repository.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:appgym/screens/exercises/exercise_detail_screen.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late local.AppDatabase db;
  late ExerciseRepository exercises;
  late RoutineRepository routines;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    exercises = ExerciseRepository(db);
    routines = RoutineRepository(db);
    await db
        .into(db.exercises)
        .insert(
          local.ExercisesCompanion.insert(
            id: const Value(1),
            slug: 'press-banca',
            name: 'Press banca',
            muscleGroup: 'chest',
            difficulty: 'intermediate',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> createCustom(String name) => exercises.createExercise(
    name: name,
    muscleGroup: 'Core',
    equipment: const [],
    movementType: 'compound',
  );

  Future<int> createRoutineWith(String name, List<int> exerciseIds) =>
      routines.create({
        'name': name,
        'days': [
          {
            'day_index': 1,
            'name': 'Día 1',
            'exercises': [
              for (var i = 0; i < exerciseIds.length; i++)
                {'exercise_id': exerciseIds[i], 'order': i},
            ],
          },
        ],
      });

  group('ExerciseRepository', () {
    test('routinesUsing devuelve los nombres de las rutinas activas que lo usan', () async {
      final custom = await createCustom('Plancha lastrada');
      await createRoutineWith('Core A', [custom]);
      await createRoutineWith('Full body', [1, custom]);
      await createRoutineWith('Solo pecho', [1]);

      expect((await exercises.routinesUsing(custom))..sort(), [
        'Core A',
        'Full body',
      ]);
      expect(await exercises.routinesUsing(1), hasLength(2));
    });

    test('un ejercicio sin rutinas devuelve lista vacía', () async {
      final custom = await createCustom('Sin uso');
      expect(await exercises.routinesUsing(custom), isEmpty);
    });

    test(
      'no permite borrar un ejercicio propio usado por una rutina activa',
      () async {
        final custom = await createCustom('Plancha lastrada');
        await createRoutineWith('Core A', [custom]);

        await expectLater(
          exercises.deleteExercise(custom),
          throwsA(
            isA<StateError>().having(
              (e) => e.message,
              'message',
              contains('Core A'),
            ),
          ),
        );

        final row = await (db.select(
          db.exercises,
        )..where((t) => t.id.equals(custom))).getSingle();
        expect(row.deleted, isFalse, reason: 'no debe quedar marcado para borrar');
      },
    );

    test(
      'si la única rutina que lo usaba fue borrada, el ejercicio sí se puede borrar',
      () async {
        final custom = await createCustom('Plancha lastrada');
        final routineId = await createRoutineWith('Core A', [custom]);
        await routines.delete(routineId);

        expect(await exercises.routinesUsing(custom), isEmpty);
        await exercises.deleteExercise(custom);

        expect(() => exercises.get(custom), throwsStateError);
      },
    );

    test('sigue borrando normalmente un ejercicio propio sin series ni rutinas', () async {
      final custom = await createCustom('Descartable');
      await exercises.deleteExercise(custom);
      expect(() => exercises.get(custom), throwsStateError);
    });
  });

  group('RoutineRepository.get tolera ejercicios inexistentes', () {
    test(
      'si la fila del ejercicio ya no existe (borrado tras sync), la rutina abre sin ese ejercicio',
      () async {
        final custom = await createCustom('Plancha lastrada');
        final routineId = await createRoutineWith('Full body', [1, custom]);

        // Simula lo que hace ExerciseSyncable tras subir un borrado.
        await (db.delete(db.exercises)..where((t) => t.id.equals(custom))).go();

        final routine = await routines.get(routineId);
        expect(routine.name, 'Full body');
        expect(routine.days, hasLength(1));
        expect(
          routine.days.single.exercises.map((e) => e.exercise.id),
          [1],
        );
      },
    );

    test('list() sigue mostrando la rutina con los ejercicios que existen', () async {
      final custom = await createCustom('Plancha lastrada');
      await createRoutineWith('Full body', [1, custom]);
      await (db.delete(db.exercises)..where((t) => t.id.equals(custom))).go();

      final list = await routines.list();
      expect(list.single.exerciseNames, ['Press banca']);
    });
  });

  group('ExerciseDetailScreen', () {
    Widget wrap(int exerciseId) {
      final workoutRepo = WorkoutRepository(db);
      return MultiProvider(
        providers: [
          Provider<local.AppDatabase>.value(value: db),
          Provider<WorkoutRepository>.value(value: workoutRepo),
          Provider<ActiveWorkoutRepository>.value(
            value: ActiveWorkoutRepository(db, workoutRepo),
          ),
          Provider<StatsRepository>.value(value: StatsRepository(db)),
          Provider<RoutineRepository>.value(value: routines),
          Provider<ExerciseRepository>.value(value: exercises),
          ChangeNotifierProvider<WeightUnitProvider>(
            create: (_) => WeightUnitProvider(),
          ),
          Provider<AnimationRepository>.value(
            value: AnimationRepository(providers: const []),
          ),
        ],
        child: MaterialApp(home: ExerciseDetailScreen(exerciseId: exerciseId)),
      );
    }

    testWidgets(
      'al intentar borrar un ejercicio usado en rutinas explica cuáles y no lo borra',
      (tester) async {
        late int custom;
        await tester.runAsync(() async {
          custom = await createCustom('Plancha lastrada');
          await createRoutineWith('Core A', [custom]);
        });

        await tester.pumpWidget(wrap(custom));
        await tester.pumpAndSettle();

        await tester.tap(find.byTooltip('Eliminar ejercicio'));
        await tester.pumpAndSettle();

        expect(find.text('No se puede eliminar'), findsOneWidget);
        expect(find.textContaining('Core A'), findsOneWidget);
        expect(find.text('Eliminar ejercicio'), findsNothing,
            reason: 'no debe ofrecer la confirmación de borrado');

        await tester.tap(find.text('Entendido'));
        await tester.pumpAndSettle();

        final row = await tester.runAsync(
          () => (db.select(
            db.exercises,
          )..where((t) => t.id.equals(custom))).getSingle(),
        );
        expect(row!.deleted, isFalse);
      },
    );
  });
}
