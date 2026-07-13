import '../../../core/date_parsing.dart';
import '../../import_export/domain/import_export_models.dart';
import 'measurement_mapper.dart';

/// Una fila ya tipada de medidas corporales: fecha resuelta + los campos
/// numericos reconocidos ([fields], claves = las de
/// `BodyMeasurementRepository.upsertForDate`). [error] es `null` si la fila
/// es valida.
class MeasurementRow {
  final int rowIndex;
  final DateTime? date;
  final Map<String, double?> fields;
  final String? error;

  const MeasurementRow({
    required this.rowIndex,
    required this.date,
    required this.fields,
    this.error,
  });

  bool get isValid => error == null && date != null;
}

/// Tipa cada fila de un dataset de medidas corporales: exige fecha valida
/// (via [parseFlexibleDate], compartido con el importador de F9), el resto
/// de los campos son opcionales -- a diferencia de F9 no hay ningun campo de
/// texto obligatorio como `exerciseName`.
class MeasurementValidator {
  List<MeasurementRow> validate(ParsedDataset dataset) {
    final columnMap = mapMeasurementColumns(dataset.columns);

    return [for (final raw in dataset.records) _validateRow(raw, columnMap)];
  }

  MeasurementRow _validateRow(RawRecord raw, Map<String, String> columnMap) {
    dynamic dateRaw;
    final fields = <String, double?>{};
    String? error;

    for (final entry in columnMap.entries) {
      final value = raw.values[entry.key];
      if (entry.value == 'date') {
        dateRaw = value;
        continue;
      }
      final text = value?.toString().trim();
      if (text == null || text.isEmpty) continue;

      final parsed = double.tryParse(text.replaceAll(',', '.'));
      if (parsed == null) {
        error ??= 'Dato corrupto en "${entry.value}": "$text"';
        continue;
      }
      if (parsed < 0) {
        error ??= 'Valor negativo no permitido en "${entry.value}": $parsed';
        continue;
      }
      fields[entry.value] = parsed;
    }

    final dateText = dateRaw?.toString().trim();
    DateTime? date;
    if (dateText == null || dateText.isEmpty) {
      error ??= 'Falta la fecha (campo obligatorio)';
    } else {
      date = dateRaw is DateTime ? dateRaw : parseFlexibleDate(dateText);
      if (date == null) error ??= 'Fecha invalida: "$dateText"';
    }

    return MeasurementRow(
      rowIndex: raw.rowIndex,
      date: date,
      fields: fields,
      error: error,
    );
  }
}
