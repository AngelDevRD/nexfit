import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/features/import_export/data/exercise_resolver.dart';
import 'package:appgym/features/import_export/data/import_engine.dart';
import 'package:appgym/features/import_export/domain/mapping_models.dart';
import 'package:appgym/features/import_export/domain/validation_models.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cubre las correcciones del importador (docs/PLAN_ENTRENAMIENTO_V2.md F3/F4):
/// horas reales de la sesión, agrupación por (título, inicio), interpretación
/// de `set_type`, remapeo de supersets y reconstrucción de récords sin
/// duplicados. Ejercita el ImportEngine real contra una base en memoria.
void main() {
  late local.AppDatabase db;
  late ImportEngine engine;

  setUp(() async {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    for (final e in const [
      (1, 'sentadilla-hack', 'Sentadilla Hack'),
      (2, 'prensa', 'Prensa'),
    ]) {
      await db
          .into(db.exercises)
          .insert(
            local.ExercisesCompanion.insert(
              id: Value(e.$1),
              slug: e.$2,
              name: e.$3,
              muscleGroup: 'legs',
              difficulty: 'intermediate',
            ),
          );
    }
    engine = ImportEngine(
      workoutRepository: WorkoutRepository(db),
      exerciseResolver: ExerciseResolver(db),
    );
  });

  tearDown(() async => db.close());

  ValidatedRecord rec(
    int row, {
    required String exercise,
    required String title,
    required DateTime start,
    required DateTime end,
    required int setNumber,
    required double weight,
    required int reps,
    String setType = 'normal',
    int? superset,
  }) => ValidatedRecord(
    rowIndex: row,
    values: {
      CanonicalField.exerciseName: exercise,
      CanonicalField.sessionTitle: title,
      CanonicalField.startTime: start,
      CanonicalField.endTime: end,
      CanonicalField.setNumber: setNumber,
      CanonicalField.weightKg: weight,
      CanonicalField.reps: reps,
      CanonicalField.setType: setType,
      if (superset != null) CanonicalField.supersetId: superset,
    },
    issues: const [],
  );

  test(
    'la sesión guarda la hora real de inicio y fin (no medianoche/now)',
    () async {
      final start = DateTime(2026, 7, 10, 15, 44);
      final end = DateTime(2026, 7, 10, 16, 46);
      await engine.import([
        rec(
          1,
          exercise: 'Sentadilla Hack',
          title: 'Viernes pierna volumen',
          start: start,
          end: end,
          setNumber: 0,
          weight: 80,
          reps: 8,
        ),
      ]);

      final sessions = await db.select(db.workoutSessions).get();
      expect(sessions, hasLength(1));
      expect(sessions.single.startedAt, start);
      expect(sessions.single.endedAt, end);
      expect(sessions.single.title, 'Viernes pierna volumen');
      // La duración real es 1 h 2 min, no miles de minutos.
      expect(
        sessions.single.endedAt!.difference(sessions.single.startedAt),
        const Duration(minutes: 62),
      );
    },
  );

  test('dos entrenamientos el mismo día no se fusionan', () async {
    await engine.import([
      rec(
        1,
        exercise: 'Sentadilla Hack',
        title: 'Mañana',
        start: DateTime(2026, 7, 10, 8),
        end: DateTime(2026, 7, 10, 9),
        setNumber: 0,
        weight: 80,
        reps: 8,
      ),
      rec(
        2,
        exercise: 'Prensa',
        title: 'Tarde',
        start: DateTime(2026, 7, 10, 18),
        end: DateTime(2026, 7, 10, 19),
        setNumber: 0,
        weight: 150,
        reps: 10,
      ),
    ]);

    expect(await db.select(db.workoutSessions).get(), hasLength(2));
  });

  test(
    'set_type dropset se guarda como técnica, no como serie normal',
    () async {
      await engine.import([
        rec(
          1,
          exercise: 'Sentadilla Hack',
          title: 'X',
          start: DateTime(2026, 7, 10, 15),
          end: DateTime(2026, 7, 10, 16),
          setNumber: 0,
          weight: 80,
          reps: 8,
          setType: 'dropset',
        ),
      ]);

      final sets = await db.select(db.workoutSets).get();
      expect(sets.single.techniques, contains('drop_set'));
      expect(sets.single.isWarmup, false);
    },
  );

  test('set_type warmup marca calentamiento y no cuenta para récords', () async {
    await engine.import([
      rec(
        1,
        exercise: 'Sentadilla Hack',
        title: 'X',
        start: DateTime(2026, 7, 10, 15),
        end: DateTime(2026, 7, 10, 16),
        setNumber: 0,
        weight: 200,
        reps: 3,
        setType: 'warmup',
      ),
      rec(
        2,
        exercise: 'Sentadilla Hack',
        title: 'X',
        start: DateTime(2026, 7, 10, 15),
        end: DateTime(2026, 7, 10, 16),
        setNumber: 1,
        weight: 80,
        reps: 8,
      ),
    ]);

    final sets = await db.select(db.workoutSets).get();
    expect(sets.firstWhere((s) => s.setNumber == 0).isWarmup, true);

    final records = await db.select(db.personalRecords).get();
    final maxWeight = records.firstWhere((r) => r.recordType == 'max_weight');
    // El calentamiento de 200 kg se ignora: el récord es el set efectivo (80).
    expect(maxWeight.value, 80);
  });

  test(
    'récords: progresión con fechas reales, récord vigente correcto',
    () async {
      await engine.import([
        for (var i = 0; i < 4; i++)
          rec(
            i + 1,
            exercise: 'Sentadilla Hack',
            title: 'Sesión ${i + 1}',
            start: DateTime(2026, 7, 10 + i, 15),
            end: DateTime(2026, 7, 10 + i, 16),
            setNumber: 0,
            weight: 80.0 + i * 5, // 80, 85, 90, 95 -> progresión
            reps: 8, // reps constantes -> un solo récord de reps
          ),
      ]);

      final records = await db.select(db.personalRecords).get();
      final maxWeight = records.where((r) => r.recordType == 'max_weight');
      // Cuatro mejoras de peso -> cuatro eventos (serie temporal para predecir),
      // con fechas reales de cada sesión, no todas el día de la importación.
      expect(maxWeight, hasLength(4));
      expect(maxWeight.map((r) => r.achievedAt).toSet(), {
        DateTime(2026, 7, 10, 15),
        DateTime(2026, 7, 11, 15),
        DateTime(2026, 7, 12, 15),
        DateTime(2026, 7, 13, 15),
      });
      // Reps constantes -> un único récord de reps (no una fila por sesión).
      expect(records.where((r) => r.recordType == 'max_reps'), hasLength(1));
      // El récord vigente de peso es el máximo de la progresión.
      expect(maxWeight.map((r) => r.value).reduce((a, b) => a > b ? a : b), 95);
    },
  );

  test('supersets se remapean a ids locales por sesión', () async {
    await engine.import([
      rec(
        1,
        exercise: 'Sentadilla Hack',
        title: 'X',
        start: DateTime(2026, 7, 10, 15),
        end: DateTime(2026, 7, 10, 16),
        setNumber: 0,
        weight: 80,
        reps: 8,
        superset: 42,
      ),
      rec(
        2,
        exercise: 'Prensa',
        title: 'X',
        start: DateTime(2026, 7, 10, 15),
        end: DateTime(2026, 7, 10, 16),
        setNumber: 0,
        weight: 150,
        reps: 10,
        superset: 42,
      ),
    ]);

    final sets = await db.select(db.workoutSets).get();
    final groupIds = sets.map((s) => s.supersetGroupId).toSet();
    // Ambos sets comparten el mismo grupo remapeado (un único id, no null).
    expect(groupIds, hasLength(1));
    expect(groupIds.single, isNotNull);
  });
}
