import 'package:appgym/models/exercise.dart';
import 'package:appgym/models/workout.dart';
import 'package:flutter_test/flutter_test.dart';

final _exercise = ExerciseSummary(
  id: 1,
  slug: 'sentadilla',
  name: 'Sentadilla',
  muscleGroup: 'legs',
  difficulty: 'intermediate',
);

WorkoutSet _set(int setNumber) => WorkoutSet(
  id: setNumber,
  setNumber: setNumber,
  weightKg: 50,
  reps: 8,
  techniques: const [],
  isWarmup: false,
  exercise: _exercise,
);

void main() {
  group('nextSetNumber', () {
    test('sin series previas, la primera es la 1', () {
      expect(nextSetNumber(const []), 1);
    });

    test('con series 1..3, la próxima es la 4', () {
      expect(nextSetNumber([_set(1), _set(2), _set(3)]), 4);
    });

    test(
      'T4: tras borrar una serie intermedia, usa max+1 en vez de length+1',
      () {
        // Series 1 y 3 (la 2 se borró) -- `length` da 2, pero el máximo real
        // es 3, así que la próxima serie debe ser la 4, no la 3.
        final sets = [_set(1), _set(3)];
        expect(nextSetNumber(sets), 4);
        expect(nextSetNumber(sets), isNot(sets.length + 1));
      },
    );
  });
}
