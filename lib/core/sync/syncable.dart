import '../local/database.dart';

/// Contrato que implementa cada entidad sincronizable (una tabla raíz del
/// schema local con columnas `dirty`/`deleted`/`serverId`). El [SyncEngine] no
/// conoce nada de Routines/Workouts en concreto: solo recorre una lista de
/// [SyncableEntity] y llama a estos métodos.
abstract class SyncableEntity {
  /// Nombre corto para logs/errores.
  String get name;

  /// Sube al backend todas las filas locales marcadas `dirty=true` de esta
  /// entidad (create si no tiene `serverId`, delete si `deleted=true`).
  /// Debe dejar `dirty=false` en cada fila que se subió con éxito.
  Future<void> push(AppDatabase db);
}
