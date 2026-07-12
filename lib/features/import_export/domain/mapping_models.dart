/// Campos internos a los que el AutoMapper puede resolver una columna de
/// origen. Cubre el caso de uso principal (migrar sets de entrenamiento) --
/// sumar un campo nuevo (ej. medidas corporales) es agregar un valor aca y
/// sus sinonimos en `defaultSynonyms` (`data/auto_mapper.dart`).
enum CanonicalField {
  exerciseName,
  date,
  setNumber,
  weightKg,
  reps,
  rpe,
  rir,
  restSeconds,
  notes,
  isWarmup,
  bodyWeightKg,
}

/// Resultado de mapear una columna de origen: a que [CanonicalField] quedo
/// resuelta, o `null` si el AutoMapper no encontro un sinonimo conocido (esa
/// columna requiere mapeo manual del usuario en una fase posterior, F9).
class ColumnMapping {
  final String sourceColumn;
  final CanonicalField? field;

  const ColumnMapping({required this.sourceColumn, this.field});

  bool get isMapped => field != null;
}

class MappingResult {
  final List<ColumnMapping> mappings;

  const MappingResult(this.mappings);

  List<String> get unmappedColumns =>
      mappings.where((m) => !m.isMapped).map((m) => m.sourceColumn).toList();

  CanonicalField? fieldFor(String sourceColumn) => mappings
      .firstWhere(
        (m) => m.sourceColumn == sourceColumn,
        orElse: () => ColumnMapping(sourceColumn: sourceColumn),
      )
      .field;
}
