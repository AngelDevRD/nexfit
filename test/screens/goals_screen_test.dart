import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/repositories/goal_repository.dart';
import 'package:appgym/screens/goals/goals_screen.dart';
import 'package:appgym/widgets/empty_state.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';

/// U5: antes el vacío era una línea de texto suelta ("Sin objetivos
/// todavía.") sin ícono ni acción, y un error en `_load()` (sin try/catch)
/// dejaba el spinner girando para siempre. Este test cubre ambos caminos con
/// el nuevo `EmptyState`.
void main() {
  late local.AppDatabase db;
  late GoalRepository repo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    repo = GoalRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap() => MultiProvider(
    providers: [Provider<GoalRepository>.value(value: repo)],
    child: const MaterialApp(home: GoalsScreen()),
  );

  testWidgets(
    'U5: sin objetivos, muestra el EmptyState con CTA que abre el diálogo '
    'de creación',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      expect(find.byType(EmptyState), findsOneWidget);
      expect(find.text('Sin objetivos todavía.'), findsOneWidget);
      expect(find.text('Crear objetivo'), findsOneWidget);

      await tester.tap(find.text('Crear objetivo'));
      await tester.pumpAndSettle();

      expect(find.text('Nuevo objetivo'), findsOneWidget);
    },
  );
}
