import 'package:excel/excel.dart';

import '../domain/export_models.dart';
import '../domain/import_export_models.dart';

/// Escribe un [ExportDataset] como .xlsx, una fila por registro mas el
/// encabezado. Convierte cada valor Dart plano al `CellValue` sellado que
/// pide el paquete `excel` -- es lo inverso de [ExcelParser._rawValue], sin
/// tomar ninguna decision de contenido.
class ExcelWriter implements FileWriter {
  @override
  ImportSourceFormat get format => ImportSourceFormat.xlsx;

  @override
  List<int> write(ExportDataset dataset) {
    final workbook = Excel.createExcel();
    final sheetName = workbook.getDefaultSheet()!;
    final sheet = workbook[sheetName];

    sheet.appendRow(dataset.columns.map((c) => TextCellValue(c)).toList());
    for (final row in dataset.rows) {
      sheet.appendRow([
        for (final column in dataset.columns) _toCellValue(row[column]),
      ]);
    }

    return workbook.save()!;
  }

  CellValue _toCellValue(dynamic value) {
    return switch (value) {
      null => TextCellValue(''),
      int v => IntCellValue(v),
      double v => DoubleCellValue(v),
      bool v => BoolCellValue(v),
      DateTime v => DateTimeCellValue.fromDateTime(v),
      _ => TextCellValue(value.toString()),
    };
  }
}
