import 'dart:io';

import 'package:flutter/foundation.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../../models/workout.dart';
import '../../repositories/workout_repository.dart';
import 'data/excel_writer.dart';
import 'data/export_writers.dart';
import 'domain/export_models.dart';
import 'domain/import_export_models.dart';

enum ExportFlowStatus { idle, exporting, success, error }

/// Orquesta la exportacion: junta las sesiones ya guardadas via
/// [WorkoutRepository] (composicion de metodos existentes, sin tocar el
/// repositorio), las aplana con [workoutSessionsToExportDataset] y delega
/// el formato elegido a [CsvWriter]/[JsonWriter]/[ExcelWriter] -- no
/// reimplementa ninguno. Comparte el mismo patron de compartir archivo que
/// `DataTransferService.exportAll` (archivo temporal + hoja de compartir
/// nativa), pero es un archivo distinto (multi-formato, local-first).
class ExportFlowProvider extends ChangeNotifier {
  final WorkoutRepository workoutRepository;

  ExportFlowProvider({required this.workoutRepository});

  ExportFlowStatus status = ExportFlowStatus.idle;
  String? errorMessage;

  Future<void> exportTo(ImportSourceFormat format) async {
    status = ExportFlowStatus.exporting;
    errorMessage = null;
    notifyListeners();

    try {
      final summaries = await workoutRepository.history();
      final sessions = <WorkoutSession>[
        for (final summary in summaries)
          await workoutRepository.get(summary.id),
      ];
      final dataset = workoutSessionsToExportDataset(sessions);
      final bytes = _writerFor(format).write(dataset);

      final dir = await getTemporaryDirectory();
      final date = DateTime.now().toIso8601String().split('T').first;
      final file = File(
        '${dir.path}/appgym_export_$date.${_extensionFor(format)}',
      );
      await file.writeAsBytes(bytes);
      await Share.shareXFiles([
        XFile(file.path),
      ], text: 'Exportación de entrenamientos de AppGym');

      status = ExportFlowStatus.success;
    } catch (e) {
      errorMessage = e.toString();
      status = ExportFlowStatus.error;
    }
    notifyListeners();
  }

  FileWriter _writerFor(ImportSourceFormat format) => switch (format) {
    ImportSourceFormat.csv => CsvWriter(),
    ImportSourceFormat.json => JsonWriter(),
    ImportSourceFormat.xlsx => ExcelWriter(),
    _ => throw ArgumentError('Formato de exportacion no soportado: $format'),
  };

  String _extensionFor(ImportSourceFormat format) => switch (format) {
    ImportSourceFormat.csv => 'csv',
    ImportSourceFormat.json => 'json',
    ImportSourceFormat.xlsx => 'xlsx',
    _ => 'dat',
  };

  void reset() {
    status = ExportFlowStatus.idle;
    errorMessage = null;
    notifyListeners();
  }
}
