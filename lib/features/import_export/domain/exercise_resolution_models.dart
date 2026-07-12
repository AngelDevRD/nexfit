/// Un ejercicio de texto libre (extraido del archivo importado) que no pudo
/// resolverse contra el catalogo local, agrupado por nombre normalizado para
/// no pedirle al usuario que decida lo mismo mas de una vez -- "Bench Press",
/// "bench press" y "Bench  Press" (mayusculas/espacios distintos) son el
/// mismo grupo, no tres.
///
/// [key] es el nombre normalizado ([normalizeHeader]), usado para
/// correlacionar la decision del usuario ([ExerciseResolutionChoice]) de
/// vuelta con este grupo. [name] es el texto tal como aparecio la primera
/// vez en el archivo, para mostrarselo al usuario.
class UnresolvedExerciseGroup {
  final String key;
  final String name;
  final List<int> rowIndexes;

  const UnresolvedExerciseGroup({
    required this.key,
    required this.name,
    required this.rowIndexes,
  });
}

/// Una opcion del catalogo para el selector de asociacion manual.
class CatalogExerciseOption {
  final int id;
  final String name;

  const CatalogExerciseOption({required this.id, required this.name});
}

enum ExerciseResolutionAction { ignore, createNew, mapExisting }

/// Decision del usuario para un [UnresolvedExerciseGroup] puntual, tomada en
/// la pantalla de resolucion (asistente de un solo dialogo).
class ExerciseResolutionChoice {
  final ExerciseResolutionAction action;
  final int? mappedExerciseId;

  const ExerciseResolutionChoice.ignore()
    : action = ExerciseResolutionAction.ignore,
      mappedExerciseId = null;

  const ExerciseResolutionChoice.createNew()
    : action = ExerciseResolutionAction.createNew,
      mappedExerciseId = null;

  const ExerciseResolutionChoice.mapExisting(int exerciseId)
    : action = ExerciseResolutionAction.mapExisting,
      mappedExerciseId = exerciseId;
}
