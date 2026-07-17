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

    // Agrupa por (título, hora de inicio) en vez de por día calendario: así
    // dos entrenamientos del mismo día no se fusionan, y cada sesión conserva
    // su hora real de inicio/fin (antes se truncaba a medianoche -> la duración
    // salía en miles de minutos, ver docs/PLAN_ENTRENAMIENTO_V2.md §0.1).
    final groups = <String, List<ValidatedRecord>>{};
    final groupOrder = <String>[];
    for (final record in importable) {
      final start =
          record.values[CanonicalField.startTime] as DateTime? ??
          record.values[CanonicalField.date] as DateTime?;
      final title = record.values[CanonicalField.sessionTitle] as String?;
      final key = '${title ?? ''}|${start?.toIso8601String() ?? 'sin-fecha'}';
      if (!groups.containsKey(key)) groupOrder.add(key);
      groups.putIfAbsent(key, () => []).add(record);
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

    for (final key in groupOrder) {
      final group = groups[key]!;
      final first = group.first.values;
      final start =
          first[CanonicalField.startTime] as DateTime? ??
          first[CanonicalField.date] as DateTime? ??
          DateTime.now();
      final end = first[CanonicalField.endTime] as DateTime?;
      final title = first[CanonicalField.sessionTitle] as String?;

      final session = await workoutRepository.startSession(
        startedAt: start,
        title: title,
      );
      sessionsCreated++;
      var setIndex = 0;
      // Los ids de superserie de Hevy son globales al archivo; se remapean a
      // ids locales por sesión para no colisionar entre sesiones distintas.
      final supersetRemap = <int, int>{};

      for (final record in group) {
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
        final setType = (record.values[CanonicalField.setType] as String?)
            ?.toLowerCase();
        final rawSuperset = record.values[CanonicalField.supersetId] as int?;
        final supersetGroupId = rawSuperset == null
            ? null
            : supersetRemap.putIfAbsent(
                rawSuperset,
                () => supersetRemap.length + 1,
              );

        await workoutRepository.addSet(session.id, {
          'exercise_id': exerciseId,
          'set_number': record.values[CanonicalField.setNumber] ?? setIndex,
          'weight_kg': record.values[CanonicalField.weightKg] ?? 0,
          'reps': record.values[CanonicalField.reps] ?? 0,
          'rpe': record.values[CanonicalField.rpe],
          'rir': record.values[CanonicalField.rir],
          'rest_seconds': record.values[CanonicalField.restSeconds],
          'is_warmup': _isWarmup(
            setType,
            record.values[CanonicalField.isWarmup],
          ),
          'techniques': _techniquesFor(setType),
          'superset_group_id': supersetGroupId,
          'notes': record.values[CanonicalField.notes],
        });
        setsCreated++;
        outcomes.add(ImportOutcome(rowIndex: record.rowIndex, imported: true));
      }

      // Fija la hora de fin real del CSV (o null si no vino -> la UI muestra
      // "—", nunca DateTime.now() para datos importados).
      await workoutRepository.finishSession(session.id, endedAt: end);
    }

    // Reconstruye los récords una sola vez, replayando todo el historial ya
    // escrito en orden cronológico. Es más rápido y correcto que evaluar PR
    // set por set durante la importación (que además dejaba `achievedAt` mal).
    await workoutRepository.rebuildPersonalRecords();

    return ImportResult(
      sessionsCreated: sessionsCreated,
      setsCreated: setsCreated,
      outcomes: outcomes,
    );
  }

  /// `set_type` de Hevy -> flag de calentamiento. `warmup` es calentamiento;
  /// el resto (normal/dropset/failure) no. Cae al valor mapeado de `isWarmup`
  /// si no hubo columna `set_type`.
  bool _isWarmup(String? setType, dynamic isWarmupValue) {
    if (setType != null) return setType == 'warmup';
    return isWarmupValue as bool? ?? false;
  }

  /// `set_type` de Hevy -> técnicas ejecutadas. `dropset`/`failure` se guardan
  /// en `techniques` (ya existen en `availableTechniques`); `normal`/`warmup`
  /// no aportan técnica.
  List<String> _techniquesFor(String? setType) {
    switch (setType) {
      case 'dropset':
        return const ['drop_set'];
      case 'failure':
        return const ['to_failure'];
      default:
        return const [];
    }
  }
}
