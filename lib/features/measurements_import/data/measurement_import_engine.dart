import '../../../repositories/body_measurement_repository.dart';
import 'measurement_validator.dart';

class MeasurementImportResult {
  final int imported;
  final int skipped;

  const MeasurementImportResult({
    required this.imported,
    required this.skipped,
  });
}

/// Persiste las filas ya validadas via [BodyMeasurementRepository]
/// (upsert-por-dia) -- reimportar el mismo archivo es idempotente, mismo
/// criterio de dedup por fecha que ya usa `DataImportService` para
/// nutrition/checkins.
class MeasurementImportEngine {
  final BodyMeasurementRepository repository;

  MeasurementImportEngine({required this.repository});

  Future<MeasurementImportResult> import(List<MeasurementRow> rows) async {
    var imported = 0;
    var skipped = 0;

    for (final row in rows) {
      if (!row.isValid) {
        skipped++;
        continue;
      }
      await repository.upsertForDate(row.date!, row.fields);
      imported++;
    }

    return MeasurementImportResult(imported: imported, skipped: skipped);
  }
}
