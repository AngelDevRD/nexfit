import 'dart:convert';

import 'package:csv/csv.dart';

import '../domain/import_export_models.dart';

/// Extrae filas de un archivo CSV tal cual vienen en el archivo, sin ninguna
/// interpretacion semantica (sin inferir tipos, unidades, fechas ni
/// sinonimos de columnas). Todo eso es responsabilidad de fases
/// posteriores: AutoMapper, Validators, ConflictResolver.
///
/// Todos los valores quedan como String literal (shouldParseNumbers: false)
/// para no tomar ninguna decision de tipo por el parser.
class CsvParser implements FileParser {
  @override
  ImportSourceFormat get format => ImportSourceFormat.csv;

  @override
  Future<ParsedDataset> parse({
    required String fileName,
    required List<int> bytes,
  }) async {
    final content = _normalizeLineEndings(_decode(bytes));
    final rows = const CsvToListConverter(
      shouldParseNumbers: false,
      eol: '\n',
    ).convert(content);

    if (rows.isEmpty) {
      return ParsedDataset(
        format: format,
        sourceFileName: fileName,
        columns: const [],
        records: const [],
      );
    }

    final columns = rows.first.map((cell) => cell.toString()).toList();
    final records = <RawRecord>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final values = <String, dynamic>{};
      for (var col = 0; col < columns.length; col++) {
        values[columns[col]] = col < row.length ? row[col] : null;
      }
      records.add(RawRecord(rowIndex: i, values: values));
    }

    return ParsedDataset(
      format: format,
      sourceFileName: fileName,
      columns: columns,
      records: records,
    );
  }

  String _decode(List<int> bytes) {
    try {
      return utf8.decode(bytes);
    } on FormatException {
      return latin1.decode(bytes);
    }
  }

  /// El paquete `csv` espera un unico `eol` fijo; sin esto, un archivo con
  /// saltos de linea Unix-only (`\n`, tipico de Sheets/Mac/Linux) se
  /// parseaba como una sola fila gigante porque el default del paquete es
  /// `\r\n`. Normalizar antes de convertir soporta ambos estilos de salto
  /// de linea sin tener que autodetectar nada.
  String _normalizeLineEndings(String content) =>
      content.replaceAll('\r\n', '\n').replaceAll('\r', '\n');
}
