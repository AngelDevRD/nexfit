import 'package:appgym/core/exercise_animation/animation_repository.dart';
import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/providers/weight_unit_provider.dart';
import 'package:appgym/repositories/active_workout_repository.dart';
import 'package:appgym/repositories/routine_repository.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:appgym/screens/workout/active_workout_screen.dart';
import 'package:appgym/widgets/stepper_field.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// T2 rompió lo que C2 arreglaba: el debounce de `_updateSetField` (500ms)
/// corría contra `setCompleted`, que lee weight/reps DE LA BASE -- si el
/// usuario tocaba el check antes de que el debounce escribiera, el récord se
/// evaluaba contra el valor viejo (o directamente se perdía la escritura si
/// la pantalla se cerraba antes). Estos tests reproducen la secuencia exacta
/// por el camino de UI (tap del stepper, no repositorio) con el reloj
/// controlado por `tester.pump`, nunca esperando los 500ms reales.
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

  Widget wrap(int sessionId) => MultiProvider(
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
    child: MaterialApp(home: ActiveWorkoutScreen(sessionId: sessionId)),
  );

  Finder kgStepperAddButton() => find.descendant(
    of: find.byType(StepperField).at(0),
    matching: find.byIcon(Icons.add),
  );

  testWidgets(
    'REGRESIÓN: tocar + varias veces y completar la serie ANTES de los '
    '500ms del debounce evalúa el récord con el valor FINAL y muestra el '
    'banner -- no el valor de antes de los toques',
    (tester) async {
      await addExercise(1, 'Press banca');
      final session = await workoutRepo.startSession();
      final outcome = await workoutRepo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 10.0,
        'reps': 8,
      });

      await tester.pumpWidget(wrap(session.id));
      await tester.pumpAndSettle();

      // 4 toques de +2.5kg: 10 -> 20. Cada `pump()` sin duración no deja
      // avanzar el reloj del debounce (sigue en 0ms).
      for (var i = 0; i < 4; i++) {
        await tester.tap(kgStepperAddButton());
        await tester.pump();
      }
      expect(find.text('20.0'), findsOneWidget);

      // Completar la serie ANTES de los 500ms -- acá es donde reventaba: el
      // repositorio leía weight_kg=10.0 (lo escrito al crear la serie), no
      // 20.0 (lo que se ve en pantalla).
      await tester.tap(find.byKey(ValueKey('set-check-${outcome.set.id}')));
      await tester.pump(); // procesa el tap (async, pero no el timer)
      await tester.pump(const Duration(milliseconds: 100));

      final records = await db.select(db.personalRecords).get();
      expect(records, hasLength(2), reason: 'max_weight + max_reps');
      final weight = records.firstWhere((r) => r.recordType == 'max_weight');
      expect(
        weight.value,
        20.0,
        reason: 'debe evaluar el valor final (20), no el de antes de los '
            'toques (10)',
      );

      final row =
          await (db.select(db.workoutSets)
                ..where((t) => t.id.equals(outcome.set.id)))
              .getSingle();
      expect(row.weightKg, 20.0);

      // El banner de "¡Récord Personal!" tiene que aparecer -- antes no
      // renderizaba nunca en este flujo porque `setCompleted` devolvía una
      // lista vacía (evaluaba contra 10kg, que no rompía nada).
      await tester.pump();
      expect(find.textContaining('Récord'), findsOneWidget);

      // Que no queden timers pendientes al terminar el test.
      await tester.pump(const Duration(milliseconds: 500));
    },
  );

  testWidgets(
    'REGRESIÓN: tocar + y finalizar dentro de los 500ms -- el valor final '
    'queda en la base, no el de antes del toque',
    (tester) async {
      await addExercise(1, 'Press banca');
      final session = await workoutRepo.startSession();
      final outcome = await workoutRepo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 10.0,
        'reps': 8,
      });
      // `_finish` navega con `pushReplacement`; el draft activo debe existir
      // para que `ActiveWorkoutRepository.finish` no falle.
      await db
          .into(db.activeWorkoutDrafts)
          .insert(
            local.ActiveWorkoutDraftsCompanion.insert(
              id: const Value(1),
              sessionId: session.id,
              updatedAt: DateTime.now(),
            ),
          );

      await tester.pumpWidget(wrap(session.id));
      await tester.pumpAndSettle();

      await tester.tap(kgStepperAddButton());
      await tester.pump();
      expect(find.text('12.5'), findsOneWidget);

      // "Finalizar" -> confirmar en el diálogo, todo dentro de los 500ms.
      await tester.tap(find.text('Finalizar'));
      await tester.pump();
      await tester.tap(find.text('Finalizar').last);
      await tester.pumpAndSettle();

      final row =
          await (db.select(db.workoutSets)
                ..where((t) => t.id.equals(outcome.set.id)))
              .getSingle();
      expect(row.weightKg, 12.5);
    },
  );

  testWidgets(
    'REGRESIÓN: tocar + y minimizar dentro de los 500ms -- el valor final '
    'queda en la base',
    (tester) async {
      await addExercise(1, 'Press banca');
      final session = await workoutRepo.startSession();
      final outcome = await workoutRepo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 10.0,
        'reps': 8,
      });

      // Stack con una ruta debajo para que "minimizar" (pop) tenga a dónde
      // volver -- igual que HomeShell en la app real.
      await tester.pumpWidget(
        MultiProvider(
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
          child: MaterialApp(
            home: Builder(
              builder: (context) => Scaffold(
                body: Center(
                  child: FilledButton(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) =>
                            ActiveWorkoutScreen(sessionId: session.id),
                      ),
                    ),
                    child: const Text('abrir'),
                  ),
                ),
              ),
            ),
          ),
        ),
      );
      await tester.tap(find.text('abrir'));
      await tester.pumpAndSettle();

      await tester.tap(kgStepperAddButton());
      await tester.pump();
      expect(find.text('12.5'), findsOneWidget);

      await tester.tap(find.byTooltip('Minimizar (seguir después)'));
      await tester.pumpAndSettle();

      final row =
          await (db.select(db.workoutSets)
                ..where((t) => t.id.equals(outcome.set.id)))
              .getSingle();
      expect(row.weightKg, 12.5);
    },
  );

  testWidgets(
    'FLUJO COMPLETO: agregar ejercicio -> ajustar con el stepper -> '
    'completar la serie -> finalizar -- verifica el resultado final de '
    'principio a fin. Los tres bugs de esta ronda (C1/C2, T2/C5, N-lo que '
    'sea) salieron de la interacción entre dos cambios correctos por '
    'separado, no de un ítem aislado -- este test corre después de CUALQUIER '
    'cambio a este flujo, de acá en adelante.',
    (tester) async {
      await addExercise(1, 'Press banca');
      final session = await activeRepo.begin(title: 'Entrenamiento libre');

      await tester.pumpWidget(wrap(session.id));
      await tester.pumpAndSettle();

      // 1) Agregar ejercicio -- abre el picker y elige el único disponible.
      await tester.tap(find.text('Agregar ejercicio'));
      await tester.pumpAndSettle();
      expect(find.text('Elegir ejercicio'), findsOneWidget);
      await tester.tap(find.text('Press banca'));
      await tester.pumpAndSettle();

      final sets = await db.select(db.workoutSets).get();
      expect(sets, hasLength(1), reason: 'una serie 0/0 recién agregada');
      final setId = sets.single.id;

      // 2) Ajustar con el stepper -- 8 toques de +2.5kg (0 -> 20) y 3 de
      // +1 rep (0 -> 3), todo dentro de la ventana del debounce.
      for (var i = 0; i < 8; i++) {
        await tester.tap(kgStepperAddButton());
        await tester.pump();
      }
      final repsStepperAdd = find.descendant(
        of: find.byType(StepperField).at(1),
        matching: find.byIcon(Icons.add),
      );
      for (var i = 0; i < 3; i++) {
        await tester.tap(repsStepperAdd);
        await tester.pump();
      }
      expect(find.text('20.0'), findsOneWidget);
      expect(find.text('3'), findsWidgets); // set 1, reps 3

      // 3) Completar la serie -- antes de que el debounce (500ms) escriba
      // por su cuenta.
      await tester.tap(find.byKey(ValueKey('set-check-$setId')));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 100));

      final completedRow =
          await (db.select(db.workoutSets)..where((t) => t.id.equals(setId)))
              .getSingle();
      expect(completedRow.weightKg, 20.0);
      expect(completedRow.reps, 3);
      expect(completedRow.completed, isTrue);

      final records = await db.select(db.personalRecords).get();
      expect(records, hasLength(2), reason: 'max_weight + max_reps, valor final');
      expect(
        records.firstWhere((r) => r.recordType == 'max_weight').value,
        20.0,
      );

      // Terminó de completar -> deja pasar el descanso persistido antes de
      // finalizar, para no dejar timers de UI colgando.
      await tester.pump(const Duration(milliseconds: 500));

      // 4) Finalizar -- confirmar en el diálogo.
      await tester.tap(find.text('Finalizar'));
      await tester.pump();
      await tester.tap(find.text('Finalizar').last);
      await tester.pumpAndSettle();

      // Terminó en el resumen del entrenamiento, no en una pantalla en
      // blanco ni con una excepción.
      expect(find.text('Resumen del entrenamiento'), findsOneWidget);

      final finishedSession =
          await (db.select(db.workoutSessions)
                ..where((t) => t.id.equals(session.id)))
              .getSingle();
      expect(finishedSession.endedAt != null, isTrue);

      // La red de seguridad de `finishSession` no debe haber tocado el
      // resultado ya correcto.
      final finalRecords = await db.select(db.personalRecords).get();
      expect(finalRecords, hasLength(2));
    },
  );

  testWidgets(
    'A2: la columna ANTERIOR muestra el peso × reps de ESA MISMA serie la '
    'última vez -- serie 1 contra serie 1, serie 2 contra serie 2, no un '
    'valor suelto',
    (tester) async {
      await addExercise(1, 'Press banca');

      // Sesión anterior terminada: serie 1 a 60kg×8, serie 2 a 65kg×6.
      final previous = await workoutRepo.startSession(
        startedAt: DateTime(2026, 1, 1),
      );
      await workoutRepo.addSet(previous.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 60.0,
        'reps': 8,
      });
      await workoutRepo.addSet(previous.id, {
        'exercise_id': 1,
        'set_number': 2,
        'weight_kg': 65.0,
        'reps': 6,
      });
      await workoutRepo.finishSession(
        previous.id,
        endedAt: DateTime(2026, 1, 1, 1),
      );

      // Sesión de hoy, en curso, con 2 series del mismo ejercicio (más una
      // 3ra que la vez pasada no existía).
      final session = await workoutRepo.startSession();
      await workoutRepo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 62.5,
        'reps': 8,
      });
      await workoutRepo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 2,
        'weight_kg': 65.0,
        'reps': 8,
      });
      await workoutRepo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 3,
        'weight_kg': 65.0,
        'reps': 5,
      });

      await tester.pumpWidget(wrap(session.id));
      await tester.pumpAndSettle();

      expect(find.text('ANTERIOR'), findsOneWidget);
      // Serie 1 contra serie 1, serie 2 contra serie 2.
      expect(find.text('60 kg × 8'), findsOneWidget);
      expect(find.text('65 kg × 6'), findsOneWidget);
      // Serie 3: no existía la vez pasada -> guion, no un valor inventado.
      expect(find.text('-'), findsOneWidget);
    },
  );

  testWidgets(
    'A4: "Reemplazar ejercicio" mueve las series existentes al ejercicio '
    'elegido -- no las pierde ni las deja huérfanas',
    (tester) async {
      await addExercise(1, 'Press banca');
      await addExercise(2, 'Sentadilla');

      final session = await workoutRepo.startSession();
      await workoutRepo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 80.0,
        'reps': 8,
      });
      await workoutRepo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 2,
        'weight_kg': 82.5,
        'reps': 6,
      });

      await tester.pumpWidget(wrap(session.id));
      await tester.pumpAndSettle();

      expect(find.text('Press banca'), findsOneWidget);

      await tester.tap(find.byTooltip('Más acciones del ejercicio'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Reemplazar ejercicio'));
      await tester.pumpAndSettle();

      expect(find.text('Elegir ejercicio'), findsOneWidget);
      await tester.tap(find.text('Sentadilla'));
      await tester.pumpAndSettle();

      // La tarjeta ahora es la del ejercicio nuevo, con las MISMAS 2 series.
      expect(find.text('Press banca'), findsNothing);
      expect(find.text('Sentadilla'), findsOneWidget);

      final sets = await db.select(db.workoutSets).get();
      expect(sets, hasLength(2), reason: 'no se pierden ni se duplican');
      expect(sets.every((s) => s.exerciseId == 2), isTrue);
      expect(
        sets.map((s) => s.weightKg).toSet(),
        {80.0, 82.5},
        reason: 'peso/reps de cada serie se conservan tal cual',
      );
    },
  );
}
