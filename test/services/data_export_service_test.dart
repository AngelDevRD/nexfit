import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/services/data_export_service.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late local.AppDatabase db;
  late DataExportService service;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    service = DataExportService(db, userEmail: 'user@example.com');
  });

  tearDown(() async {
    await db.close();
  });

  test('buildEnvelope trae version y estructura vacia sin datos', () async {
    final envelope = await service.buildEnvelope();

    expect(envelope['version'], 1);
    expect(envelope['exported_at'], isNot(null));
    final data = envelope['data'] as Map<String, dynamic>;
    expect(data['routines'], isEmpty);
    expect(data['workout_sessions'], isEmpty);
    expect(data['nutrition_logs'], isEmpty);
    expect(data['daily_checkins'], isEmpty);
    expect(data['goals'], isEmpty);
    expect(data['profile']['email'], 'user@example.com');
  });

  test('buildEnvelope serializa rutina con dias y ejercicios', () async {
    await db
        .into(db.exercises)
        .insert(
          local.ExercisesCompanion.insert(
            id: const Value(1),
            slug: 'sentadilla',
            name: 'Sentadilla',
            muscleGroup: 'legs',
            difficulty: 'intermediate',
          ),
        );
    final routineId = await db
        .into(db.routines)
        .insert(
          local.RoutinesCompanion.insert(
            name: 'Fuerza',
            daysPerWeek: const Value(3),
            updatedAt: DateTime.now(),
          ),
        );
    final dayId = await db
        .into(db.routineDays)
        .insert(
          local.RoutineDaysCompanion.insert(
            routineId: routineId,
            dayIndex: 0,
            name: 'Día 1',
          ),
        );
    await db
        .into(db.routineExercises)
        .insert(
          local.RoutineExercisesCompanion.insert(
            dayId: dayId,
            exerciseId: 1,
            orderIndex: 0,
            targetSets: const Value(4),
          ),
        );

    final envelope = await service.buildEnvelope();
    final routines = (envelope['data'] as Map)['routines'] as List;
    expect(routines, hasLength(1));
    final routine = routines.single as Map<String, dynamic>;
    expect(routine['name'], 'Fuerza');
    final days = routine['days'] as List;
    expect(days, hasLength(1));
    final exercises = (days.single as Map)['exercises'] as List;
    expect((exercises.single as Map)['exercise_id'], 1);
    expect((exercises.single as Map)['target_sets'], 4);
  });

  test(
    'buildEnvelope referencia la rutina de una sesion por indice, no por id',
    () async {
      final routineId = await db
          .into(db.routines)
          .insert(
            local.RoutinesCompanion.insert(
              name: 'Fuerza',
              updatedAt: DateTime.now(),
            ),
          );
      await db
          .into(db.workoutSessions)
          .insert(
            local.WorkoutSessionsCompanion.insert(
              routineId: Value(routineId),
              startedAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );

      final envelope = await service.buildEnvelope();
      final sessions = (envelope['data'] as Map)['workout_sessions'] as List;
      expect((sessions.single as Map)['routine_index'], 0);
    },
  );

  test(
    'buildEnvelope no incluye rutinas ni goals marcados como deleted',
    () async {
      await db
          .into(db.routines)
          .insert(
            local.RoutinesCompanion.insert(
              name: 'Borrada',
              deleted: const Value(true),
              updatedAt: DateTime.now(),
            ),
          );
      await db
          .into(db.goals)
          .insert(
            local.GoalsCompanion.insert(
              title: 'Meta borrada',
              metric: 'body_weight_kg',
              startingValue: 80,
              targetValue: 75,
              deleted: const Value(true),
              updatedAt: DateTime.now(),
            ),
          );

      final envelope = await service.buildEnvelope();
      final data = envelope['data'] as Map<String, dynamic>;
      expect(data['routines'], isEmpty);
      expect(data['goals'], isEmpty);
    },
  );
}
