import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

import 'package:nexfit/main.dart';

void main() {
  testWidgets(
    'App arranca y muestra la pantalla de login sin sesión guardada',
    (WidgetTester tester) async {
      SharedPreferences.setMockInitialValues({});

      await tester.pumpWidget(const NexFitApp());
      await tester.pumpAndSettle();
      expect(find.text('NexFit'), findsOneWidget);
      expect(find.text('Iniciar sesión'), findsOneWidget);
    },
  );
}
