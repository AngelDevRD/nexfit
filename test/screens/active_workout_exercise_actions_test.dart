// Tests escritos por el SUPERVISOR (Opus): acciones por ejercicio y descanso
// del entrenamiento activo, que estaban sin cubrir (la pantalla quedó en
// 71,4 % tras T-H3 y el gate de cobertura la rechazó). Verifican lo que
// queda en la BASE, no solo lo que se dibuja.
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'package:appgym/core/exercise_animation/animation_repository.dart';
import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/providers/weight_unit_provider.dart';
import 'package:appgym/repositories/active_workout_repository.dart';
import 'package:appgym/repositories/exercise_repository.dart';
import 'package:appgym/repositories/routine_repository.dart';
import 'package:appgym/repositories/stats_repository.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:appgym/screens/workout/active_workout_screen.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

void main() {
  late local.AppDatabase db;
  late WorkoutRepository workoutRepo;
  late ActiveWorkoutRepository activeRepo;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    workoutRepo = WorkoutRepository(db);
    activeRepo = ActiveWorkoutRepository(db, workoutRepo);
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> addExercise(int id, String name) => db
      .into(db.exercises)
      .insert(
        local.ExercisesCompanion.insert(
          id: Value(id),
          slug: 'slug-$id',
          name: name,
          muscleGroup: 'chest',
          difficulty: 'intermediate',
        ),
      );

  Widget wrap(int sessionId) => MultiProvider(
    providers: [
      Provider<local.AppDatabase>.value(value: db),
      Provider<WorkoutRepository>.value(value: workoutRepo),
      Provider<ActiveWorkoutRepository>.value(value: activeRepo),
      Provider<RoutineRepository>(create: (_) => RoutineRepository(db)),
      Provider<StatsRepository>(create: (_) => StatsRepository(db)),
      Provider<ExerciseRepository>(create: (_) => ExerciseRepository(db)),
      ChangeNotifierProvider<WeightUnitProvider>(
        create: (_) => WeightUnitProvider(),
      ),
      Provider<AnimationRepository>.value(
        value: AnimationRepository(providers: const []),
      ),
    ],
    child: MaterialApp(home: ActiveWorkoutScreen(sessionId: sessionId)),
  );

  /// Sesión activa con dos ejercicios (1 serie cada uno).
  Future<int> sessionWithTwoExercises() async {
    await addExercise(1, 'Press banca');
    await addExercise(2, 'Sentadilla');
    final session = await activeRepo.begin();
    for (final id in [1, 2]) {
      await workoutRepo.addSet(session.id, {
        'exercise_id': id,
        'set_number': 1,
        'weight_kg': 50.0,
        'reps': 10,
        'rest_seconds': 60,
      });
    }
    return session.id;
  }

  Future<List<local.WorkoutSet>> setsOf(int sessionId) => (db.select(
    db.workoutSets,
  )..where((t) => t.sessionId.equals(sessionId))).get();

  Future<void> openActionsForFirstExercise(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Más acciones del ejercicio').first);
    await tester.pumpAndSettle();
  }

  group('acciones por ejercicio', () {
    testWidgets('eliminar ejercicio borra sus series y deja el otro intacto', (
      tester,
    ) async {
      final sessionId = await sessionWithTwoExercises();

      await tester.pumpWidget(wrap(sessionId));
      await tester.pumpAndSettle();
      await openActionsForFirstExercise(tester);

      await tester.tap(find.text('Eliminar ejercicio'));
      await tester.pumpAndSettle();
      expect(find.textContaining('Press banca'), findsWidgets);
      await tester.tap(find.text('Eliminar'));
      await tester.pumpAndSettle();

      final remaining = await setsOf(sessionId);
      expect(remaining.map((s) => s.exerciseId), [2]);
      expect(find.text('Press banca'), findsNothing);
    });

    testWidgets('cancelar en eliminar no borra nada', (tester) async {
      final sessionId = await sessionWithTwoExercises();

      await tester.pumpWidget(wrap(sessionId));
      await tester.pumpAndSettle();
      await openActionsForFirstExercise(tester);
      await tester.tap(find.text('Eliminar ejercicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(await setsOf(sessionId), hasLength(2));
    });

    testWidgets(
      'reemplazar ejercicio mueve las series al ejercicio elegido conservando peso y reps',
      (tester) async {
        await addExercise(3, 'Remo con barra');
        final sessionId = await sessionWithTwoExercises();

        await tester.pumpWidget(wrap(sessionId));
        await tester.pumpAndSettle();
        await openActionsForFirstExercise(tester);
        await tester.tap(find.text('Reemplazar ejercicio'));
        await tester.pumpAndSettle();

        // Se abre el picker: elegir el ejercicio nuevo.
        await tester.tap(find.text('Remo con barra').first);
        await tester.pumpAndSettle();

        final sets = await setsOf(sessionId);
        expect(sets.map((s) => s.exerciseId).toSet(), {2, 3});
        final moved = sets.firstWhere((s) => s.exerciseId == 3);
        expect(moved.weightKg, 50.0);
        expect(moved.reps, 10);
      },
    );
  });
}
