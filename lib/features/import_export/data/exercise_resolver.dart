import '../../../core/local/database.dart' as local;
import '../../../repositories/exercise_repository.dart';
import '../domain/exercise_resolution_models.dart';
import 'auto_mapper.dart' show normalizeHeader;

/// Resuelve un `exerciseName` de texto libre (extraido de un archivo
/// importado) al id de un ejercicio existente en el catalogo local
/// (`db.exercises`), por coincidencia exacta normalizada de nombre o slug.
///
/// A proposito NO hace fuzzy matching ni similitud parcial -- misma
/// disciplina de "no adivinar" que el AutoMapper: si el nombre no coincide
/// exactamente (normalizado) con ningun ejercicio del catalogo, se reporta
/// como no resuelto en vez de asumir cual quiso decir el usuario. Reusa
/// [normalizeHeader] del AutoMapper para no duplicar la logica de
/// normalizacion de texto.
///
/// Los ejercicios sin correspondencia no se descartan solos: la pantalla de
/// resolucion (import_flow_provider) le pregunta al usuario que hacer y
/// aplica la decision aca via [applyManualMapping] o [createExercise] antes
/// de que el ImportEngine vuelva a llamar a [resolve].
class ExerciseResolver {
  final local.AppDatabase db;
  Map<String, int>? _cache;

  ExerciseResolver(this.db);

  Future<int?> resolve(String exerciseName) async {
    final cache = await _ensureCache();
    return cache[normalizeHeader(exerciseName)];
  }

  Future<List<CatalogExerciseOption>> listCatalog() async {
    final rows = await db.select(db.exercises).get();
    return [
      for (final row in rows) CatalogExerciseOption(id: row.id, name: row.name),
    ]..sort((a, b) => a.name.compareTo(b.name));
  }

  /// Asocia manualmente `exerciseName` (tal como aparecio en el archivo
  /// importado) a un ejercicio existente del catalogo. Queda resuelto para
  /// el resto de esta importacion.
  ///
  /// Alcance actual (F9): el mapeo solo vive en el cache en memoria de esta
  /// instancia, es decir, dura lo que dura la importacion en curso. Si una
  /// version futura (F10/F11) necesita recordar "Bench Press" -> "Press de
  /// banca" entre importaciones, el punto de extension es este metodo: se
  /// agregaria una escritura a una tabla/repositorio nuevo (p.ej. un
  /// `ExerciseAliasRepository` con una tabla `exercise_aliases` en
  /// `database.dart`) aca mismo, y [_ensureCache] la precargaria junto con
  /// el catalogo al construir el cache -- sin tocar el resto del modulo.
  Future<void> applyManualMapping(String exerciseName, int exerciseId) async {
    final cache = await _ensureCache();
    cache[normalizeHeader(exerciseName)] = exerciseId;
  }

  /// Crea un ejercicio nuevo en el catalogo local a partir de un nombre
  /// importado que no tenia correspondencia, con categoria "Sin clasificar"
  /// y el minimo de datos necesario. Delega en `ExerciseRepository` (E1):
  /// es el punto unico de escritura del catalogo, con la misma estrategia
  /// de ids (fuera del rango del catalogo semilla) para ejercicios creados
  /// desde la app o desde una importacion.
  Future<int> createExercise(String exerciseName) async {
    final cache = await _ensureCache();
    final id = await ExerciseRepository(db).createExercise(
      name: exerciseName,
      muscleGroup: 'Sin clasificar',
      equipment: const [],
      movementType: '',
    );
    cache[normalizeHeader(exerciseName)] = id;
    return id;
  }

  Future<Map<String, int>> _ensureCache() async {
    final cached = _cache;
    if (cached != null) return cached;

    final rows = await db.select(db.exercises).get();
    final map = <String, int>{};
    for (final row in rows) {
      map[normalizeHeader(row.name)] = row.id;
      map.putIfAbsent(normalizeHeader(row.slug), () => row.id);
    }
    _cache = map;
    return map;
  }
}
