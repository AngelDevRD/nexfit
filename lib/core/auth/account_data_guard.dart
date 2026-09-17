import 'package:drift/drift.dart';
import 'package:shared_preferences/shared_preferences.dart';

import '../local/database.dart';

const _lastUserIdPrefsKey = 'account_data_guard.last_user_id';

/// Id a partir del cual arrancan los ejercicios propios del usuario (ver
/// `ExerciseRepository.customExerciseIdStart`). Duplicado -- mismo patrón que
/// `core/sync/entities/exercise_syncable.dart` -- para no acoplar `core/` a
/// la capa de repositorios.
const _customExerciseIdStart = 1000000;

/// Aísla los datos locales por cuenta (hallazgo C1/S1 de
/// docs/AUDITORIA_2026-09-16_SUPERVISOR.md; decisión D4 del dueño): si en
/// este teléfono entra una cuenta DISTINTA a la última que se usó, se
/// limpian los datos locales antes de considerar la cuenta nueva "lista"
/// para mostrarse o sincronizar. Si es la primera cuenta de una instalación
/// existente, o vuelve a entrar la misma, los datos se conservan.
class AccountDataGuard {
  AccountDataGuard(this._db);

  final AppDatabase _db;

  bool _preparing = false;
  String? _readyForUserId;

  /// Prepara la base local para [userId]. Devuelve `true` si limpió datos
  /// de una cuenta distinta a la anterior.
  ///
  /// Marca el estado "en preparación" de forma SÍNCRONA (antes del primer
  /// `await`) para que [isReadyFor] ya lo refleje aunque el llamador no
  /// espere a que termine esta función.
  Future<bool> prepareForUser(String userId) async {
    _preparing = true;
    _readyForUserId = null;

    final prefs = await SharedPreferences.getInstance();
    final lastUserId = prefs.getString(_lastUserIdPrefsKey);

    var wiped = false;
    if (lastUserId != null && lastUserId != userId) {
      await _db.clearAllData();
      wiped = true;
    }
    await prefs.setString(_lastUserIdPrefsKey, userId);

    _readyForUserId = userId;
    _preparing = false;
    return wiped;
  }

  /// `true` solo si [userId] no es null, no hay una preparación en curso y
  /// coincide con la cuenta ya preparada en ESTA instancia del guard.
  bool isReadyFor(String? userId) =>
      userId != null && !_preparing && _readyForUserId == userId;

  /// Cambios locales que el `SyncEngine` todavía no subió: filas `dirty` de
  /// las entidades sincronizables más las operaciones de serie pendientes.
  /// `BodyMeasurements` es solo local (sin `dirty`/`serverId`) y no cuenta.
  Future<int> unsyncedChangesCount() async {
    Future<int> dirtyCount<T extends Table, D>(
      TableInfo<T, D> table,
      Expression<bool> Function(T) predicate,
    ) async => (await (_db.select(table)..where(predicate)).get()).length;

    final routines = await dirtyCount(_db.routines, (t) => t.dirty.equals(true));
    final sessions = await dirtyCount(
      _db.workoutSessions,
      (t) => t.dirty.equals(true),
    );
    final goals = await dirtyCount(_db.goals, (t) => t.dirty.equals(true));
    final nutritionLogs = await dirtyCount(
      _db.nutritionLogs,
      (t) => t.dirty.equals(true),
    );
    final dailyCheckins = await dirtyCount(
      _db.dailyCheckins,
      (t) => t.dirty.equals(true),
    );
    final profiles = await dirtyCount(_db.profiles, (t) => t.dirty.equals(true));
    final customExercises = await dirtyCount(
      _db.exercises,
      (t) =>
          t.dirty.equals(true) &
          t.id.isBiggerOrEqualValue(_customExerciseIdStart),
    );
    final pendingSetOps = (await _db.select(_db.pendingSetOps).get()).length;

    return routines +
        sessions +
        goals +
        nutritionLogs +
        dailyCheckins +
        profiles +
        customExercises +
        pendingSetOps;
  }
}
