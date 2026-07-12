import 'package:excel/excel.dart';

import '../domain/import_export_models.dart';

/// Extrae filas de la primera hoja con datos de un archivo Excel (.xlsx/.xls
/// via el mismo decoder), sin ninguna interpretacion semantica -- misma
/// disciplina que [CsvParser]: la primera fila son encabezados, cada celda
/// se conserva con el valor que trae el paquete `excel` (String/num/bool
/// segun el tipo real de la celda), sin inferir unidades, fechas ni
/// sinonimos de columnas. Un mismo parser cubre .xlsx y .xls porque el
/// paquete `excel` decodifica ambos formatos con la misma API.
class ExcelParser implements FileParser {
  final ImportSourceFormat _format;

  ExcelParser([this._format = ImportSourceFormat.xlsx]);

  @override
  ImportSourceFormat get format => _format;

  @override
  Future<ParsedDataset> parse({
    required String fileName,
    required List<int> bytes,
  }) async {
    final workbook = Excel.decodeBytes(bytes);
    if (workbook.tables.isEmpty) {
      return ParsedDataset(
        format: format,
        sourceFileName: fileName,
        columns: const [],
        records: const [],
      );
    }

    final sheet = workbook.tables[workbook.tables.keys.first]!;
    final rows = sheet.rows;
    if (rows.isEmpty) {
      return ParsedDataset(
        format: format,
        sourceFileName: fileName,
        columns: const [],
        records: const [],
      );
    }

    final columns = rows.first
        .map((cell) => (_rawValue(cell?.value)?.toString() ?? '').trim())
        .toList();

    final records = <RawRecord>[];
    for (var i = 1; i < rows.length; i++) {
      final row = rows[i];
      final values = <String, dynamic>{};
      for (var col = 0; col < columns.length; col++) {
        values[columns[col]] = col < row.length
            ? _rawValue(row[col]?.value)
            : null;
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

  /// Desempaqueta el `CellValue` sellado del paquete `excel` a un tipo Dart
  /// plano (String/int/double/bool/DateTime), para que el modelo canonico
  /// (`RawRecord.values`) nunca exponga tipos propios de una libreria de
  /// terceros. Es una conversion de representacion, no una interpretacion:
  /// no decide unidades ni corrige nada, solo desenvuelve el valor tal cual
  /// esta guardado en la celda.
  dynamic _rawValue(CellValue? cell) {
    return switch (cell) {
      null => null,
      TextCellValue v => v.value.toString(),
      IntCellValue v => v.value,
      DoubleCellValue v => v.value,
      BoolCellValue v => v.value,
      DateCellValue v => v.asDateTimeUtc(),
      DateTimeCellValue v => v.asDateTimeUtc(),
      TimeCellValue v => v.toString(),
      FormulaCellValue v => v.formula,
    };
  }
}
