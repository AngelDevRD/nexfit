/// Contratos de dominio del ImportExportModule (Fase 1: File Reader + Parser).
///
/// El resto de fases (Mapper, Preview, Import/Export Engine, Conflict
/// Resolver) se construyen sobre [ParsedDataset] y [FileParser] sin depender
/// de ningun formato concreto -- agregar un formato nuevo es implementar
/// [FileParser] y registrarlo en `FileReader`, sin tocar el nucleo.
library;

enum ImportSourceFormat { csv, xlsx, xls, json, zip, unknown }

ImportSourceFormat sourceFormatFromExtension(String fileName) {
  final ext = fileName.toLowerCase().split('.').last;
  switch (ext) {
    case 'csv':
      return ImportSourceFormat.csv;
    case 'xlsx':
      return ImportSourceFormat.xlsx;
    case 'xls':
      return ImportSourceFormat.xls;
    case 'json':
      return ImportSourceFormat.json;
    case 'zip':
      return ImportSourceFormat.zip;
    default:
      return ImportSourceFormat.unknown;
  }
}

/// Una fila cruda tal cual vino del archivo origen, sin mapear a campos
/// internos todavia (eso lo hace el Mapper en una fase posterior).
class RawRecord {
  final int rowIndex;
  final Map<String, dynamic> values;

  const RawRecord({required this.rowIndex, required this.values});
}

/// Resultado de parsear un archivo: columnas detectadas + filas crudas.
class ParsedDataset {
  final ImportSourceFormat format;
  final String sourceFileName;
  final List<String> columns;
  final List<RawRecord> records;

  const ParsedDataset({
    required this.format,
    required this.sourceFileName,
    required this.columns,
    required this.records,
  });
}

/// Contrato que debe implementar cada parser de formato (CSV, XLSX, JSON...).
///
/// Cada implementacion es independiente y desacoplada del resto del modulo
/// (principio de responsabilidad unica): solo sabe convertir bytes crudos de
/// un formato especifico en un [ParsedDataset].
abstract class FileParser {
  ImportSourceFormat get format;

  Future<ParsedDataset> parse({
    required String fileName,
    required List<int> bytes,
  });
}

class UnsupportedFormatException implements Exception {
  final String fileName;
  final ImportSourceFormat format;

  UnsupportedFormatException(this.fileName, this.format);

  @override
  String toString() =>
      'No hay un parser registrado para "$fileName" (formato: $format)';
}
