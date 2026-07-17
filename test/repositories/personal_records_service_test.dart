import 'package:appgym/repositories/personal_records_service.dart';
import 'package:flutter_test/flutter_test.dart';

RecordInput _set(
  double weight,
  int reps, {
  int exercise = 1,
  bool warmup = false,
  int day = 1,
  int session = 1,
}) => RecordInput(
  exerciseId: exercise,
  weightKg: weight,
  reps: reps,
  isWarmup: warmup,
  achievedAt: DateTime(2026, 1, day),
  sessionId: session,
);

void main() {
  group('computeRecords', () {
    test('sin sets, no hay récords', () {
      expect(computeRecords([]), isEmpty);
    });

    test('un solo set establece récord de peso y de reps', () {
      final records = computeRecords([_set(100, 8)]);
      expect(records, hasLength(2));
      final weight = records.firstWhere((r) => r.recordType == 'max_weight');
      final reps = records.firstWhere((r) => r.recordType == 'max_reps');
      expect(weight.value, 100);
      expect(weight.previousValue, isNull);
      expect(reps.value, 8);
    });

    test('progresión: emite un evento por cada mejora (serie temporal)', () {
      final records = computeRecords([
        _set(100, 8, day: 1),
        _set(105, 8, day: 2),
        _set(110, 6, day: 3),
      ]);
      final weight = records.where((r) => r.recordType == 'max_weight');
      // Los tres sets mejoran el peso -> tres eventos (alimentan la predicción).
      expect(weight.map((r) => r.value), [100, 105, 110]);
      expect(weight.last.previousValue, 105);
    });

    test('un set que no mejora no genera evento', () {
      final records = computeRecords([
        _set(100, 8, day: 1),
        _set(90, 8, day: 2), // peor peso, mismas reps -> ni peso ni reps
      ]);
      expect(records.where((r) => r.recordType == 'max_weight'), hasLength(1));
      expect(records.where((r) => r.recordType == 'max_reps'), hasLength(1));
    });

    test('empatar el máximo no es récord', () {
      final records = computeRecords([
        _set(100, 8, day: 1),
        _set(100, 8, day: 2),
      ]);
      // Solo el primer set cuenta; el segundo empata y no genera récord nuevo.
      final weight = records.firstWhere((r) => r.recordType == 'max_weight');
      expect(weight.value, 100);
      expect(weight.previousValue, isNull);
    });

    test('los calentamientos se ignoran', () {
      final records = computeRecords([
        _set(200, 3, warmup: true),
        _set(100, 8),
      ]);
      final weight = records.firstWhere((r) => r.recordType == 'max_weight');
      expect(weight.value, 100);
    });

    test('un set puede romper récord de peso y de reps a la vez', () {
      final current = currentRecords(
        computeRecords([_set(100, 8, day: 1), _set(110, 10, day: 2)]),
      );
      final weight = current.firstWhere((r) => r.recordType == 'max_weight');
      final reps = current.firstWhere((r) => r.recordType == 'max_reps');
      expect(weight.value, 110);
      expect(reps.value, 10);
    });

    test('récords se agrupan por ejercicio', () {
      final records = computeRecords([
        _set(100, 8, exercise: 1),
        _set(60, 12, exercise: 2),
      ]);
      final ex1 = records.where((r) => r.exerciseId == 1);
      final ex2 = records.where((r) => r.exerciseId == 2);
      expect(ex1, hasLength(2));
      expect(ex2, hasLength(2));
      expect(ex1.firstWhere((r) => r.recordType == 'max_weight').value, 100);
      expect(ex2.firstWhere((r) => r.recordType == 'max_weight').value, 60);
    });

    test('el orden de entrada no importa (se ordena por fecha)', () {
      final ascending = computeRecords([
        _set(100, 8, day: 1),
        _set(110, 8, day: 2),
      ]);
      final descending = computeRecords([
        _set(110, 8, day: 2),
        _set(100, 8, day: 1),
      ]);
      expect(
        ascending.map((r) => (r.recordType, r.value)),
        descending.map((r) => (r.recordType, r.value)),
      );
    });
  });

  group('currentRecords', () {
    test('colapsa la progresión al récord vigente por ejercicio/tipo', () {
      final log = computeRecords([
        _set(100, 8, day: 1),
        _set(105, 9, day: 2),
        _set(110, 10, day: 3),
      ]);
      // La bitácora tiene la progresión; el vigente es uno por (ejercicio,tipo).
      final current = currentRecords(log);
      expect(current, hasLength(2));
      expect(
        current.firstWhere((r) => r.recordType == 'max_weight').value,
        110,
      );
      expect(current.firstWhere((r) => r.recordType == 'max_reps').value, 10);
    });

    test('agrupa varios ejercicios sin repetir', () {
      final log = computeRecords([
        _set(100, 8, exercise: 1, day: 1),
        _set(110, 8, exercise: 1, day: 2),
        _set(60, 12, exercise: 2, day: 1),
      ]);
      final current = currentRecords(log);
      // 2 tipos x 2 ejercicios = 4 récords vigentes, sin duplicar exercise 1.
      expect(current, hasLength(4));
      expect(
        current
            .where((r) => r.exerciseId == 1 && r.recordType == 'max_weight')
            .single
            .value,
        110,
      );
    });
  });
}
