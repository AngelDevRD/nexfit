import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../repositories/workout_repository.dart';
import 'data/auto_mapper.dart';
import 'data/exercise_resolver.dart';
import 'data/file_reader.dart';
import 'data/import_engine.dart';
import 'data/parser_registry.dart';
import 'data/preview_builder.dart';
import 'data/validators.dart';
import 'domain/exercise_resolution_models.dart';
import 'domain/import_export_models.dart';
import 'domain/import_result.dart';
import 'domain/mapping_models.dart';
import 'domain/validation_models.dart';

enum ImportFlowStatus {
  idle,
  loading,
  resolvingExercises,
  preview,
  importing,
  success,
  error,
}

/// Orquesta el flujo completo de importacion: elegir archivo -> FileReader
/// -> AutoMapper -> Validators -> PreviewBuilder (analisis, F9a) y, tras
/// confirmar el usuario, ImportEngine (persistencia, F9b). No reimplementa
/// ninguna de esas piezas -- solo las encadena y expone el estado a la UI.
class ImportFlowProvider extends ChangeNotifier {
  final FileReader _fileReader;
  final ImportEngine _importEngine;

  ImportFlowProvider({
    required WorkoutRepository workoutRepository,
    FileReader? fileReader,
    ImportEngine? importEngine,
  }) : _fileReader = fileReader ?? FileReader(defaultFileParsers()),
       _importEngine =
           importEngine ??
           ImportEngine(
             workoutRepository: workoutRepository,
             exerciseResolver: ExerciseResolver(workoutRepository.db),
           );

  ImportFlowStatus status = ImportFlowStatus.idle;
  String? fileName;
  MappingResult? mapping;
  List<ValidatedRecord>? validatedRecords;
  PreviewSummary? summary;
  ImportResult? result;
  String? errorMessage;
  List<UnresolvedExerciseGroup>? unresolvedExercises;
  List<CatalogExerciseOption>? catalogOptions;

  Future<void> pickAndAnalyzeFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'xls', 'json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    status = ImportFlowStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final dataset = await _fileReader.readFile(path);
      await analyzeDataset(dataset);
    } catch (e) {
      errorMessage = e.toString();
      status = ImportFlowStatus.error;
      notifyListeners();
    }
  }

  /// Corre AutoMapper -> Validators -> deteccion de ejercicios sin resolver
  /// sobre un [ParsedDataset] ya leido. Separado de [pickAndAnalyzeFile] (que
  /// depende del plugin `file_picker`) para que este paso -- el que decide si
  /// hace falta mostrar la pantalla de resolucion -- se pueda testear
  /// construyendo un [ParsedDataset] a mano, sin pasar por un archivo real.
  @visibleForTesting
  Future<void> analyzeDataset(ParsedDataset dataset) async {
    final autoMapping = AutoMapper().map(dataset.columns);
    final validated = Validators().validate(dataset, autoMapping);

    fileName = dataset.sourceFileName;
    mapping = autoMapping;
    validatedRecords = validated;

    final unresolved = await _detectUnresolvedExercises(validated);
    if (unresolved.isNotEmpty) {
      unresolvedExercises = unresolved;
      catalogOptions = await _importEngine.exerciseResolver.listCatalog();
      status = ImportFlowStatus.resolvingExercises;
    } else {
      summary = PreviewBuilder().build(validated, autoMapping);
      status = ImportFlowStatus.preview;
    }
    notifyListeners();
  }

  /// Agrupa por nombre normalizado ([normalizeHeader]) los `exerciseName` de
  /// filas sin errores de validacion que no resuelven a ningun ejercicio del
  /// catalogo, para preguntarle al usuario una sola vez por cada nombre
  /// distinto (sin importar mayusculas/espacios) en vez de una vez por fila
  /// -- "Bench Press" repetido 3 veces es un solo grupo, no tres.
  Future<List<UnresolvedExerciseGroup>> _detectUnresolvedExercises(
    List<ValidatedRecord> records,
  ) async {
    final resolver = _importEngine.exerciseResolver;
    final rowsByKey = <String, List<int>>{};
    final displayNameByKey = <String, String>{};

    for (final record in records) {
      if (record.hasErrors) continue;
      final exerciseName =
          record.values[CanonicalField.exerciseName] as String?;
      if (exerciseName == null) continue;
      if (await resolver.resolve(exerciseName) != null) continue;

      final key = normalizeHeader(exerciseName);
      displayNameByKey.putIfAbsent(key, () => exerciseName);
      rowsByKey.putIfAbsent(key, () => []).add(record.rowIndex);
    }

    return [
      for (final key in rowsByKey.keys)
        UnresolvedExerciseGroup(
          key: key,
          name: displayNameByKey[key]!,
          rowIndexes: rowsByKey[key]!,
        ),
    ];
  }

  /// Aplica las decisiones tomadas en la pantalla de resolucion (una por
  /// cada [UnresolvedExerciseGroup], indexadas por [UnresolvedExerciseGroup.key])
  /// y recien ahi arma la vista previa -- para que el resumen ya refleje los
  /// ejercicios creados/asociados.
  Future<void> submitExerciseResolutions(
    Map<String, ExerciseResolutionChoice> choices,
  ) async {
    final resolver = _importEngine.exerciseResolver;
    final groupsByKey = {for (final g in unresolvedExercises!) g.key: g};

    for (final entry in choices.entries) {
      final group = groupsByKey[entry.key]!;
      final choice = entry.value;
      switch (choice.action) {
        case ExerciseResolutionAction.ignore:
          break;
        case ExerciseResolutionAction.createNew:
          await resolver.createExercise(group.name);
          break;
        case ExerciseResolutionAction.mapExisting:
          await resolver.applyManualMapping(
            group.name,
            choice.mappedExerciseId!,
          );
          break;
      }
    }

    unresolvedExercises = null;
    catalogOptions = null;
    summary = PreviewBuilder().build(validatedRecords!, mapping!);
    status = ImportFlowStatus.preview;
    notifyListeners();
  }

  Future<void> confirmImport() async {
    final records = validatedRecords;
    if (records == null) return;

    status = ImportFlowStatus.importing;
    errorMessage = null;
    notifyListeners();

    try {
      result = await _importEngine.import(records);
      status = ImportFlowStatus.success;
    } catch (e) {
      errorMessage = e.toString();
      status = ImportFlowStatus.error;
    }
    notifyListeners();
  }

  void reset() {
    status = ImportFlowStatus.idle;
    fileName = null;
    mapping = null;
    validatedRecords = null;
    summary = null;
    result = null;
    errorMessage = null;
    unresolvedExercises = null;
    catalogOptions = null;
    notifyListeners();
  }
}
