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

/// D4: la app asume ancho de teléfono en casi todas partes (solo 2 archivos
/// usan `LayoutBuilder`/`MediaQuery.sizeOf` en todo `lib/`). Estos tests
/// pintan las dos pantallas más densas de la app -- la tabla de series del
/// entrenamiento activo (kg/reps/RPE lado a lado) y el detalle de ejercicio
/// con el historial fusionado (U2) -- en el ancho mínimo razonable (320dp,
/// el iPhone SE de 1a gen / Galaxy Fold cerrado) y con el texto escalado al
/// 200%, y fallan si Flutter reporta un overflow de layout (`RenderFlex
/// overflowed`) en cualquiera de los dos casos.
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

  Widget wrapAt(
    Widget child, {
    required Size size,
    required double textScale,
  }) => MultiProvider(
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
        data: MediaQuery.of(
          context,
        ).copyWith(size: size, textScaler: TextScaler.linear(textScale)),
        child: appChild!,
      ),
      home: child,
    ),
  );

  testWidgets(
    'D4: entrenamiento activo (tabla kg/reps/RPE) no desborda a 320dp de '
    'ancho con texto al 200%',
    (tester) async {
      tester.view.physicalSize = const Size(320, 640);
      tester.view.devicePixelRatio = 1.0;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await addExercise(1, 'Press banca');
      final session = await workoutRepo.startSession();
      await workoutRepo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 80.0,
        'reps': 8,
        'rpe': 8.5,
      });

      await tester.pumpWidget(
        wrapAt(
          ActiveWorkoutScreen(sessionId: session.id),
          size: const Size(320, 640),
          textScale: 2.0,
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException() == null, isTrue);
    },
  );

  // A1 dejaba el encabezado (animación + nombre + pills + botón "Empezar
  // entrenamiento...") FIJO arriba de las pestañas, compitiendo por alto con
  // el contenido de la pestaña activa -- a 320×640 (más bajo que un iPhone
  // SE, 320×568, así que el caso real es TODAVÍA más chico) con texto al
  // 200% ni el encabezado solo entraba. El fix real: `NestedScrollView` con
  // el encabezado como sliver que scrollea y solo `PillTabBar` fijo
  // (`SliverPersistentHeader(pinned: true)`) -- deja de competir por alto
  // sin importar cuánto crezca el texto. Se prueba a las dos alturas: 640
  // (el valor histórico de este archivo) y 568 (iPhone SE real).
  for (final height in [640.0, 568.0]) {
    testWidgets(
      'D4: detalle de ejercicio (PR + última vez + gráfico, U2) no desborda '
      'a 320×${height.toInt()} con texto al 200%',
      (tester) async {
        tester.view.physicalSize = Size(320, height);
        tester.view.devicePixelRatio = 1.0;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await addExercise(1, 'Press banca');
        final s1 = await workoutRepo.startSession(
          startedAt: DateTime(2026, 1, 1),
        );
        await workoutRepo.addSet(s1.id, {
          'exercise_id': 1,
          'set_number': 1,
          'weight_kg': 80.0,
          'reps': 8,
        });
        await workoutRepo.finishSession(
          s1.id,
          endedAt: DateTime(2026, 1, 1, 1),
        );
        final s2 = await workoutRepo.startSession(
          startedAt: DateTime(2026, 1, 8),
        );
        await workoutRepo.addSet(s2.id, {
          'exercise_id': 1,
          'set_number': 1,
          'weight_kg': 82.5,
          'reps': 8,
        });
        await workoutRepo.finishSession(
          s2.id,
          endedAt: DateTime(2026, 1, 8, 1),
        );

        await tester.pumpWidget(
          wrapAt(
            const ExerciseDetailScreen(exerciseId: 1),
            size: Size(320, height),
            textScale: 2.0,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException() == null, isTrue);
      },
    );
  }
}
