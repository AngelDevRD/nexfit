import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/repositories/goal_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late local.AppDatabase db;
  late GoalRepository repo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    repo = GoalRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'objetivo de peso corporal usa el peso actual del perfil como punto de partida',
    () async {
      await db
          .into(db.profiles)
          .insert(
            local.ProfilesCompanion.insert(
              id: 'user-1',
              updatedAt: DateTime.now(),
              weightKg: const Value(80.0),
            ),
          );

      await repo.create({
        'title': 'Bajar de peso',
        'metric': 'body_weight_kg',
        'target_value': 75.0,
      });

      final goals = await repo.list();
      expect(goals, hasLength(1));
      expect(goals.first.startingValue, 80.0);
      expect(goals.first.currentValue, 80.0);
      expect(goals.first.progressPct, 0.0);
      expect(goals.first.achieved, isFalse);
    },
  );

  test(
    'progreso de objetivo de peso avanza cuando el perfil se actualiza',
    () async {
      await db
          .into(db.profiles)
          .insert(
            local.ProfilesCompanion.insert(
              id: 'user-1',
              updatedAt: DateTime.now(),
              weightKg: const Value(80.0),
            ),
          );
      await repo.create({
        'title': 'Bajar de peso',
        'metric': 'body_weight_kg',
        'target_value': 70.0, // span de 10kg (80 -> 70)
      });

      await (db.update(db.profiles)..where((t) => t.id.equals('user-1'))).write(
        const local.ProfilesCompanion(weightKg: Value(75.0)),
      );

      final goals = await repo.list();
      expect(goals.first.currentValue, 75.0);
      expect(goals.first.progressPct, 50.0); // avanzó 5 de 10kg
      expect(goals.first.achieved, isFalse);
    },
  );

  test(
    'objetivo de fuerza usa el récord personal local como valor actual',
    () async {
      final exerciseId = await db
          .into(db.exercises)
          .insert(
            local.ExercisesCompanion.insert(
              id: const Value(1),
              slug: 'press-banca',
              name: 'Press banca',
              muscleGroup: 'chest',
              difficulty: 'intermediate',
            ),
          );

      await repo.create({
        'title': 'Press banca a 100kg',
        'metric': 'exercise_max_weight',
        'exercise_id': exerciseId,
        'target_value': 100.0,
      });
      // Sin récords todavía: startingValue cae a 0 (no hay valor previo).
      var goals = await repo.list();
      expect(goals.first.startingValue, 0.0);
      expect(goals.first.currentValue, 0.0);

      await db
          .into(db.personalRecords)
          .insert(
            local.PersonalRecordsCompanion.insert(
              exerciseId: const Value(1),
              recordType: 'max_weight',
              value: 90.0,
              achievedAt: DateTime.now(),
            ),
          );

      goals = await repo.list();
      expect(goals.first.currentValue, 90.0);
      expect(goals.first.progressPct, 90.0); // 90/100 del objetivo (span=100)
      expect(goals.first.achieved, isFalse);

      await db
          .into(db.personalRecords)
          .insert(
            local.PersonalRecordsCompanion.insert(
              exerciseId: const Value(1),
              recordType: 'max_weight',
              value: 100.0,
              achievedAt: DateTime.now(),
            ),
          );

      goals = await repo.list();
      expect(goals.first.currentValue, 100.0);
      expect(goals.first.achieved, isTrue);
    },
  );

  test('borrar un objetivo lo saca de list()', () async {
    final id = await repo.create({
      'title': 'Objetivo temporal',
      'metric': 'body_weight_kg',
      'target_value': 70.0,
    });

    await repo.delete(id);

    expect(await repo.list(), isEmpty);
  });
}
