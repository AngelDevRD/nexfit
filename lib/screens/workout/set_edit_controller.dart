import 'dart:async';

/// T-H3 (docs/AUDITORIA_2026-09-16_SUPERVISOR.md): saca de
/// `ActiveWorkoutScreen` el debounce de edición de series, para que `flush`
/// pueda esperar TAMBIÉN la escritura que el debounce ya disparó y sigue en
/// vuelo. Antes, tocar el check mientras esa escritura estaba en curso hacía
/// que `setCompleted` leyera el peso/reps viejo -- récord y XP evaluados
/// contra un valor que ya no era el que se veía en pantalla.
///
/// Por serie (`setId`): [queue] acumula campos y reinicia su debounce;
/// [flush] cancela el debounce, escribe lo pendiente y encadena/espera la
/// escritura en vuelo de esa serie (haya sido disparada por el debounce o
/// por un `flush` anterior). Los errores de [write] se propagan a quien
/// llamó `flush`, sin trabar escrituras posteriores de la misma serie.
class SetEditController {
  SetEditController({
    required this.write,
    this.debounce = const Duration(milliseconds: 500),
  });

  final Future<void> Function(int setId, Map<String, num> payload) write;
  final Duration debounce;

  final _pending = <int, Map<String, num>>{};
  final _timers = <int, Timer>{};
  final _inFlight = <int, Future<void>>{};

  void queue(int setId, String field, num value) {
    (_pending[setId] ??= {})[field] = value;
    _timers.remove(setId)?.cancel();
    _timers[setId] = Timer(debounce, () => _fire(setId));
  }

  void _fire(int setId) {
    _timers.remove(setId);
    final payload = _pending.remove(setId);
    if (payload == null || payload.isEmpty) return;
    // `..catchError` se suscribe al error para que Dart no lo marque como
    // "no manejado" si nadie vuelve a hacer `flush` de esta serie -- quien sí
    // haga `flush` sigue recibiendo el error real a través de `_inFlight`.
    _inFlight[setId] = _chainWrite(_inFlight[setId], setId, payload)
      ..catchError((_) {});
  }

  Future<void> _chainWrite(
    Future<void>? previous,
    int setId,
    Map<String, num> payload,
  ) async {
    if (previous != null) {
      try {
        await previous;
      } catch (_) {
        // La escritura anterior de esta serie ya falló y fue reportada por
        // el `flush` que la esperó -- no debe volver a fallar acá ni frenar
        // la escritura nueva.
      }
    }
    await write(setId, payload);
  }

  /// Cancela el debounce de [setId], escribe lo pendiente (si hay) y espera
  /// también la escritura en vuelo de esa serie, aunque no haya nada nuevo
  /// que escribir.
  Future<void> flush(int setId) {
    _timers.remove(setId)?.cancel();
    final payload = _pending.remove(setId);
    if (payload == null || payload.isEmpty) {
      return _inFlight[setId] ?? Future.value();
    }
    final future = _chainWrite(_inFlight[setId], setId, payload);
    _inFlight[setId] = future;
    return future;
  }

  Future<void> flushAll() {
    final ids = {..._pending.keys, ..._inFlight.keys};
    return Future.wait(ids.map(flush));
  }

  /// Cancela los timers y dispara (sin esperar) lo que haya pendiente, para
  /// no perder cambios sin escribir si la pantalla se cierra de golpe. No
  /// deja timers vivos.
  void dispose() {
    for (final timer in _timers.values) {
      timer.cancel();
    }
    _timers.clear();
    for (final setId in _pending.keys.toList()) {
      _fire(setId);
    }
  }
}
