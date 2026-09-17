// T-H3 -- Tests escritos por el SUPERVISOR (Opus) ANTES de la implementación.
// Hallazgo H3 de docs/AUDITORIA_2026-09-16_SUPERVISOR.md: el debounce de los
// steppers vive en `ActiveWorkoutScreen`, llama a `updateSet` SIN await y
// borra el pendiente al disparar. Si el usuario toca el check mientras esa
// escritura está en vuelo, `_flushPendingSetUpdate` no encuentra nada que
// volcar, no espera nada, y `setCompleted` lee el peso viejo -> récord y XP
// evaluados contra un valor que ya no es el que se ve en pantalla.
// (El caso "el debounce todavía NO escribió" ya está cubierto por
// test/screens/active_workout_screen_test.dart.)
//
// Contrato: la lógica de edición debita salir del widget a una clase propia
// con la escritura inyectable, y `flush` debe esperar TAMBIÉN la escritura en
// vuelo.
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'dart:async';

import 'package:appgym/screens/workout/set_edit_controller.dart';
import 'package:flutter_test/flutter_test.dart';

/// Registra cada escritura y permite controlar cuándo termina, para poder
/// dejar una "en vuelo" a propósito.
class _RecordingWriter {
  final calls = <({int setId, Map<String, num> payload})>[];
  final completed = <int>[];
  final _gates = <Completer<void>>[];
  bool manualGate = false;
  Object? throwOnNextWrite;

  Future<void> write(int setId, Map<String, num> payload) async {
    calls.add((setId: setId, payload: Map.of(payload)));
    final error = throwOnNextWrite;
    throwOnNextWrite = null;
    if (manualGate) {
      final gate = Completer<void>();
      _gates.add(gate);
      await gate.future;
    }
    if (error != null) throw error;
    completed.add(setId);
  }

  /// Deja terminar la escritura pendiente más antigua.
  void releaseOne() => _gates.removeAt(0).complete();

  int get inFlight => _gates.where((g) => !g.isCompleted).length;
}

const _debounce = Duration(milliseconds: 500);

void main() {
  late _RecordingWriter writer;
  late SetEditController controller;

  setUp(() {
    writer = _RecordingWriter();
    controller = SetEditController(write: writer.write, debounce: _debounce);
  });

  tearDown(() => controller.dispose());

  test('varios toques del mismo campo terminan en UNA escritura con el valor final', () async {
    for (var i = 1; i <= 32; i++) {
      controller.queue(7, 'weight_kg', 2.5 * i);
    }

    expect(writer.calls, isEmpty, reason: 'nada se escribe antes del debounce');
    await Future<void>.delayed(_debounce * 2);

    expect(writer.calls, hasLength(1));
    expect(writer.calls.single.setId, 7);
    expect(writer.calls.single.payload, {'weight_kg': 80.0});
  });

  test('campos distintos de la misma serie viajan en un solo payload', () async {
    controller.queue(7, 'weight_kg', 80);
    controller.queue(7, 'reps', 8);
    controller.queue(7, 'weight_kg', 82.5);

    await Future<void>.delayed(_debounce * 2);

    expect(writer.calls, hasLength(1));
    expect(writer.calls.single.payload, {'weight_kg': 82.5, 'reps': 8});
  });

  test('series distintas se escriben por separado', () async {
    controller.queue(7, 'weight_kg', 80);
    controller.queue(9, 'reps', 10);

    await Future<void>.delayed(_debounce * 2);

    expect(writer.calls.map((c) => c.setId).toSet(), {7, 9});
  });

  test('flush escribe YA lo pendiente y no vuelve a escribir al vencer el debounce', () async {
    controller.queue(7, 'weight_kg', 80);

    await controller.flush(7);

    expect(writer.calls, hasLength(1));
    expect(writer.calls.single.payload, {'weight_kg': 80.0});
    expect(writer.completed, [7]);

    await Future<void>.delayed(_debounce * 2);
    expect(writer.calls, hasLength(1), reason: 'el debounce ya no dispara');
  });

  test(
    'H3: flush ESPERA la escritura que ya disparó el debounce y sigue en vuelo',
    () async {
      writer.manualGate = true;
      controller.queue(7, 'weight_kg', 80);

      // El debounce dispara la escritura, que queda en vuelo (sin terminar).
      await Future<void>.delayed(_debounce * 2);
      expect(writer.calls, hasLength(1));
      expect(writer.completed, isEmpty);
      expect(writer.inFlight, 1);

      var flushDone = false;
      final flush = controller.flush(7).then((_) => flushDone = true);

      await Future<void>.delayed(const Duration(milliseconds: 50));
      expect(
        flushDone,
        isFalse,
        reason:
            'flush no puede darse por terminado con una escritura en vuelo: '
            'quien lo llama (completar la serie) leería el valor viejo',
      );

      writer.releaseOne();
      await flush;
      expect(flushDone, isTrue);
      expect(writer.completed, [7]);
    },
  );

  test('flush de una serie sin cambios pendientes no escribe nada', () async {
    await controller.flush(7);
    expect(writer.calls, isEmpty);
  });

  test('flushAll vuelca todas las series pendientes', () async {
    controller.queue(7, 'weight_kg', 80);
    controller.queue(9, 'reps', 10);

    await controller.flushAll();

    expect(writer.calls.map((c) => c.setId).toSet(), {7, 9});
    expect(writer.completed.toSet(), {7, 9});
  });

  test('un error de escritura se propaga por flush y no bloquea las siguientes', () async {
    writer.throwOnNextWrite = StateError('base caída');
    controller.queue(7, 'weight_kg', 80);

    await expectLater(controller.flush(7), throwsStateError);

    controller.queue(7, 'weight_kg', 85);
    await controller.flush(7);
    expect(writer.calls.last.payload, {'weight_kg': 85.0});
    expect(writer.completed, [7]);
  });

  test('dispose lanza las escrituras pendientes en vez de perderlas', () async {
    controller.queue(7, 'weight_kg', 80);

    controller.dispose();
    await Future<void>.delayed(const Duration(milliseconds: 50));

    expect(writer.calls, hasLength(1));
    expect(writer.calls.single.payload, {'weight_kg': 80.0});

    // Un dispose no debe dejar timers vivos que escriban de nuevo.
    await Future<void>.delayed(_debounce * 2);
    expect(writer.calls, hasLength(1));

    controller = SetEditController(write: writer.write, debounce: _debounce);
  });
}
