import 'dart:convert';

import '../domain/import_export_models.dart';

/// Extrae registros de un archivo JSON tal cual vienen, sin interpretacion
/// semantica: los valores quedan con el tipo que trae `jsonDecode` (String,
/// num, bool, null, List, Map), sin inferir unidades, fechas ni sinonimos de
/// claves. Misma disciplina que [CsvParser]/[ExcelParser].
///
/// A diferencia de CSV/Excel, JSON no es intrinsecamente tabular, asi que el
/// parser solo hace la navegacion estructural minima indispensable para
/// encontrar la lista de registros (no elige significado de campos):
/// - Si la raiz es una lista -> cada elemento es un registro.
/// - Si la raiz es un objeto con una unica propiedad que es una lista de
///   objetos -> esa lista son los registros (ej. `{"workouts": [...]}`).
/// - Si la raiz es un objeto sin ninguna propiedad-lista-de-objetos -> el
///   objeto entero es un unico registro.
/// - Si hay mas de una propiedad-lista-de-objetos, es ambiguo: se rechaza en
///   vez de adivinar cual es la correcta.
class JsonParser implements FileParser {
  @override
  ImportSourceFormat get format => ImportSourceFormat.json;

  @override
  Future<ParsedDataset> parse({
    required String fileName,
    required List<int> bytes,
  }) async {
    final decoded = jsonDecode(utf8.decode(bytes));
    final rawRecords = _extractRecordMaps(decoded, fileName);

    final columns = <String>[];
    for (final map in rawRecords) {
      for (final key in map.keys) {
        if (!columns.contains(key)) columns.add(key);
      }
    }

    final records = <RawRecord>[
      for (var i = 0; i < rawRecords.length; i++)
        RawRecord(rowIndex: i, values: rawRecords[i]),
    ];

    return ParsedDataset(
      format: format,
      sourceFileName: fileName,
      columns: columns,
      records: records,
    );
  }

  List<Map<String, dynamic>> _extractRecordMaps(
    dynamic decoded,
    String fileName,
  ) {
    if (decoded is List) {
      return decoded.map(_asRecordMap).toList();
    }

    if (decoded is Map<String, dynamic>) {
      final listProperties = decoded.entries
          .where((e) => e.value is List && _isListOfObjects(e.value as List))
          .toList();

      if (listProperties.length == 1) {
        return (listProperties.first.value as List).map(_asRecordMap).toList();
      }
      if (listProperties.isEmpty) {
        return [decoded];
      }
      throw JsonAmbiguousStructureException(
        fileName,
        listProperties.map((e) => e.key).toList(),
      );
    }

    throw JsonAmbiguousStructureException(fileName, const []);
  }

  bool _isListOfObjects(List list) =>
      list.isNotEmpty && list.every((e) => e is Map<String, dynamic>);

  Map<String, dynamic> _asRecordMap(dynamic item) {
    if (item is Map<String, dynamic>) return item;
    throw FormatException('Se esperaba un objeto JSON, se encontro: $item');
  }
}

class JsonAmbiguousStructureException implements Exception {
  final String fileName;
  final List<String> candidateKeys;

  JsonAmbiguousStructureException(this.fileName, this.candidateKeys);

  @override
  String toString() => candidateKeys.isEmpty
      ? 'No se encontraron registros interpretables en "$fileName"'
      : 'Estructura ambigua en "$fileName": mas de una lista de registros '
            'posible (${candidateKeys.join(", ")}). Requiere mapeo manual.';
}
