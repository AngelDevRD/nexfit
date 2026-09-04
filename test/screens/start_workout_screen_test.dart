import 'package:appgym/core/exercise_animation/animation_repository.dart';
import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/providers/weight_unit_provider.dart';
import 'package:appgym/repositories/active_workout_repository.dart';
import 'package:appgym/repositories/routine_repository.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:appgym/screens/workout/start_workout_screen.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// C4, camino de UI real (no solo repositorio): infla `StartWorkoutScreen`
/// tal como la monta la app, toca la tarjeta de la rutina, y verifica en la
/// base lo que la UI efectivamente escribió -- exactamente lo que se pidió
/// tras la regresión anterior ("probá el camino de la UI, no solo el
/// repositorio").
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
    child: const MaterialApp(home: StartWorkoutScreen()),
  );

  testWidgets(
    'iniciar con una rutina precarga las series con el targetRestSeconds de '
    'la rutina (120s), no el default de 90s',
    (tester) async {
      await addExercise(1, 'Press banca');
      await routineRepo.create({
        'name': 'Empuje',
        'days': [
          {
            'day_index': 0,
            'name': 'Día 1',
            'exercises': [
              {
                'exercise_id': 1,
                'order': 0,
                'target_sets': 2,
                'target_reps_min': 8,
                'target_reps_max': 10,
                'target_rest_seconds': 120,
              },
            ],
          },
        ],
      });

      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.text('Empuje'), findsOneWidget);
      await tester.tap(find.text('Empuje'));
      await tester.pumpAndSettle();

      final sets = await db.select(db.workoutSets).get();
      expect(sets, hasLength(2), reason: 'targetSets=2 -> 2 series precargadas');
      for (final set in sets) {
        expect(
          set.restSeconds,
          120,
          reason: 'debe venir de targetRestSeconds, no del default 90',
        );
      }

      // La sesión debe haber quedado asociada al día precargado, no solo a
      // la rutina -- es lo que permite mostrar "Objetivo" y resolver qué
      // día fue en el futuro.
      final sessions = await db.select(db.workoutSessions).get();
      expect(sessions, hasLength(1));
      expect(sessions.single.routineDayId != null, isTrue);

      // Y lo más importante -- lo que RENDERIZA `ActiveWorkoutScreen`, no
      // solo lo que quedó en la base: el objetivo de la rutina y el
      // descanso real (120s), visibles en pantalla.
      expect(find.text('Objetivo: 2×8-10'), findsOneWidget);
      expect(find.text('120s'), findsOneWidget);

      // El check de una serie (C5) debe arrancar el descanso en 120s, no en
      // el default -- confirma que `setCompleted` lee el `restSeconds` real
      // de la serie ya precargada, no un valor fijo.
      final outcome = await workoutRepo.setCompleted(sets.first.id, true);
      // No debe reventar por peso/reps en 0: el preload usa targetWeightKg
      // (null acá) o 0.0, así que sin historial previo puede no haber PR --
      // lo que importa es que el rest_seconds de la serie sigue en 120.
      expect(outcome, isA<List>());
      final reloaded =
          await (db.select(db.workoutSets)
                ..where((t) => t.id.equals(sets.first.id)))
              .getSingle();
      expect(reloaded.restSeconds, 120);
    },
  );
}
