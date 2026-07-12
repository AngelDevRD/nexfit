import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/services/data_export_service.dart';
import 'package:appgym/services/data_import_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Export A -> Import -> Export B: A y B deben ser equivalentes (salvo
/// `exported_at`, que es un timestamp inevitablemente distinto, y `profile`,
/// que el import nunca reconstruye -- mismo comportamiento que tenía el
/// backend FastAPI original). Este tipo de prueba suele descubrir problemas
/// de duplicación o serialización antes de que lleguen a producción.
void main() {
  test(
    'export -> import -> export es idempotente (A equivalente a B)',
    () async {
      final sourceDb = local.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(sourceDb.close);

      await sourceDb
          .into(sourceDb.exercises)
          .insert(
            local.ExercisesCompanion.insert(
              id: const Value(1),
              slug: 'sentadilla',
              name: 'Sentadilla',
              muscleGroup: 'legs',
              difficulty: 'intermediate',
            ),
          );
      final routineId = await sourceDb
          .into(sourceDb.routines)
          .insert(
            local.RoutinesCompanion.insert(
              name: 'Fuerza',
              goal: const Value('hypertrophy'),
              daysPerWeek: const Value(3),
              updatedAt: DateTime.now(),
            ),
          );
      final dayId = await sourceDb
          .into(sourceDb.routineDays)
          .insert(
            local.RoutineDaysCompanion.insert(
              routineId: routineId,
              dayIndex: 0,
              name: 'Día 1',
            ),
          );
      await sourceDb
          .into(sourceDb.routineExercises)
          .insert(
            local.RoutineExercisesCompanion.insert(
              dayId: dayId,
              exerciseId: 1,
              orderIndex: 0,
              targetSets: const Value(4),
            ),
          );
      final sessionId = await sourceDb
          .into(sourceDb.workoutSessions)
          .insert(
            local.WorkoutSessionsCompanion.insert(
              routineId: Value(routineId),
              startedAt: DateTime(2026, 1, 1, 10),
              endedAt: Value(DateTime(2026, 1, 1, 11)),
              updatedAt: DateTime.now(),
            ),
          );
      await sourceDb
          .into(sourceDb.workoutSets)
          .insert(
            local.WorkoutSetsCompanion.insert(
              sessionId: sessionId,
              exerciseId: 1,
              setNumber: 1,
              weightKg: const Value(100.0),
              reps: const Value(5),
            ),
          );
      await sourceDb
          .into(sourceDb.nutritionLogs)
          .insert(
            local.NutritionLogsCompanion.insert(
              logDate: DateTime(2026, 1, 1),
              calories: const Value(2200),
              updatedAt: DateTime.now(),
            ),
          );
      await sourceDb
          .into(sourceDb.dailyCheckins)
          .insert(
            local.DailyCheckinsCompanion.insert(
              checkinDate: DateTime(2026, 1, 1),
              sleepHours: 7.5,
              perceivedFatigue: 4,
              updatedAt: DateTime.now(),
            ),
          );
      await sourceDb
          .into(sourceDb.goals)
          .insert(
            local.GoalsCompanion.insert(
              title: 'Bajar de peso',
              metric: 'body_weight_kg',
              startingValue: 90.0,
              targetValue: 80.0,
              updatedAt: DateTime.now(),
            ),
          );

      final envelopeA = await DataExportService(sourceDb).buildEnvelope();

      final targetDb = local.AppDatabase.forTesting(NativeDatabase.memory());
      addTearDown(targetDb.close);
      await DataImportService(targetDb).importEnvelope(envelopeA);

      final envelopeB = await DataExportService(targetDb).buildEnvelope();

      final dataA = envelopeA['data'] as Map<String, dynamic>;
      final dataB = envelopeB['data'] as Map<String, dynamic>;

      // El profile nunca se reconstruye en el import (igual que el backend
      // original) -- se excluye explícitamente de la comparación.
      expect(dataB['routines'], dataA['routines']);
      expect(dataB['workout_sessions'], dataA['workout_sessions']);
      expect(dataB['nutrition_logs'], dataA['nutrition_logs']);
      expect(dataB['daily_checkins'], dataA['daily_checkins']);
      expect(dataB['goals'], dataA['goals']);
    },
  );
}
