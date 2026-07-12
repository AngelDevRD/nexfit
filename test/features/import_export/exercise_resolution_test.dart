import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/features/import_export/domain/exercise_resolution_models.dart';
import 'package:appgym/features/import_export/domain/import_export_models.dart';
import 'package:appgym/features/import_export/import_flow_provider.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:drift/drift.dart' show Value;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cubre la pantalla de resolucion de ejercicios sin correspondencia (mejora
/// de UX sobre F9): un ejercicio importado que no existe en el catalogo ya
/// no se omite en silencio, sino que dispara [ImportFlowStatus.resolvingExercises]
/// y espera una decision explicita del usuario por cada nombre distinto.
void main() {
  late local.AppDatabase db;
  late ImportFlowProvider provider;

  setUp(() async {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    await db
        .into(db.exercises)
        .insert(
          local.ExercisesCompanion.insert(
            id: const Value(1),
            slug: 'press-de-banca',
            name: 'Press de banca',
            muscleGroup: 'Pecho',
            difficulty: 'beginner',
          ),
        );
    provider = ImportFlowProvider(workoutRepository: WorkoutRepository(db));
  });

  tearDown(() async => db.close());

  ParsedDataset datasetWithExercises(List<String> exerciseNames) {
    return ParsedDataset(
      format: ImportSourceFormat.csv,
      sourceFileName: 'test.csv',
      columns: const ['exercise', 'date', 'weight', 'reps'],
      records: [
        for (var i = 0; i < exerciseNames.length; i++)
          RawRecord(
            rowIndex: i + 1,
            values: {
              'exercise': exerciseNames[i],
              'date': '2026-01-${(i + 1).toString().padLeft(2, '0')}',
              'weight': '50',
              'reps': '10',
            },
          ),
      ],
    );
  }

  test('ejercicio inexistente dispara la pantalla de resolucion', () async {
    await provider.analyzeDataset(datasetWithExercises(['Bench Press']));

    expect(provider.status, ImportFlowStatus.resolvingExercises);
    expect(provider.unresolvedExercises, hasLength(1));
    expect(provider.unresolvedExercises!.single.name, 'Bench Press');
  });

  test('ejercicio ya en el catalogo no dispara resolucion', () async {
    await provider.analyzeDataset(datasetWithExercises(['Press de banca']));

    expect(provider.status, ImportFlowStatus.preview);
    expect(provider.unresolvedExercises, isNull);
  });

  test('el mismo ejercicio repetido (con distintas mayusculas/espacios) '
      'aparece como un solo elemento en la lista de resolucion', () async {
    await provider.analyzeDataset(
      datasetWithExercises(['Bench Press', 'bench press', ' Bench  Press ']),
    );

    expect(provider.unresolvedExercises, hasLength(1));
    expect(provider.unresolvedExercises!.single.rowIndexes, [1, 2, 3]);
  });

  test('crear ejercicio nuevo: existe al finalizar y no se duplica '
      'aunque el nombre se repita varias veces', () async {
    await provider.analyzeDataset(
      datasetWithExercises(['Bench Press', 'Bench Press', 'Bench Press']),
    );
    final group = provider.unresolvedExercises!.single;

    await provider.submitExerciseResolutions({
      group.key: const ExerciseResolutionChoice.createNew(),
    });

    expect(provider.status, ImportFlowStatus.preview);
    final rows = await db.select(db.exercises).get();
    expect(rows.where((r) => r.name == 'Bench Press'), hasLength(1));

    await provider.confirmImport();
    expect(provider.status, ImportFlowStatus.success);
    expect(provider.result!.setsCreated, 3);
  });

  test('ignorar: no crea el ejercicio y la fila queda omitida sin romper '
      'el resto de la importacion', () async {
    await provider.analyzeDataset(
      datasetWithExercises(['Bench Press', 'Press de banca']),
    );
    final group = provider.unresolvedExercises!.single;

    await provider.submitExerciseResolutions({
      group.key: const ExerciseResolutionChoice.ignore(),
    });

    final rows = await db.select(db.exercises).get();
    expect(rows.where((r) => r.name == 'Bench Press'), isEmpty);

    await provider.confirmImport();
    expect(provider.status, ImportFlowStatus.success);
    expect(provider.result!.setsCreated, 1);
    expect(provider.result!.skipped, 1);
  });

  test('asociar manualmente: la fila usa el ejercicio elegido', () async {
    await provider.analyzeDataset(datasetWithExercises(['Bench Press']));
    final group = provider.unresolvedExercises!.single;

    await provider.submitExerciseResolutions({
      group.key: const ExerciseResolutionChoice.mapExisting(1),
    });
    await provider.confirmImport();

    expect(provider.status, ImportFlowStatus.success);
    expect(provider.result!.setsCreated, 1);
    final sets = await db.select(db.workoutSets).get();
    expect(sets.single.exerciseId, 1);
  });

  test(
    'combinacion en una misma importacion: crear + asociar + ignorar',
    () async {
      await provider.analyzeDataset(
        datasetWithExercises(['Bench Press', 'Squat', 'Deadlift']),
      );
      expect(provider.unresolvedExercises, hasLength(3));

      final choices = {
        for (final g in provider.unresolvedExercises!)
          g.key: switch (g.name) {
            'Bench Press' => const ExerciseResolutionChoice.mapExisting(1),
            'Squat' => const ExerciseResolutionChoice.createNew(),
            _ => const ExerciseResolutionChoice.ignore(),
          },
      };
      await provider.submitExerciseResolutions(choices);
      await provider.confirmImport();

      expect(provider.status, ImportFlowStatus.success);
      expect(provider.result!.setsCreated, 2);
      expect(provider.result!.skipped, 1);

      final rows = await db.select(db.exercises).get();
      expect(rows.where((r) => r.name == 'Squat'), hasLength(1));
      expect(rows.where((r) => r.name == 'Deadlift'), isEmpty);
    },
  );
}
