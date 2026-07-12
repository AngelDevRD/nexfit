import '../../../repositories/workout_repository.dart';
import '../domain/import_result.dart';
import '../domain/mapping_models.dart';
import '../domain/validation_models.dart';
import 'exercise_resolver.dart';

/// Persiste los registros ya validados: agrupa por fecha en sesiones de
/// entrenamiento y reusa [WorkoutRepository] (no escribe Drift directo) para
/// que las sesiones/sets importados queden con el mismo flujo de sync
/// (dirty flags, PendingSetOps, deteccion de PRs) que un set cargado a mano
/// desde la UI.
///
/// Filas con errores de validacion nunca se persisten. Filas cuyo
/// `exerciseName` no resuelve a un ejercicio del catalogo tampoco -- se
/// reportan como no importadas en vez de crear un ejercicio nuevo por su
/// cuenta.
class ImportEngine {
  final WorkoutRepository workoutRepository;
  final ExerciseResolver exerciseResolver;

  ImportEngine({
    required this.workoutRepository,
    required this.exerciseResolver,
  });

  Future<ImportResult> import(List<ValidatedRecord> records) async {
    final importable = records.where((r) => !r.hasErrors).toList();
    final groups = <DateTime, List<ValidatedRecord>>{};
    for (final record in importable) {
      final date = record.values[CanonicalField.date] as DateTime?;
      final day = date == null
          ? DateTime.now()
          : DateTime(date.year, date.month, date.day);
      groups.putIfAbsent(day, () => []).add(record);
    }

    final outcomes = <ImportOutcome>[
      for (final record in records)
        if (record.hasErrors)
          ImportOutcome(
            rowIndex: record.rowIndex,
            imported: false,
            reason: 'Fila con errores de validacion, no importada',
          ),
    ];
    var sessionsCreated = 0;
    var setsCreated = 0;

    for (final entry in groups.entries) {
      final session = await workoutRepository.startSession(
        startedAt: entry.key,
      );
      sessionsCreated++;
      var setIndex = 0;

      for (final record in entry.value) {
        final exerciseName =
            record.values[CanonicalField.exerciseName] as String?;
        final exerciseId = exerciseName == null
            ? null
            : await exerciseResolver.resolve(exerciseName);

        if (exerciseId == null) {
          outcomes.add(
            ImportOutcome(
              rowIndex: record.rowIndex,
              imported: false,
              reason: 'Ejercicio no encontrado en el catalogo: "$exerciseName"',
            ),
          );
          continue;
        }

        setIndex++;
        await workoutRepository.addSet(session.id, {
          'exercise_id': exerciseId,
          'set_number': record.values[CanonicalField.setNumber] ?? setIndex,
          'weight_kg': record.values[CanonicalField.weightKg] ?? 0,
          'reps': record.values[CanonicalField.reps] ?? 0,
          'rpe': record.values[CanonicalField.rpe],
          'rir': record.values[CanonicalField.rir],
          'rest_seconds': record.values[CanonicalField.restSeconds],
          'is_warmup': record.values[CanonicalField.isWarmup] ?? false,
          'notes': record.values[CanonicalField.notes],
        });
        setsCreated++;
        outcomes.add(ImportOutcome(rowIndex: record.rowIndex, imported: true));
      }

      await workoutRepository.finishSession(session.id);
    }

    return ImportResult(
      sessionsCreated: sessionsCreated,
      setsCreated: setsCreated,
      outcomes: outcomes,
    );
  }
}
