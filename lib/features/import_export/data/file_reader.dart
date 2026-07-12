import 'dart:io';

import '../domain/import_export_models.dart';

/// Punto de entrada del ImportExportModule: recibe un path de archivo,
/// detecta el formato por extension y delega el parseo al [FileParser]
/// registrado correspondiente.
///
/// Registry pattern (AG-CORE / SOLID - Open/Closed): sumar un formato nuevo
/// (Excel, ZIP, un importador especifico de otra app) es agregar un
/// [FileParser] a la lista al construir `FileReader`, sin modificar esta
/// clase.
class FileReader {
  final Map<ImportSourceFormat, FileParser> _parsers;

  FileReader(List<FileParser> parsers)
    : _parsers = {for (final p in parsers) p.format: p};

  Future<ParsedDataset> readFile(String path) async {
    final file = File(path);
    if (!await file.exists()) {
      throw FileSystemException('Archivo no encontrado', path);
    }

    final fileName = file.uri.pathSegments.last;
    final format = sourceFormatFromExtension(fileName);
    final parser = _parsers[format];
    if (parser == null) {
      throw UnsupportedFormatException(fileName, format);
    }

    final bytes = await file.readAsBytes();
    return parser.parse(fileName: fileName, bytes: bytes);
  }
}
