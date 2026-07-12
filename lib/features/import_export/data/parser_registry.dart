import '../domain/import_export_models.dart';
import 'csv_parser.dart';
import 'excel_parser.dart';
import 'json_parser.dart';

/// Punto unico de registro de parsers para `FileReader`.
///
/// Sumar un formato nuevo (ZIP, un importador especifico de otra app) es
/// agregar su [FileParser] a esta lista -- `FileReader` nunca se modifica.
List<FileParser> defaultFileParsers() => [
  CsvParser(),
  ExcelParser(ImportSourceFormat.xlsx),
  ExcelParser(ImportSourceFormat.xls),
  JsonParser(),
];
