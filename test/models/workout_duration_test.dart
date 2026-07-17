import 'package:appgym/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

WorkoutSessionSummary _session(DateTime start, DateTime? end) =>
    WorkoutSessionSummary(id: 1, startedAt: start, endedAt: end);

void main() {
  group('formatWorkoutDuration', () {
    test('menos de una hora -> "48 min"', () {
      expect(formatWorkoutDuration(const Duration(minutes: 48)), '48 min');
    });

    test('más de una hora -> "1 h 12 min"', () {
      expect(
        formatWorkoutDuration(const Duration(hours: 1, minutes: 12)),
        '1 h 12 min',
      );
    });

    test('null -> "—"', () {
      expect(formatWorkoutDuration(null), '—');
    });
  });

  group('WorkoutSessionSummary.duration', () {
    test('sesión en curso (sin fin) -> null', () {
      expect(_session(DateTime(2026, 7, 10, 15, 44), null).duration, isNull);
    });

    test('duración normal se calcula de start/end', () {
      final s = _session(
        DateTime(2026, 7, 10, 15, 44),
        DateTime(2026, 7, 10, 16, 46),
      );
      expect(s.duration, const Duration(minutes: 62));
      expect(formatWorkoutDuration(s.duration), '1 h 2 min');
    });

    test('dato corrupto (>12 h, bug de importación viejo) -> null', () {
      // 4433 min = ~3 días: el caso real del bug. No debe mostrarse.
      final s = _session(
        DateTime(2026, 7, 10),
        DateTime(2026, 7, 10).add(const Duration(minutes: 4433)),
      );
      expect(s.duration, isNull);
      expect(formatWorkoutDuration(s.duration), '—');
    });

    test('fin anterior al inicio -> null', () {
      final s = _session(DateTime(2026, 7, 10, 16), DateTime(2026, 7, 10, 15));
      expect(s.duration, isNull);
    });
  });
}
