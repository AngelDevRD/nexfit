import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/models/exercise.dart';
import 'package:appgym/models/workout.dart';
import 'package:appgym/providers/weight_unit_provider.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:appgym/screens/workout/workout_summary_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A5: `GridView.count(childAspectRatio: ...)` hacía que la altura de la
/// tarjeta creciera con el ancho de la ventana -- en pantalla ancha las
/// tarjetas de métrica se veían enormes. El arreglo usa
/// `SliverGridDelegateWithFixedCrossAxisCount(mainAxisExtent: ...)` (alto
/// fijo por contenido) + `ConstrainedBox(maxWidth: 560)` para no estirar la
/// grilla. Estos tests verifican, a dos anchos (teléfono ~430dp y pantalla
/// ancha ~1200dp), que no hay overflow y que a 1200dp la grilla NO ocupa
/// todo el ancho disponible (prueba de que dejó de estirarse).
void main() {
  late local.AppDatabase db;
  late WorkoutRepository workoutRepo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    workoutRepo = WorkoutRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrapAt(Widget child, {required double width}) => MultiProvider(
    providers: [
      Provider<local.AppDatabase>.value(value: db),
      Provider<WorkoutRepository>.value(value: workoutRepo),
      ChangeNotifierProvider<WeightUnitProvider>(
        create: (_) => WeightUnitProvider(),
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

  final session = WorkoutSession(
    id: 1,
    startedAt: DateTime(2026, 1, 1, 10),
    endedAt: DateTime(2026, 1, 1, 11),
    sets: [
      WorkoutSet(
        id: 1,
        setNumber: 1,
        weightKg: 80,
        reps: 8,
        techniques: const [],
        isWarmup: false,
        exercise: ExerciseSummary(
          id: 1,
          slug: 'press-banca',
          name: 'Press banca',
          muscleGroup: 'Pecho',
          difficulty: 'intermediate',
        ),
      ),
    ],
  );

  for (final width in [430.0, 1200.0]) {
    testWidgets(
      'A5: resumen del entrenamiento no desborda a ${width.toInt()}dp',
      (tester) async {
        tester.view.physicalSize = Size(width, 900);
        tester.view.devicePixelRatio = 1;
        addTearDown(tester.view.resetPhysicalSize);
        addTearDown(tester.view.resetDevicePixelRatio);

        await tester.pumpWidget(
          wrapAt(
            WorkoutSummaryScreen(session: session, records: const []),
            width: width,
          ),
        );
        await tester.pumpAndSettle();

        expect(tester.takeException(), isNull);
      },
    );
  }

  testWidgets(
    'A5: en pantalla ancha (1200dp) la grilla de métricas no se estira a todo el ancho',
    (tester) async {
      tester.view.physicalSize = const Size(1200, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        wrapAt(
          WorkoutSummaryScreen(session: session, records: const []),
          width: 1200,
        ),
      );
      await tester.pumpAndSettle();

      final gridFinder = find.byType(GridView);
      expect(gridFinder, findsWidgets);
      final gridSize = tester.getSize(gridFinder.first);
      // El ConstrainedBox limita el ancho a 560 -- muy por debajo de los
      // 1200dp disponibles, prueba de que la grilla dejó de estirarse.
      expect(gridSize.width, lessThanOrEqualTo(560));
    },
  );
}
