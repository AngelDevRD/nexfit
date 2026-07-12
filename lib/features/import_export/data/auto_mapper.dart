import '../domain/mapping_models.dart';

/// Diccionario de sinonimos configurable: cada [CanonicalField] tiene una
/// lista de variantes de encabezado (en distintos idiomas/apps) que deben
/// resolver a ese campo. Normalizado a minusculas/sin acentos/sin
/// espacios extra por [normalizeHeader] antes de comparar.
///
/// Sumar un sinonimo nuevo (o un formato de otra app) es agregar una entrada
/// aca, o pasar un mapa propio a `AutoMapper(synonyms: ...)` -- no hace
/// falta tocar la logica de [AutoMapper].
final Map<CanonicalField, List<String>> defaultSynonyms = {
  CanonicalField.exerciseName: [
    'exercise',
    'exercise name',
    'ejercicio',
    'nombre ejercicio',
    'movement',
    'lift',
  ],
  CanonicalField.date: [
    'date',
    'fecha',
    'workout date',
    'session date',
    'fecha entrenamiento',
  ],
  CanonicalField.setNumber: [
    'set',
    'sets',
    'set number',
    'serie',
    'series',
    'numero de serie',
  ],
  CanonicalField.weightKg: [
    'weight',
    'peso',
    'kg',
    'kilograms',
    'carga',
    'load',
    'weight kg',
  ],
  CanonicalField.reps: [
    'reps',
    'repeticiones',
    'rep',
    'repetition',
    'repetitions',
  ],
  CanonicalField.rpe: ['rpe', 'esfuerzo percibido'],
  CanonicalField.rir: ['rir', 'reps in reserve', 'reps en reserva'],
  CanonicalField.restSeconds: [
    'rest',
    'rest seconds',
    'descanso',
    'tiempo de descanso',
    'rest time',
  ],
  CanonicalField.notes: ['notes', 'notas', 'comment', 'comentario'],
  CanonicalField.isWarmup: ['warmup', 'calentamiento', 'is warmup'],
  CanonicalField.bodyWeightKg: [
    'bodyweight',
    'body weight',
    'peso corporal',
    'peso corporal kg',
  ],
};

/// Normaliza un encabezado para comparar contra el diccionario de
/// sinonimos: minusculas, sin acentos, espacios/guiones/guiones bajos
/// colapsados a un solo espacio, sin espacios en los extremos. Es
/// normalizacion de texto, no interpretacion de significado.
String normalizeHeader(String header) {
  const accented = 'áéíóúüñÁÉÍÓÚÜÑ';
  const plain = 'aeiouunAEIOUUN';
  var result = header.trim().toLowerCase();
  for (var i = 0; i < accented.length; i++) {
    result = result.replaceAll(accented[i], plain[i]);
  }
  result = result.replaceAll(RegExp(r'[_\-]+'), ' ');
  result = result.replaceAll(RegExp(r'\s+'), ' ').trim();
  return result;
}

/// Resuelve automaticamente cada columna de un dataset a un [CanonicalField]
/// conocido via el diccionario de sinonimos. No adivina: si una columna no
/// tiene un sinonimo exacto registrado, queda sin mapear (`field: null`)
/// para que una fase posterior (mapeo manual, F9) la resuelva con el
/// usuario -- nunca se infiere un campo por similitud parcial.
class AutoMapper {
  final Map<CanonicalField, List<String>> synonyms;
  late final Map<String, CanonicalField> _lookup = {
    for (final entry in synonyms.entries)
      for (final synonym in entry.value) normalizeHeader(synonym): entry.key,
  };

  AutoMapper({Map<CanonicalField, List<String>>? synonyms})
    : synonyms = synonyms ?? defaultSynonyms;

  MappingResult map(List<String> columns) {
    return MappingResult([
      for (final column in columns)
        ColumnMapping(
          sourceColumn: column,
          field: _lookup[normalizeHeader(column)],
        ),
    ]);
  }
}
