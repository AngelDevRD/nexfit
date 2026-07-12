import 'mapping_models.dart';

enum ValidationSeverity { error, warning }

class ValidationIssue {
  final int rowIndex;
  final CanonicalField? field;
  final String message;
  final ValidationSeverity severity;

  const ValidationIssue({
    required this.rowIndex,
    this.field,
    required this.message,
    required this.severity,
  });
}

/// Un registro ya tipado a los [CanonicalField] que pudieron mapearse, mas
/// los problemas encontrados al validarlo. `values` solo contiene entradas
/// para los campos presentes en ese dataset -- no rellena con nulls los
/// campos que ni siquiera fueron mapeados.
class ValidatedRecord {
  final int rowIndex;
  final Map<CanonicalField, dynamic> values;
  final List<ValidationIssue> issues;

  const ValidatedRecord({
    required this.rowIndex,
    required this.values,
    required this.issues,
  });

  bool get hasErrors =>
      issues.any((i) => i.severity == ValidationSeverity.error);
}

/// Resumen contable para mostrarle al usuario antes de confirmar la
/// importacion (vista previa) -- construido por el PreviewBuilder a partir
/// de la lista de [ValidatedRecord].
class PreviewSummary {
  final int totalRecords;
  final int validRecords;
  final int recordsWithErrors;
  final int recordsWithWarnings;
  final int duplicateRecords;
  final List<String> unmappedColumns;
  final List<ValidationIssue> issues;

  const PreviewSummary({
    required this.totalRecords,
    required this.validRecords,
    required this.recordsWithErrors,
    required this.recordsWithWarnings,
    required this.duplicateRecords,
    required this.unmappedColumns,
    required this.issues,
  });
}
