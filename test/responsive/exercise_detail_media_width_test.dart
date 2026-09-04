import 'package:appgym/core/exercise_animation/animation_repository.dart';
import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/providers/weight_unit_provider.dart';
import 'package:appgym/repositories/active_workout_repository.dart';
import 'package:appgym/repositories/exercise_repository.dart';
import 'package:appgym/repositories/routine_repository.dart';
import 'package:appgym/repositories/stats_repository.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:appgym/screens/exercises/exercise_detail_screen.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// Retoque post-A1: el bloque de medios (GIF) y el botón "Empezar
/// entrenamiento..." eran full-bleed -- en pantalla ancha quedaban
/// estirados (una caja de animación enorme casi vacía, una barra de botón
/// gigante), mismo problema que A5 ya había resuelto en la grilla de
/// métricas. El arreglo es el mismo criterio: `ConstrainedBox(maxWidth:
/// 560)` + `Center`. Estos tests verifican, a dos anchos (teléfono ~430dp y
/// pantalla ancha ~1200dp), que no hay overflow y que a 1200dp ninguno de
/// los dos bloques se estira más allá de 560dp.
void main() {
  late local.AppDatabase db;
  late WorkoutRepository workoutRepo;
  late ActiveWorkoutRepository activeRepo;
  late RoutineRepository routineRepo;
  late StatsRepository statsRepo;
  late ExerciseRepository exerciseRepo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    workoutRepo = WorkoutRepository(db);
    activeRepo = ActiveWorkoutRepository(db, workoutRepo);
    routineRepo = RoutineRepository(db);
    statsRepo = StatsRepository(db);
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
          muscleGroup: 'Pecho',
          difficulty: 'intermediate',
        ),
      );

  Widget wrapAt(Widget child, {required double width}) => MultiProvider(
    providers: [
      Provider<local.AppDatabase>.value(value: db),
      Provider<WorkoutRepository>.value(value: workoutRepo),
      Provider<ActiveWorkoutRepository>.value(value: activeRepo),
      Provider<RoutineRepository>.value(value: routineRepo),
      Provider<StatsRepository>.value(value: statsRepo),
      Provider<ExerciseRepository>.value(value: exerciseRepo),
      ChangeNotifierProvider<WeightUnitProvider>(
        create: (_) => WeightUnitProvider(),
      ),
      Provider<AnimationRepository>.value(
        value: AnimationRepository(providers: const []),
      ),
    ],
    child: MaterialApp(
      builder: (context, appChild) => MediaQuery(
        data: MediaQuery.of(context).copyWith(size: Size(width, 900)),
        child: SizedBox(width: width, height: 900, child: appChild),
      ),
      home: child,
    ),
  );

  for (final width in [430.0, 1200.0]) {
    testWidgets('detalle de ejercicio no desborda a ${width.toInt()}dp', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await addExercise(1, 'Press banca');

      await tester.pumpWidget(
        wrapAt(const ExerciseDetailScreen(exerciseId: 1), width: width),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException() == null, isTrue);
    });
  }

  testWidgets(
    'en pantalla ancha (1200dp) ni el bloque de medios ni el botón de '
    'empezar se estiran a todo el ancho',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await addExercise(1, 'Press banca');

      await tester.pumpWidget(
        wrapAt(const ExerciseDetailScreen(exerciseId: 1), width: 1200),
      );
      await tester.pumpAndSettle();

      final mediaBlock = find.byKey(const Key('exercise-detail-media-block'));
      final buttonBlock = find.byKey(
        const Key('exercise-detail-start-button-block'),
      );
      expect(mediaBlock, findsOneWidget);
      expect(buttonBlock, findsOneWidget);
      expect(tester.getSize(mediaBlock).width, lessThanOrEqualTo(560));
      expect(tester.getSize(buttonBlock).width, lessThanOrEqualTo(560));
    },
  );

  testWidgets('el nombre del ejercicio no se repite en el encabezado', (
    tester,
  ) async {
    await addExercise(1, 'Press banca');

    await tester.pumpWidget(
      wrapAt(const ExerciseDetailScreen(exerciseId: 1), width: 430),
    );
    await tester.pumpAndSettle();

    // Solo el título del AppBar -- ya no hay un segundo "Press banca" debajo
    // de la animación.
    expect(find.text('Press banca'), findsOneWidget);
  });
}
