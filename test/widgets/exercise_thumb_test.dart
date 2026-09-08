import 'package:appgym/core/exercise_animation/animation_repository.dart';
import 'package:appgym/core/exercise_animation/exercise_animation.dart';
import 'package:appgym/core/exercise_animation/exercise_animation_provider.dart';
import 'package:appgym/widgets/exercise_thumb.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A10: cuenta cuántas veces se le pide una animación al provider.
class _CountingProvider implements ExerciseAnimationProvider {
  int callCount = 0;

  @override
  int get priority => 0;

  @override
  Future<bool> hasAnimation(String exerciseSlug) async => true;

  @override
  Future<ExerciseAnimation?> getAnimation(String exerciseSlug) async {
    callCount++;
    return ExerciseAnimation.placeholder(exerciseSlug);
  }
}

void main() {
  testWidgets(
    'A10: ExerciseThumb resuelve la animación una sola vez ante varios rebuilds',
    (tester) async {
      final provider = _CountingProvider();
      var counter = 0;

      await tester.pumpWidget(
        Provider<AnimationRepository>.value(
          value: AnimationRepository(providers: [provider]),
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: Column(
                  children: [
                    const ExerciseThumb(slug: 'press-banca', color: Colors.blue),
                    ElevatedButton(
                      onPressed: () => setState(() => counter++),
                      child: const Text('rebuild'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();

      expect(provider.callCount, 1);

      for (var i = 0; i < 5; i++) {
        await tester.tap(find.text('rebuild'));
        await tester.pump();
      }

      expect(provider.callCount, 1);
    },
  );

  testWidgets(
    'A10: cambiar el slug vuelve a resolver la animación',
    (tester) async {
      final provider = _CountingProvider();
      var slug = 'press-banca';

      await tester.pumpWidget(
        Provider<AnimationRepository>.value(
          value: AnimationRepository(providers: [provider]),
          child: MaterialApp(
            home: StatefulBuilder(
              builder: (context, setState) => Scaffold(
                body: Column(
                  children: [
                    ExerciseThumb(slug: slug, color: Colors.blue),
                    ElevatedButton(
                      onPressed: () => setState(() => slug = 'sentadilla'),
                      child: const Text('cambiar'),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ),
      );
      await tester.pump();
      expect(provider.callCount, 1);

      await tester.tap(find.text('cambiar'));
      await tester.pump();

      expect(provider.callCount, 2);
    },
  );
}
