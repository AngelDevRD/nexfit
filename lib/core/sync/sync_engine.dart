import 'dart:async';
import 'dart:developer' as developer;

import 'package:connectivity_plus/connectivity_plus.dart';
import 'package:flutter/foundation.dart' show ChangeNotifier;

import '../local/database.dart';
import 'syncable.dart';

/// Motor de sincronización genérico: recorre las [SyncableEntity] inyectadas
/// y sube lo pendiente (dirty) al backend. Se dispara al recuperar
/// conectividad y, de respaldo, con un timer periódico (por si el listener de
/// conectividad se pierde con la app en background).
///
/// `ChangeNotifier` -- antes cada falla de entidad quedaba solo en
/// `developer.log` (nadie la veía sin conectar un debugger). Eso dejó pasar
/// meses un bug real (columna faltante en Supabase, PGRST204 constante) sin
/// que nadie se enterara: ver `lastError`/`lastErrorAt`, mostrados en
/// Ajustes.
class SyncEngine extends ChangeNotifier {
  final AppDatabase db;
  final List<SyncableEntity> entities;
  Duration backupInterval;

  SyncEngine({
    required this.db,
    required this.entities,
    this.backupInterval = const Duration(hours: 3),
  });

  StreamSubscription<List<ConnectivityResult>>? _connectivitySub;
  Timer? _backupTimer;
  bool _syncing = false;

  /// Mensaje de la última falla de sync (de cualquier entidad), o null si la
  /// pasada más reciente terminó sin errores. Se limpia solo cuando una
  /// pasada completa corre sin ninguna falla -- así Ajustes deja de mostrar
  /// el aviso apenas el problema real se resuelve.
  String? lastError;
  DateTime? lastErrorAt;

  void start() {
    _connectivitySub = Connectivity().onConnectivityChanged.listen((results) {
      if (!results.contains(ConnectivityResult.none)) {
        syncNow();
      }
    });
    _backupTimer = Timer.periodic(backupInterval, (_) => syncNow());
    // Intento inicial al arrancar la app (por si ya hay conexión).
    syncNow();
  }

  /// Reinicia el timer periódico con un nuevo intervalo (ej. el usuario
  /// cambió la frecuencia en Ajustes). No afecta al listener de conectividad.
  void updateInterval(Duration newInterval) {
    if (newInterval == backupInterval) return;
    backupInterval = newInterval;
    _backupTimer?.cancel();
    _backupTimer = Timer.periodic(backupInterval, (_) => syncNow());
  }

  @override
  void dispose() {
    _connectivitySub?.cancel();
    _backupTimer?.cancel();
    super.dispose();
  }

  /// Corre una pasada de sync. Ignora llamadas concurrentes (lock simple:
  /// Dart es single-threaded en el isolate de UI, no hace falta un mutex).
  Future<void> syncNow() async {
    if (_syncing) return;
    _syncing = true;
    String? failureThisPass;
    try {
      for (final entity in entities) {
        try {
          await entity.push(db);
        } catch (e, st) {
          // Una entidad fallando (ej. sin red a mitad de camino) no debe
          // frenar a las demás -- se reintenta en la próxima pasada.
          developer.log(
            'Sync falló para ${entity.name}',
            error: e,
            stackTrace: st,
            name: 'SyncEngine',
          );
          failureThisPass = '${entity.name}: $e';
        }
      }
    } finally {
      _syncing = false;
      // Se pisa con la última falla de ESTA pasada (o se limpia si no hubo
      // ninguna) -- no acumula errores viejos ya resueltos.
      lastError = failureThisPass;
      lastErrorAt = failureThisPass != null ? DateTime.now() : lastErrorAt;
      notifyListeners();
    }
  }
}
