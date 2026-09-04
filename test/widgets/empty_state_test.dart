import 'package:appgym/widgets/empty_state.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

/// U5: componente reutilizable de estado vacío/error -- ícono + explicación
/// + acción que lo resuelve, en vez de la línea de texto suelta que había
/// antes en cada pantalla (o directamente nada en caso de error, dejando el
/// spinner girando para siempre).
void main() {
  testWidgets('EmptyState muestra ícono, mensaje y, si hay, el CTA', (
    tester,
  ) async {
    var tapped = false;
    await tester.pumpWidget(
      MaterialApp(
        home: Scaffold(
          body: EmptyState(
            icon: Icons.flag_outlined,
            message: 'Sin objetivos todavía.',
            actionLabel: 'Crear objetivo',
            onAction: () => tapped = true,
          ),
        ),
      ),
    );

    expect(find.byIcon(Icons.flag_outlined), findsOneWidget);
    expect(find.text('Sin objetivos todavía.'), findsOneWidget);
    expect(find.text('Crear objetivo'), findsOneWidget);

    await tester.tap(find.text('Crear objetivo'));
    expect(tapped, isTrue);
  });

  testWidgets('EmptyState sin actionLabel/onAction no muestra botón', (
    tester,
  ) async {
    await tester.pumpWidget(
      const MaterialApp(
        home: Scaffold(
          body: EmptyState(icon: Icons.info_outline, message: 'Vacío.'),
        ),
      ),
    );

    expect(find.byType(FilledButton), findsNothing);
  });

  testWidgets(
    'EmptyState.error usa el ícono/mensaje por defecto y el botón dispara '
    'onRetry',
    (tester) async {
      var retried = false;
      await tester.pumpWidget(
        MaterialApp(
          home: Scaffold(
            body: EmptyState.error(onRetry: () => retried = true),
          ),
        ),
      );

      expect(find.byIcon(Icons.error_outline), findsOneWidget);
      expect(
        find.text('Ocurrió un error al cargar los datos.'),
        findsOneWidget,
      );
      expect(find.text('Reintentar'), findsOneWidget);

      await tester.tap(find.text('Reintentar'));
      expect(retried, isTrue);
    },
  );
}
