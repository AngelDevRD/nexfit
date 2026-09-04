import 'package:appgym/widgets/stepper_field.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  Widget wrap(Widget child) => MaterialApp(home: Scaffold(body: child));

  testWidgets(
    'C6: tocar el número edita inline (sin diálogo modal) y confirma al '
    'perder el foco',
    (tester) async {
      double? changedTo;
      await tester.pumpWidget(
        wrap(
          StepperField(
            value: 60,
            decimals: 1,
            onChanged: (v) => changedTo = v,
          ),
        ),
      );

      expect(find.text('60.0'), findsOneWidget);
      // Nada de AlertDialog en pantalla antes de tocar.
      expect(find.byType(AlertDialog), findsNothing);

      await tester.tap(find.text('60.0'));
      await tester.pump();

      // Sigue sin haber ningún diálogo -- la edición pasa a ser el mismo
      // espacio, ahora un TextField.
      expect(find.byType(AlertDialog), findsNothing);
      expect(find.byType(TextField), findsOneWidget);

      await tester.enterText(find.byType(TextField), '82.5');
      await tester.testTextInput.receiveAction(TextInputAction.done);
      await tester.pump();

      expect(changedTo, 82.5);
      // Vuelve a mostrar el número, ya no el campo de texto.
      expect(find.byType(TextField), findsNothing);
    },
  );

  testWidgets('los botones +/- siguen funcionando sin abrir edición', (
    tester,
  ) async {
    double? changedTo;
    await tester.pumpWidget(
      wrap(
        StepperField(value: 60, step: 2.5, onChanged: (v) => changedTo = v),
      ),
    );

    await tester.tap(find.byIcon(Icons.add));
    await tester.pump();

    // decimals: 0 (default) -> se redondea al enterito más cercano, igual
    // que ya hacía `_apply` antes de este cambio.
    expect(changedTo, 63.0);
    expect(find.byType(TextField), findsNothing);
  });

  testWidgets(
    'D3: sin fieldLabel, los botones +/- y el valor tienen semantic label '
    'genérico pero presente',
    (tester) async {
      await tester.pumpWidget(
        wrap(StepperField(value: 60, onChanged: (_) {})),
      );

      expect(
        find.bySemanticsLabel('Restar'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Sumar'),
        findsOneWidget,
      );
      expect(
        find.bySemanticsLabel('Editar valor, 60'),
        findsOneWidget,
      );
    },
  );

  testWidgets(
    'D3: con fieldLabel, los botones +/- y el valor anuncian el campo -- '
    'sin esto un lector de pantalla solo dice "más"/"menos" sin contexto',
    (tester) async {
      await tester.pumpWidget(
        wrap(
          StepperField(value: 60, fieldLabel: 'peso', onChanged: (_) {}),
        ),
      );

      expect(find.bySemanticsLabel('Restar peso'), findsOneWidget);
      expect(find.bySemanticsLabel('Sumar peso'), findsOneWidget);
      expect(find.bySemanticsLabel('Editar peso, 60'), findsOneWidget);
    },
  );
}
