import 'package:appgym/core/exercise_animation/animation_repository.dart';
import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/providers/weight_unit_provider.dart';
import 'package:appgym/repositories/active_workout_repository.dart';
import 'package:appgym/repositories/exercise_repository.dart';
import 'package:appgym/repositories/routine_repository.dart';
import 'package:appgym/repositories/stats_repository.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:appgym/screens/exercises/exercise_detail_screen.dart';
import 'package:appgym/screens/workout/active_workout_screen.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// U2: el detalle del ejercicio deja de ser pura enciclopedia y muestra el
/// historial del usuario (PR, última vez, evolución) más una acción directa
/// para arrancar un entrenamiento con ese ejercicio.
void main() {
  late local.AppDatabase db;
  late WorkoutRepository workoutRepo;
  late ActiveWorkoutRepository activeRepo;
  late StatsRepository statsRepo;
  late RoutineRepository routineRepo;
  late ExerciseRepository exerciseRepo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    workoutRepo = WorkoutRepository(db);
    activeRepo = ActiveWorkoutRepository(db, workoutRepo);
    statsRepo = StatsRepository(db);
    routineRepo = RoutineRepository(db);
    exerciseRepo = ExerciseRepository(db);
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

  Widget wrap(int exerciseId) => MultiProvider(
    providers: [
      Provider<local.AppDatabase>.value(value: db),
      Provider<WorkoutRepository>.value(value: workoutRepo),
      Provider<ActiveWorkoutRepository>.value(value: activeRepo),
      Provider<StatsRepository>.value(value: statsRepo),
      Provider<RoutineRepository>.value(value: routineRepo),
      Provider<ExerciseRepository>.value(value: exerciseRepo),
      ChangeNotifierProvider<WeightUnitProvider>(
        create: (_) => WeightUnitProvider(),
      ),
      Provider<AnimationRepository>.value(
        value: AnimationRepository(providers: const []),
      ),
    ],
    child: MaterialApp(home: ExerciseDetailScreen(exerciseId: exerciseId)),
  );

  testWidgets(
    'U2: sin historial previo, muestra el mensaje de "todavía no entrenaste" '
    'y el botón para empezar',
    (tester) async {
      await addExercise(1, 'Press banca');

      await tester.pumpWidget(wrap(1));
      await tester.pumpAndSettle();

      expect(
        find.text('Todavía no entrenaste este ejercicio.'),
        findsOneWidget,
      );
      expect(
        find.text('Empezar entrenamiento con este ejercicio'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'U2: con historial, muestra el PR vigente y la última vez entrenado '
    '(peso × reps por serie)',
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
      await workoutRepo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 2,
        'weight_kg': 80.0,
        'reps': 6,
      });
      await workoutRepo.finishSession(session.id, endedAt: DateTime(2026, 1, 1, 1));

      await tester.pumpWidget(wrap(1));
      await tester.pumpAndSettle();

      expect(find.textContaining('Récord de peso'), findsOneWidget);
      expect(find.textContaining('80.0 kg'), findsWidgets);
      expect(find.textContaining('Última vez'), findsOneWidget);
      expect(find.textContaining('80.0 kg × 8'), findsOneWidget);
      expect(find.textContaining('80.0 kg × 6'), findsOneWidget);
    },
  );

  testWidgets(
    'U2: tocar "Empezar entrenamiento con este ejercicio" sin sesión activa '
    'crea una y navega a ActiveWorkoutScreen con el ejercicio ya cargado',
    (tester) async {
      await addExercise(1, 'Press banca');

      await tester.pumpWidget(wrap(1));
      await tester.pumpAndSettle();

      await tester.tap(
        find.text('Empezar entrenamiento con este ejercicio'),
      );
      await tester.pumpAndSettle();

      expect(find.byType(ActiveWorkoutScreen), findsOneWidget);
      expect(find.text('Press banca'), findsWidgets);

      final sessionId = await activeRepo.currentSessionId();
      expect(sessionId != null, isTrue);
      final session = await workoutRepo.get(sessionId!);
      expect(session.sets.length, 1);
      expect(session.sets.first.exercise.id, 1);
    },
  );

  testWidgets(
    'A1: arranca en la pestaña "Resumen" y las 3 pestañas muestran su '
    'propio contenido al tocarlas',
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

      await tester.pumpWidget(wrap(1));
      await tester.pumpAndSettle();

      // Pestaña inicial: "Resumen" -- récord vigente visible, sin tocar
      // nada. `TabBarView` construye las 3 pestañas de una (no es lazy), así
      // que se verifica el contenido PROPIO de cada una al pasar por ella
      // en vez de la ausencia del resto (que sigue existiendo en el árbol,
      // solo no visible).
      expect(find.textContaining('Récord de peso'), findsOneWidget);

      await tester.tap(find.text('Historial'));
      await tester.pumpAndSettle();
      expect(find.text('01/01/2026'), findsOneWidget);

      await tester.tap(find.text('Guía'));
      await tester.pumpAndSettle();
      expect(find.text('Músculos trabajados'), findsOneWidget);
    },
  );
}
