import 'package:appgym/core/exercise_animation/animation_repository.dart';
import 'package:appgym/core/exercise_animation/exercise_animation.dart';
import 'package:appgym/core/exercise_animation/exercise_animation_provider.dart';
import 'package:appgym/widgets/attribution_footer.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// A4: fuente de animaciones falsa que solo atribuye a un slug fijo -- así
/// se puede probar que el texto sale de `ExerciseAnimation.attribution`
/// (no hardcodeado) y que no aparece si ningún ejercicio visible lo requiere.
class _FakeProvider implements ExerciseAnimationProvider {
  @override
  int get priority => 0;

  @override
  Future<bool> hasAnimation(String exerciseSlug) async =>
      exerciseSlug == 'con-licencia';

  @override
  Future<ExerciseAnimation?> getAnimation(String exerciseSlug) async {
    if (exerciseSlug != 'con-licencia') return null;
    return const ExerciseAnimation(
      id: 'con-licencia',
      animationPath: 'assets/x.gif',
      animationType: AnimationType.gif,
      provider: 'fake',
      attribution: '© Proveedor de prueba',
    );
  }
}

Widget wrap(Widget child) => Provider<AnimationRepository>.value(
  value: AnimationRepository(providers: [_FakeProvider()]),
  child: MaterialApp(home: Scaffold(body: child)),
);

void main() {
  testWidgets(
    'A4: no muestra nada si ningún ejercicio visible requiere atribución',
    (tester) async {
      await tester.pumpWidget(wrap(const AttributionFooter(slugs: ['sin-licencia'])));
      await tester.pump();
      expect(find.byType(Text), findsNothing);
    },
  );

  testWidgets(
    'A4: muestra el texto de ExerciseAnimation.attribution si algún visible lo requiere',
    (tester) async {
      await tester.pumpWidget(
        wrap(const AttributionFooter(slugs: ['sin-licencia', 'con-licencia'])),
      );
      await tester.pump();
      expect(find.text('© Proveedor de prueba'), findsOneWidget);
    },
  );
}
