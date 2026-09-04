import 'package:appgym/core/exercise_animation/animation_repository.dart';
import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/providers/weight_unit_provider.dart';
import 'package:appgym/repositories/active_workout_repository.dart';
import 'package:appgym/repositories/routine_repository.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:appgym/screens/history/history_list_screen.dart';
import 'package:appgym/screens/workout/active_workout_screen.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// U3: historial sin filtros ni paginación -- cargaba TODO el historial de
/// una vez. Estos tests cubren la paginación ("Cargar más") y la nueva
/// acción "Repetir" (crea una sesión nueva con los mismos ejercicios).
void main() {
  late local.AppDatabase db;
  late WorkoutRepository workoutRepo;
  late ActiveWorkoutRepository activeRepo;
  late RoutineRepository routineRepo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    workoutRepo = WorkoutRepository(db);
    activeRepo = ActiveWorkoutRepository(db, workoutRepo);
    routineRepo = RoutineRepository(db);
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

  Widget wrap() => MultiProvider(
    providers: [
      Provider<local.AppDatabase>.value(value: db),
      Provider<WorkoutRepository>.value(value: workoutRepo),
      Provider<ActiveWorkoutRepository>.value(value: activeRepo),
      Provider<RoutineRepository>.value(value: routineRepo),
      ChangeNotifierProvider<WeightUnitProvider>(
        create: (_) => WeightUnitProvider(),
      ),
      Provider<AnimationRepository>.value(
        value: AnimationRepository(providers: const []),
      ),
    ],
    child: const MaterialApp(home: Scaffold(body: HistoryListScreen())),
  );

  testWidgets(
    'U3: con más de 20 sesiones muestra "Cargar más" y trae la página '
    'siguiente al tocarlo',
    (tester) async {
      await addExercise(1, 'Press banca');
      for (var i = 1; i <= 25; i++) {
        final session = await workoutRepo.startSession(
          startedAt: DateTime(2026, 1, i),
        );
        await workoutRepo.addSet(session.id, {
          'exercise_id': 1,
          'set_number': 1,
          'weight_kg': 50.0,
          'reps': 10,
        });
        await workoutRepo.finishSession(
          session.id,
          endedAt: DateTime(2026, 1, i, 1),
        );
      }

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      final list = find.byKey(const Key('history-session-list'));
      await tester.dragUntilVisible(
        find.text('Cargar más'),
        list,
        const Offset(0, -300),
      );
      expect(find.text('Cargar más'), findsOneWidget);
      // La sesión más vieja (día 1) es de la página 2 -- todavía no cargó.
      expect(find.text('01/01/2026'), findsNothing);

      await tester.tap(find.text('Cargar más'));
      await tester.pumpAndSettle();
      await tester.dragUntilVisible(
        find.text('01/01/2026'),
        list,
        const Offset(0, -300),
      );

      // Página 2 (las 5 restantes) ya cargó, y no hay más para pedir.
      expect(find.text('01/01/2026'), findsOneWidget);
      expect(find.text('Cargar más'), findsNothing);
    },
  );

  testWidgets(
    'U3: "Repetir" crea una sesión activa nueva con los mismos ejercicios y '
    'navega a ActiveWorkoutScreen',
    (tester) async {
      await addExercise(1, 'Press banca');
      final session = await workoutRepo.startSession(
        startedAt: DateTime(2026, 1, 1),
      );
      await workoutRepo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 80.0,
        'reps': 8,
      });
      await workoutRepo.finishSession(session.id, endedAt: DateTime(2026, 1, 1, 1));

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Repetir'));
      await tester.pumpAndSettle();

      expect(find.byType(ActiveWorkoutScreen), findsOneWidget);

      final newSessionId = await activeRepo.currentSessionId();
      expect(newSessionId != null, isTrue);
      expect(newSessionId, isNot(session.id));
      final newSession = await workoutRepo.get(newSessionId!);
      expect(newSession.sets.length, 1);
      expect(newSession.sets.first.exercise.id, 1);
      expect(newSession.sets.first.weightKg, 80.0);
      expect(newSession.sets.first.completed, isFalse);
    },
  );

  testWidgets(
    'REGRESIÓN: tocar el chip de un músculo con sesiones viejas detrás de '
    'muchas sesiones recientes de otro músculo no deja la lista vacía',
    (tester) async {
      // Los chips de la UI muestran las claves de `muscleGroupColors`
      // ("Pecho", "Espalda", tal cual) -- el muscleGroup guardado tiene que
      // coincidir con eso, no con un slug en inglés.
      await db
          .into(db.exercises)
          .insert(
            local.ExercisesCompanion.insert(
              id: const Value(1),
              slug: 'press-banca',
              name: 'Press banca',
              muscleGroup: 'Pecho',
              difficulty: 'intermediate',
            ),
          );
      await db
          .into(db.exercises)
          .insert(
            local.ExercisesCompanion.insert(
              id: const Value(2),
              slug: 'remo',
              name: 'Remo',
              muscleGroup: 'Espalda',
              difficulty: 'intermediate',
            ),
          );

      for (var i = 1; i <= 5; i++) {
        final session = await workoutRepo.startSession(
          startedAt: DateTime(2026, 1, i),
        );
        await workoutRepo.addSet(session.id, {
          'exercise_id': 1,
          'set_number': 1,
          'weight_kg': 50.0,
          'reps': 10,
        });
        await workoutRepo.finishSession(
          session.id,
          endedAt: DateTime(2026, 1, i, 1),
        );
      }
      for (var i = 1; i <= 20; i++) {
        final session = await workoutRepo.startSession(
          startedAt: DateTime(2026, 2, i),
        );
        await workoutRepo.addSet(session.id, {
          'exercise_id': 2,
          'set_number': 1,
          'weight_kg': 40.0,
          'reps': 10,
        });
        await workoutRepo.finishSession(
          session.id,
          endedAt: DateTime(2026, 2, i, 1),
        );
      }

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Pecho'));
      await tester.pumpAndSettle();

      expect(
        find.text('Sin entrenamientos registrados todavía.'),
        findsNothing,
      );
      await tester.dragUntilVisible(
        find.text('01/01/2026'),
        find.byKey(const Key('history-session-list')),
        const Offset(0, -300),
      );
      expect(find.text('01/01/2026'), findsOneWidget);
    },
  );

  testWidgets(
    'U3: "Repetir" avisa en vez de pisar el entrenamiento si ya hay uno '
    'activo',
    (tester) async {
      await addExercise(1, 'Press banca');
      final session = await workoutRepo.startSession(
        startedAt: DateTime(2026, 1, 1),
      );
      await workoutRepo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 80.0,
        'reps': 8,
      });
      await workoutRepo.finishSession(session.id, endedAt: DateTime(2026, 1, 1, 1));

      // Ya hay un entrenamiento en curso (otro ejercicio).
      await addExercise(2, 'Sentadilla');
      await activeRepo.begin();

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      await tester.tap(find.text('Repetir'));
      await tester.pumpAndSettle();

      expect(find.byType(ActiveWorkoutScreen), findsNothing);
      expect(
        find.textContaining('Ya tenés un entrenamiento en curso'),
        findsOneWidget,
      );
    },
  );
}
