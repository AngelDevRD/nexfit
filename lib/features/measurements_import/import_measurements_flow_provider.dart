import 'package:file_picker/file_picker.dart';
import 'package:flutter/foundation.dart';

import '../../repositories/body_measurement_repository.dart';
import '../import_export/data/file_reader.dart';
import '../import_export/data/parser_registry.dart';
import '../import_export/domain/import_export_models.dart';
import 'data/measurement_import_engine.dart';
import 'data/measurement_validator.dart';

enum MeasurementImportStatus {
  idle,
  loading,
  preview,
  importing,
  success,
  error,
}

/// Flujo de importacion de medidas corporales -- version chica del
/// [ImportFlowProvider] de F9 (elegir archivo -> parsear -> validar ->
/// resumen -> confirmar -> importar), sin pantalla de mapeo manual de
/// columnas ni de resolucion de ejercicios porque no aplican aca (el
/// esquema es fijo y no hay entidades para resolver contra un catalogo).
/// Reusa el mismo [FileReader]/[defaultFileParsers] de F9 -- esa capa ya es
/// agnostica de dominio.
class ImportMeasurementsFlowProvider extends ChangeNotifier {
  final FileReader _fileReader;
  final MeasurementImportEngine _engine;

  ImportMeasurementsFlowProvider({
    required BodyMeasurementRepository repository,
    FileReader? fileReader,
    MeasurementImportEngine? engine,
  }) : _fileReader = fileReader ?? FileReader(defaultFileParsers()),
       _engine = engine ?? MeasurementImportEngine(repository: repository);

  MeasurementImportStatus status = MeasurementImportStatus.idle;
  String? fileName;
  List<MeasurementRow>? rows;
  MeasurementImportResult? result;
  String? errorMessage;

  Future<void> pickAndAnalyzeFile() async {
    final picked = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: const ['csv', 'xlsx', 'xls', 'json'],
    );
    final path = picked?.files.single.path;
    if (path == null) return;

    status = MeasurementImportStatus.loading;
    errorMessage = null;
    notifyListeners();

    try {
      final dataset = await _fileReader.readFile(path);
      await analyzeDataset(dataset);
    } catch (e) {
      errorMessage = e.toString();
      status = MeasurementImportStatus.error;
      notifyListeners();
    }
  }

  /// Separado de [pickAndAnalyzeFile] (que depende de `file_picker`) para
  /// poder testear con un [ParsedDataset] armado a mano.
  @visibleForTesting
  Future<void> analyzeDataset(ParsedDataset dataset) async {
    fileName = dataset.sourceFileName;
    rows = MeasurementValidator().validate(dataset);
    status = MeasurementImportStatus.preview;
    notifyListeners();
  }

  Future<void> confirmImport() async {
    final currentRows = rows;
    if (currentRows == null) return;

    status = MeasurementImportStatus.importing;
    errorMessage = null;
    notifyListeners();

    try {
      result = await _engine.import(currentRows);
      status = MeasurementImportStatus.success;
    } catch (e) {
      errorMessage = e.toString();
      status = MeasurementImportStatus.error;
    }
    notifyListeners();
  }

  void reset() {
    status = MeasurementImportStatus.idle;
    fileName = null;
    rows = null;
    result = null;
    errorMessage = null;
    notifyListeners();
  }
}
