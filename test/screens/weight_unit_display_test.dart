import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/providers/weight_unit_provider.dart';
import 'package:appgym/repositories/stats_repository.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:appgym/screens/history/history_list_screen.dart';
import 'package:appgym/screens/stats/muscle_analysis_tab.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// U1: la unidad de peso elegida en Ajustes tiene que reflejarse en TODA la
/// app, no solo en el entrenamiento activo. Antes de este arreglo, historial
/// y estadísticas seguían mostrando "kg" fijo aunque el usuario hubiera
/// elegido "lb". Este test cambia la unidad a lb y verifica que ninguna de
/// las dos pantallas siga mostrando kg.
void main() {
  late local.AppDatabase db;
  late WorkoutRepository workoutRepo;
  late StatsRepository statsRepo;
  late WeightUnitProvider unitProvider;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    workoutRepo = WorkoutRepository(db);
    statsRepo = StatsRepository(db);
    unitProvider = WeightUnitProvider();
    await unitProvider.setUnit(WeightUnit.lb);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> addExercise(int id, String muscleGroup) => db
      .into(db.exercises)
      .insert(
        local.ExercisesCompanion.insert(
          id: Value(id),
          slug: 'ejercicio-$id',
          name: 'Ejercicio $id',
          muscleGroup: muscleGroup,
          difficulty: 'intermediate',
        ),
      );

  Widget wrap(Widget child) => MultiProvider(
    providers: [
      Provider<local.AppDatabase>.value(value: db),
      Provider<WorkoutRepository>.value(value: workoutRepo),
      Provider<StatsRepository>.value(value: statsRepo),
      ChangeNotifierProvider<WeightUnitProvider>.value(value: unitProvider),
    ],
    child: MaterialApp(home: Scaffold(body: child)),
  );

  testWidgets(
    'U1: con la unidad en lb, el historial muestra el volumen en lb, no en kg',
    (tester) async {
      await addExercise(1, 'chest');
      final session = await workoutRepo.startSession();
      await workoutRepo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 100.0,
        'reps': 10,
      });
      await workoutRepo.finishSession(session.id);

      await tester.pumpWidget(wrap(const HistoryListScreen()));
      await tester.pumpAndSettle();

      // 100 kg -> 220 lb (redondeado, 0 decimales en formatWeight).
      expect(find.textContaining('220'), findsOneWidget);
      expect(find.textContaining('lb'), findsWidgets);
      expect(find.textContaining('kg'), findsNothing);
    },
  );

  testWidgets(
    'U1: con la unidad en lb, la pestaña de análisis muscular muestra el '
    'volumen en lb, no en kg',
    (tester) async {
      await addExercise(1, 'legs');
      final now = DateTime.now();
      final sessionId = await db
          .into(db.workoutSessions)
          .insert(
            local.WorkoutSessionsCompanion.insert(
              startedAt: now,
              endedAt: Value(now.add(const Duration(minutes: 30))),
              updatedAt: now,
            ),
          );
      await db
          .into(db.workoutSets)
          .insert(
            local.WorkoutSetsCompanion.insert(
              sessionId: sessionId,
              exerciseId: 1,
              setNumber: 1,
              weightKg: const Value(100.0),
              reps: const Value(10),
            ),
          );

      await tester.pumpWidget(wrap(const MuscleAnalysisTab()));
      await tester.pumpAndSettle();

      expect(find.textContaining('lb'), findsWidgets);
      expect(find.textContaining('kg'), findsNothing);
    },
  );
}
