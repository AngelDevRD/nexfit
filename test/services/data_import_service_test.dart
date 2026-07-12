import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/services/data_import_service.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late local.AppDatabase db;
  late DataImportService service;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    service = DataImportService(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('importEnvelope rechaza un archivo sin campo version', () async {
    await expectLater(
      () => service.importEnvelope({
        'data': {'routines': []},
      }),
      throwsA(isA<InvalidBackupFileException>()),
    );
  });

  test('importEnvelope rechaza un archivo sin seccion data', () async {
    await expectLater(
      () => service.importEnvelope({'version': 1}),
      throwsA(isA<InvalidBackupFileException>()),
    );
  });

  test(
    'importEnvelope crea rutinas, sesiones y sets de cero -- nunca mergea',
    () async {
      final envelope = {
        'version': 1,
        'data': {
          'routines': [
            {
              'name': 'Fuerza',
              'goal': 'hypertrophy',
              'days_per_week': 3,
              'days': [
                {
                  'day_index': 0,
                  'name': 'Día 1',
                  'exercises': [
                    {'exercise_id': 1, 'order': 0, 'target_sets': 4},
                  ],
                },
              ],
            },
          ],
          'workout_sessions': [
            {
              'routine_index': 0,
              'started_at': DateTime(2026, 1, 1).toIso8601String(),
              'sets': [
                {
                  'exercise_id': 1,
                  'set_number': 1,
                  'weight_kg': 100.0,
                  'reps': 5,
                },
                {
                  'exercise_id': 1,
                  'set_number': 2,
                  'weight_kg': 105.0,
                  'reps': 5,
                },
              ],
            },
          ],
        },
      };

      final summary = await service.importEnvelope(envelope);

      expect(summary['routines_created'], 1);
      expect(summary['workout_sessions_created'], 1);
      expect(summary['workout_sets_created'], 2);

      final routines = await db.select(db.routines).get();
      expect(routines, hasLength(1));
      final sessions = await db.select(db.workoutSessions).get();
      expect(sessions.single.routineId, routines.single.id);
      final sets = await db.select(db.workoutSets).get();
      expect(sets, hasLength(2));
    },
  );

  test(
    'importEnvelope omite nutrition_logs y checkins de fechas ya cargadas',
    () async {
      final existingDate = DateTime(2026, 3, 1);
      await db
          .into(db.nutritionLogs)
          .insert(
            local.NutritionLogsCompanion.insert(
              logDate: existingDate,
              updatedAt: DateTime.now(),
            ),
          );
      await db
          .into(db.dailyCheckins)
          .insert(
            local.DailyCheckinsCompanion.insert(
              checkinDate: existingDate,
              sleepHours: 7,
              perceivedFatigue: 5,
              updatedAt: DateTime.now(),
            ),
          );

      final envelope = {
        'version': 1,
        'data': {
          'nutrition_logs': [
            {'log_date': existingDate.toIso8601String(), 'calories': 2000},
            {
              'log_date': DateTime(2026, 3, 2).toIso8601String(),
              'calories': 2200,
            },
          ],
          'daily_checkins': [
            {
              'checkin_date': existingDate.toIso8601String(),
              'sleep_hours': 6.0,
              'perceived_fatigue': 6,
            },
            {
              'checkin_date': DateTime(2026, 3, 2).toIso8601String(),
              'sleep_hours': 8.0,
              'perceived_fatigue': 3,
            },
          ],
        },
      };

      final summary = await service.importEnvelope(envelope);

      expect(summary['nutrition_logs_created'], 1);
      expect(summary['nutrition_logs_skipped'], 1);
      expect(summary['daily_checkins_created'], 1);
      expect(summary['daily_checkins_skipped'], 1);
    },
  );

  test(
    'importEnvelope ignora en silencio entidades/campos desconocidos (forward compatibility)',
    () async {
      final envelope = {
        'version': 2,
        'data': {
          'goals': [
            {
              'title': 'Bajar de peso',
              'metric': 'body_weight_kg',
              'starting_value': 90.0,
              'target_value': 80.0,
              'a_future_field_this_client_does_not_know': 'ignorame',
            },
          ],
          'a_future_entity_this_client_does_not_know': [
            {'foo': 'bar'},
          ],
        },
      };

      final summary = await service.importEnvelope(envelope);

      expect(summary['goals_created'], 1);
      final goals = await db.select(db.goals).get();
      expect(goals.single.title, 'Bajar de peso');
    },
  );
}
