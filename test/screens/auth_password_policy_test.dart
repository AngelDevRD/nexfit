// Tests escritos por el SUPERVISOR (Opus) ANTES de la implementación.
// Registro: debe validar la MISMA política que Supabase (8 + mayúscula +
// minúscula + número) antes de llamar al servidor, y decir qué falta.
// Login: NO debe aplicar la política -- una cuenta vieja puede tener una
// contraseña de 6 caracteres y el formulario no puede impedirle entrar
// (hallazgo M16 de la auditoría). Quien decide es el servidor.
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'dart:async';

import 'package:appgym/core/auth/account_data_guard.dart';
import 'package:appgym/core/auth/auth_repository.dart';
import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/models/user.dart';
import 'package:appgym/providers/auth_provider.dart';
import 'package:appgym/repositories/profile_repository.dart';
import 'package:appgym/screens/auth/login_screen.dart';
import 'package:appgym/screens/auth/register_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _RecordingAuthRepository implements AuthRepository {
  final loginCalls = <String>[];
  final registerCalls = <String>[];
  AppUser? _user;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AuthStatus> get authStateChanges => const Stream.empty();

  @override
  Future<AuthStatus> restoreSession() async => AuthStatus.unauthenticated;

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    loginCalls.add(password);
    _user = AppUser(id: 'id-1', email: email, name: 'Ana');
    return _user!;
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
  }) async {
    registerCalls.add(password);
    _user = AppUser(id: 'id-1', email: email, name: name);
    return _user!;
  }

  @override
  Future<void> logout() async => _user = null;

  final resetCalls = <String>[];
  bool failReset = false;

  @override
  Future<void> resetPassword({required String email}) async {
    if (failReset) throw AuthFailure('No se pudo enviar el correo.');
    resetCalls.add(email);
  }

  @override
  Future<void> deleteAccount() async {}
}

void main() {
  late local.AppDatabase db;
  late _RecordingAuthRepository repo;
  late AuthProvider provider;

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    repo = _RecordingAuthRepository();
    provider = AuthProvider(
      repo,
      ProfileRepository(db),
      accountGuard: AccountDataGuard(db),
    );
  });

  tearDown(() async {
    provider.dispose();
    await db.close();
  });

  Widget wrap(Widget screen) => MultiProvider(
    providers: [
      ChangeNotifierProvider<AuthProvider>.value(value: provider),
      Provider<local.AppDatabase>.value(value: db),
    ],
    child: MaterialApp(home: screen),
  );

  Future<void> fill(
    WidgetTester tester, {
    required String email,
    required String password,
    String? name,
  }) async {
    final fields = find.byType(TextFormField);
    var index = 0;
    if (name != null) {
      await tester.enterText(fields.at(index++), name);
    }
    await tester.enterText(fields.at(index++), email);
    await tester.enterText(fields.at(index), password);
  }

  group('registro', () {
    testWidgets('una contraseña sin número no llega al servidor y se explica', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const RegisterScreen()));
      await tester.pumpAndSettle();

      await fill(
        tester,
        name: 'Ana',
        email: 'ana@x.com',
        password: 'Gimnasiooo',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(repo.registerCalls, isEmpty, reason: 'no debe llamar al servidor');
      expect(find.text('Te falta un número'), findsOneWidget);
    });

    testWidgets('una contraseña sin mayúscula tampoco pasa', (tester) async {
      await tester.pumpWidget(wrap(const RegisterScreen()));
      await tester.pumpAndSettle();

      await fill(
        tester,
        name: 'Ana',
        email: 'ana@x.com',
        password: 'gimnasio1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(repo.registerCalls, isEmpty);
      expect(find.text('Te falta una mayúscula'), findsOneWidget);
    });

    testWidgets('una contraseña que cumple la política sí se envía', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const RegisterScreen()));
      await tester.pumpAndSettle();

      await fill(
        tester,
        name: 'Ana',
        email: 'ana@x.com',
        password: 'Gimnasio1',
      );
      await tester.tap(find.widgetWithText(FilledButton, 'Crear cuenta'));
      await tester.pumpAndSettle();

      expect(repo.registerCalls, ['Gimnasio1']);
    });
  });

  group('login', () {
    testWidgets(
      'M16: una contraseña vieja de 6 caracteres NO se bloquea en el cliente',
      (tester) async {
        await tester.pumpWidget(wrap(const LoginScreen()));
        await tester.pumpAndSettle();

        await fill(tester, email: 'ana@x.com', password: 'viejo1');
        await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
        await tester.pumpAndSettle();

        expect(
          repo.loginCalls,
          ['viejo1'],
          reason: 'quien decide si la contraseña sirve es el servidor',
        );
      },
    );

    testWidgets('una contraseña vacía sí se bloquea en el cliente', (
      tester,
    ) async {
      await tester.pumpWidget(wrap(const LoginScreen()));
      await tester.pumpAndSettle();

      await fill(tester, email: 'ana@x.com', password: '');
      await tester.tap(find.widgetWithText(FilledButton, 'Iniciar sesión'));
      await tester.pumpAndSettle();

      expect(repo.loginCalls, isEmpty);
    });

    testWidgets(
      'recuperar contraseña: envía el email y avisa sin revelar si existe',
      (tester) async {
        await tester.pumpWidget(wrap(const LoginScreen()));
        await tester.pumpAndSettle();
        await tester.enterText(find.byType(TextFormField).first, 'ana@x.com');

        await tester.tap(find.text('¿Olvidaste tu contraseña?'));
        await tester.pumpAndSettle();
        expect(find.text('Recuperar contraseña'), findsOneWidget);
        await tester.tap(find.text('Enviar'));
        await tester.pumpAndSettle();

        expect(repo.resetCalls, ['ana@x.com']);
        expect(
          find.textContaining('Si el correo existe'),
          findsOneWidget,
          reason: 'no debe confirmar ni negar que la cuenta exista',
        );
      },
    );

    testWidgets('recuperar contraseña: cancelar no envía nada', (tester) async {
      await tester.pumpWidget(wrap(const LoginScreen()));
      await tester.pumpAndSettle();

      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(repo.resetCalls, isEmpty);
    });

    testWidgets('recuperar contraseña: un fallo del servidor se muestra', (
      tester,
    ) async {
      repo.failReset = true;
      await tester.pumpWidget(wrap(const LoginScreen()));
      await tester.pumpAndSettle();
      await tester.enterText(find.byType(TextFormField).first, 'ana@x.com');

      await tester.tap(find.text('¿Olvidaste tu contraseña?'));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Enviar'));
      await tester.pumpAndSettle();

      expect(find.text('No se pudo enviar el correo.'), findsOneWidget);
    });
  });
}
