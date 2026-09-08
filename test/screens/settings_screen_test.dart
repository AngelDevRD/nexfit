import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/core/sync/sync_engine.dart';
import 'package:appgym/providers/sync_settings_provider.dart';
import 'package:appgym/providers/theme_provider.dart';
import 'package:appgym/providers/weight_unit_provider.dart';
import 'package:appgym/screens/settings/settings_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Los botones de "Política de privacidad"/"Términos de uso" abren
/// `LegalUrls.privacyPolicy`/`termsOfUse` con `url_launcher`. Mientras esos
/// placeholders (`<URL_PRIVACIDAD>`/`<URL_TERMINOS>`) no se reemplacen por
/// URLs reales, `_openLegalUrl` debe mostrar el snackbar de error en vez de
/// no hacer nada -- ver el bug real: `Uri.tryParse('<URL_PRIVACIDAD>')` NO
/// da null (da una URI relativa sin esquema), así que la guarda tenía que
/// ser `uri.hasScheme`, no solo `uri != null`.
void main() {
  late local.AppDatabase db;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap() => MultiProvider(
    providers: [
      ChangeNotifierProvider(create: (_) => ThemeProvider()),
      ChangeNotifierProvider(create: (_) => SyncSettingsProvider()),
      ChangeNotifierProvider(create: (_) => SyncEngine(db: db, entities: [])),
      ChangeNotifierProvider(create: (_) => WeightUnitProvider()),
    ],
    child: const MaterialApp(home: SettingsScreen()),
  );

  testWidgets(
    'placeholder de URL sin reemplazar: tocar "Política de privacidad" '
    'muestra el snackbar de error, no falla en silencio',
    (tester) async {
      await tester.pumpWidget(wrap());
      await tester.pumpAndSettle();

      // El ListView de Ajustes es largo -- "Política de privacidad" vive
      // bajo "Acerca de", fuera del viewport inicial en un tamaño de test
      // estándar.
      await tester.dragUntilVisible(
        find.text('Política de privacidad'),
        find.byType(Scrollable),
        const Offset(0, -300),
      );
      await tester.tap(find.text('Política de privacidad'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo abrir el enlace.'), findsOneWidget);
    },
  );
}
