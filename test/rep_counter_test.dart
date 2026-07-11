import 'package:nexfit/features/pose/rep_counter.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('angleDegrees', () {
    test('ángulo recto = 90°', () {
      // b en origen, a arriba, c a la derecha
      expect(angleDegrees(0, 1, 0, 0, 1, 0), closeTo(90, 0.001));
    });

    test('línea recta = 180°', () {
      expect(angleDegrees(-1, 0, 0, 0, 1, 0), closeTo(180, 0.001));
    });

    test('puntos degenerados = 0', () {
      expect(angleDegrees(0, 0, 0, 0, 1, 0), 0);
    });
  });

  group('RepCounter', () {
    test('cuenta una rep completa (abajo y arriba)', () {
      final c = RepCounter(downThreshold: 90, upThreshold: 160);
      expect(c.update(170), isFalse); // arriba, sin cambio
      expect(c.update(80), isFalse); // baja -> phase down, no cuenta aún
      expect(c.reps, 0);
      expect(c.update(170), isTrue); // vuelve arriba -> cuenta
      expect(c.reps, 1);
    });

    test('no cuenta si no vuelve a subir', () {
      final c = RepCounter();
      c.update(80); // abajo
      c.update(100); // zona muerta, no supera upThreshold
      expect(c.reps, 0);
    });

    test('no doble cuenta en la zona muerta', () {
      final c = RepCounter(downThreshold: 90, upThreshold: 160);
      c.update(80);
      c.update(170); // 1
      c.update(170); // sigue arriba, no cuenta
      expect(c.reps, 1);
    });

    test('cuenta varias reps', () {
      final c = RepCounter();
      for (var i = 0; i < 3; i++) {
        c.update(70);
        c.update(170);
      }
      expect(c.reps, 3);
    });

    test('reset vuelve a cero', () {
      final c = RepCounter();
      c.update(70);
      c.update(170);
      c.reset();
      expect(c.reps, 0);
      expect(c.phase, RepPhase.up);
    });
  });
}
