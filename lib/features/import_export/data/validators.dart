import '../../../core/date_parsing.dart';
import '../domain/import_export_models.dart';
import '../domain/mapping_models.dart';
import '../domain/validation_models.dart';

/// Tipa y valida cada [RawRecord] segun el [MappingResult] del AutoMapper:
/// convierte el valor crudo al tipo esperado por su [CanonicalField] y
/// detecta fechas invalidas, negativos, campos obligatorios vacios y datos
/// corruptos (no se puede convertir al tipo esperado). No corrige nada por
/// su cuenta -- si algo no se puede tipar de forma segura, lo reporta como
/// error en vez de adivinar un valor.
///
/// El parseo de fecha (ISO-8601 o "d MMM yyyy, HH:mm" en espanol) vive en
/// [parseFlexibleDate] (`core/date_parsing.dart`), compartido con el
/// importador de medidas corporales.
class Validators {
  List<ValidatedRecord> validate(ParsedDataset dataset, MappingResult mapping) {
    final records = <ValidatedRecord>[];
    final seenKeys = <String, int>{};

    for (final raw in dataset.records) {
      final values = <CanonicalField, dynamic>{};
      final issues = <ValidationIssue>[];

      for (final column in dataset.columns) {
        final field = mapping.fieldFor(column);
        if (field == null) continue;
        final rawValue = raw.values[column];
        final coerced = _coerce(field, rawValue, raw.rowIndex, issues);
        if (coerced != null) values[field] = coerced;
      }

      if (!values.containsKey(CanonicalField.exerciseName)) {
        issues.add(
          ValidationIssue(
            rowIndex: raw.rowIndex,
            field: CanonicalField.exerciseName,
            message: 'Falta el nombre del ejercicio (campo obligatorio)',
            severity: ValidationSeverity.error,
          ),
        );
      }

      final dupKey = _duplicateKey(values);
      if (dupKey != null) {
        if (seenKeys.containsKey(dupKey)) {
          issues.add(
            ValidationIssue(
              rowIndex: raw.rowIndex,
              message:
                  'Posible duplicado de la fila ${seenKeys[dupKey]} '
                  '(mismo ejercicio/fecha/serie)',
              severity: ValidationSeverity.warning,
            ),
          );
        } else {
          seenKeys[dupKey] = raw.rowIndex;
        }
      }

      records.add(
        ValidatedRecord(rowIndex: raw.rowIndex, values: values, issues: issues),
      );
    }

    return records;
  }

  dynamic _coerce(
    CanonicalField field,
    dynamic rawValue,
    int rowIndex,
    List<ValidationIssue> issues,
  ) {
    final text = rawValue?.toString().trim();
    if (rawValue == null || text == null || text.isEmpty) return null;

    switch (field) {
      case CanonicalField.exerciseName:
      case CanonicalField.notes:
        return text;

      case CanonicalField.date:
        final date = _toDateTime(rawValue, text);
        if (date == null) {
          issues.add(
            ValidationIssue(
              rowIndex: rowIndex,
              field: field,
              message: 'Fecha invalida: "$text"',
              severity: ValidationSeverity.error,
            ),
          );
          return null;
        }
        return date;

      case CanonicalField.weightKg:
      case CanonicalField.bodyWeightKg:
        return _positiveNum(field, text, rowIndex, issues, allowZero: true);

      case CanonicalField.reps:
      case CanonicalField.setNumber:
      case CanonicalField.restSeconds:
      case CanonicalField.rir:
        return _positiveInt(field, text, rowIndex, issues);

      case CanonicalField.rpe:
        return _positiveNum(field, text, rowIndex, issues, allowZero: true);

      case CanonicalField.isWarmup:
        return text.toLowerCase() == 'true' ||
            text == '1' ||
            text.toLowerCase() == 'si' ||
            text.toLowerCase() == 'yes' ||
            text.toLowerCase() == 'warmup';
    }
  }

  DateTime? _toDateTime(dynamic rawValue, String text) {
    if (rawValue is DateTime) return rawValue;
    return parseFlexibleDate(text);
  }

  num? _positiveNum(
    CanonicalField field,
    String text,
    int rowIndex,
    List<ValidationIssue> issues, {
    required bool allowZero,
  }) {
    final value = num.tryParse(text.replaceAll(',', '.'));
    if (value == null) {
      issues.add(
        ValidationIssue(
          rowIndex: rowIndex,
          field: field,
          message: 'Dato corrupto, no es un numero: "$text"',
          severity: ValidationSeverity.error,
        ),
      );
      return null;
    }
    if (value < 0 || (!allowZero && value == 0)) {
      issues.add(
        ValidationIssue(
          rowIndex: rowIndex,
          field: field,
          message: 'Valor negativo no permitido: $value',
          severity: ValidationSeverity.error,
        ),
      );
      return null;
    }
    return value;
  }

  int? _positiveInt(
    CanonicalField field,
    String text,
    int rowIndex,
    List<ValidationIssue> issues,
  ) {
    final value = _positiveNum(field, text, rowIndex, issues, allowZero: true);
    if (value == null) return null;
    return value.round();
  }

  String? _duplicateKey(Map<CanonicalField, dynamic> values) {
    final name = values[CanonicalField.exerciseName];
    if (name == null) return null;
    final date = values[CanonicalField.date];
    final setNumber = values[CanonicalField.setNumber];
    if (date == null && setNumber == null) return null;
    return '$name|$date|$setNumber';
  }
}
