import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/repositories/gamification_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late local.AppDatabase db;
  late GamificationRepository repo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    repo = GamificationRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  test('sin actividad, el perfil arranca en nivel 1 con 0 XP', () async {
    final profile = await repo.profile();
    expect(profile.level, 1);
    expect(profile.totalXp, 0.0);
    expect(profile.achievements, hasLength(6));
    expect(profile.achievements.every((a) => !a.unlocked), isTrue);
  });

  test('XP suma sesiones + series + récords + racha, y sube de nivel', () async {
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

    // 5 sesiones completas, cada una con 4 series (no-calentamiento) del mismo día.
    for (var i = 0; i < 5; i++) {
      final startedAt = DateTime.now().subtract(Duration(days: i));
      final sessionId = await db
          .into(db.workoutSessions)
          .insert(
            local.WorkoutSessionsCompanion.insert(
              startedAt: startedAt,
              updatedAt: startedAt,
              endedAt: Value(startedAt.add(const Duration(minutes: 45))),
            ),
          );
      for (var j = 0; j < 4; j++) {
        await db
            .into(db.workoutSets)
            .insert(
              local.WorkoutSetsCompanion.insert(
                sessionId: sessionId,
                exerciseId: 1,
                setNumber: j + 1,
                weightKg: const Value(100),
                reps: const Value(10),
              ),
            );
      }
    }
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

    final profile = await repo.profile();
    // 5 sesiones*10 + 20 series*1 + 1 récord*25 + racha(5)*2 = 50+20+25+10 = 105
    expect(profile.totalXp, 105.0);
    expect(profile.sessionsCompleted, 5);
    expect(profile.recordsCount, 1);
    expect(profile.longestStreakDays, 5);
    expect(profile.level, 2); // 100*1^2=100 <= 105 < 100*2^2=400
    expect(
      profile.achievements
          .firstWhere((a) => a.code == 'first_workout')
          .unlocked,
      isTrue,
    );
    expect(
      profile.achievements.firstWhere((a) => a.code == 'first_pr').unlocked,
      isTrue,
    );
  });
}
