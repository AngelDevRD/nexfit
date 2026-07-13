/// Parseo de fecha reusado por cualquier flujo que reciba fechas de texto
/// libre desde un archivo externo (hoy: el importador de entrenamientos y el
/// de medidas corporales). Entiende ISO-8601 (via `DateTime.tryParse`) o el
/// formato "d MMM yyyy, HH:mm" con mes abreviado en espanol que exportan
/// Hevy/Strong/Renpho (ej. "10 jul 2026, 15:44").
///
/// Limitacion conocida: formatos regionales ambiguos como "12/07/2026"
/// (dia/mes vs. mes/dia) quedan sin soporte -- resolverlos requeriria un
/// parser de fechas configurable, fuera de alcance actual.
DateTime? parseFlexibleDate(String text) {
  return DateTime.tryParse(text) ?? _parseSpanishDateTime(text);
}

const _monthAbbreviations = {
  'ene': 1,
  'feb': 2,
  'mar': 3,
  'abr': 4,
  'may': 5,
  'jun': 6,
  'jul': 7,
  'ago': 8,
  'sep': 9,
  'set': 9,
  'oct': 10,
  'nov': 11,
  'dic': 12,
};

final _spanishDateTimePattern = RegExp(
  r'^(\d{1,2})\s+([a-zA-Z]{3})\.?\s+(\d{4}),?\s+(\d{1,2}):(\d{2})$',
);

DateTime? _parseSpanishDateTime(String text) {
  final match = _spanishDateTimePattern.firstMatch(text.trim());
  if (match == null) return null;
  final month = _monthAbbreviations[match.group(2)!.toLowerCase()];
  if (month == null) return null;
  return DateTime(
    int.parse(match.group(3)!),
    month,
    int.parse(match.group(1)!),
    int.parse(match.group(4)!),
    int.parse(match.group(5)!),
  );
}
