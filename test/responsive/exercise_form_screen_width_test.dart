import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/repositories/exercise_repository.dart';
import 'package:appgym/screens/exercises/exercise_form_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// E1: el formulario de alta/edición de ejercicios propios es pantalla
/// nueva -- mismo chequeo que el resto del catálogo (A5/D4): sin overflow a
/// ancho de teléfono chico ni en pantalla ancha.
void main() {
  late local.AppDatabase db;
  late ExerciseRepository repo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    repo = ExerciseRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  for (final width in [320.0, 1200.0]) {
    testWidgets('formulario de ejercicio no desborda a ${width.toInt()}dp', (
      tester,
    ) async {
      tester.view.physicalSize = Size(width, 900);
      tester.view.devicePixelRatio = 1;
      addTearDown(tester.view.resetPhysicalSize);
      addTearDown(tester.view.resetDevicePixelRatio);

      await tester.pumpWidget(
        MultiProvider(
          providers: [Provider<ExerciseRepository>.value(value: repo)],
          child: const MaterialApp(home: ExerciseFormScreen()),
        ),
      );
      await tester.pumpAndSettle();

      expect(tester.takeException() == null, isTrue);
    });
  }
}
