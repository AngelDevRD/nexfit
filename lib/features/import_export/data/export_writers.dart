import 'dart:convert';

import 'package:csv/csv.dart';

import '../domain/export_models.dart';
import '../domain/import_export_models.dart';

/// Escribe un [ExportDataset] como CSV UTF-8, con `eol: '\n'` explicito
/// (misma disciplina que el fix de [CsvParser] -- nunca depender del
/// default `\r\n` del paquete).
class CsvWriter implements FileWriter {
  @override
  ImportSourceFormat get format => ImportSourceFormat.csv;

  @override
  List<int> write(ExportDataset dataset) {
    final rows = [
      dataset.columns,
      for (final row in dataset.rows)
        [for (final column in dataset.columns) row[column] ?? ''],
    ];
    final csv = const ListToCsvConverter(eol: '\n').convert(rows);
    return utf8.encode(csv);
  }
}

/// Escribe un [ExportDataset] como JSON: una lista de objetos, una entrada
/// por fila, con las mismas claves que [exportColumns] -- mismo caso
/// "raiz es una lista" que ya entiende [JsonParser] al reimportar.
class JsonWriter implements FileWriter {
  @override
  ImportSourceFormat get format => ImportSourceFormat.json;

  @override
  List<int> write(ExportDataset dataset) {
    final json = jsonEncode(dataset.rows);
    return utf8.encode(json);
  }
}
