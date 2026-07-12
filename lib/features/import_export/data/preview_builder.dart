import '../domain/mapping_models.dart';
import '../domain/validation_models.dart';

/// Agrega la salida de [Validators] en un [PreviewSummary] contable para
/// mostrarle al usuario antes de confirmar la importacion. Solo cuenta y
/// junta lo que ya vino calculado -- no vuelve a validar ni a interpretar
/// nada.
class PreviewBuilder {
  PreviewSummary build(List<ValidatedRecord> records, MappingResult mapping) {
    final errorRows = records.where((r) => r.hasErrors).length;
    final warningRows = records
        .where(
          (r) =>
              !r.hasErrors &&
              r.issues.any((i) => i.severity == ValidationSeverity.warning),
        )
        .length;
    final duplicateRows = records
        .expand((r) => r.issues)
        .where((i) => i.message.startsWith('Posible duplicado'))
        .length;

    return PreviewSummary(
      totalRecords: records.length,
      validRecords: records.length - errorRows,
      recordsWithErrors: errorRows,
      recordsWithWarnings: warningRows,
      duplicateRecords: duplicateRows,
      unmappedColumns: mapping.unmappedColumns,
      issues: records.expand((r) => r.issues).toList(),
    );
  }
}
