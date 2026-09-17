// T-C1 -- Tests escritos por el SUPERVISOR (Opus) ANTES de la implementación.
// Al cerrar sesión con cambios sin sincronizar, avisar: si después entra otra
// cuenta en este teléfono, esos datos se borran (decisión D4).
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'dart:async';

import 'package:appgym/core/auth/account_data_guard.dart';
import 'package:appgym/core/auth/auth_repository.dart';
import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/models/user.dart';
import 'package:appgym/providers/auth_provider.dart';
import 'package:appgym/providers/weight_unit_provider.dart';
import 'package:appgym/repositories/nutrition_repository.dart';
import 'package:appgym/repositories/profile_repository.dart';
import 'package:appgym/screens/profile/profile_screen.dart';
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  AppUser? _user = AppUser(id: 'id-a', email: 'a@x.com', name: 'Ana');
  int logoutCalls = 0;

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AuthStatus> get authStateChanges => const Stream.empty();

  @override
  Future<AuthStatus> restoreSession() async =>
      _user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;

  @override
  Future<AppUser> login({required String email, required String password}) =>
      throw UnimplementedError();

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
  }) => throw UnimplementedError();

  @override
  Future<void> logout() async {
    logoutCalls++;
    _user = null;
  }

  @override
  Future<void> resetPassword({required String email}) async {}

  @override
  Future<void> deleteAccount() async {}
}

void main() {
  late local.AppDatabase db;
  late _FakeAuthRepository authRepository;
  late AuthProvider authProvider;
  late AccountDataGuard guard;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    authRepository = _FakeAuthRepository();
    guard = AccountDataGuard(db);
    authProvider = AuthProvider(
      authRepository,
      ProfileRepository(db),
      accountGuard: guard,
    );
    await authProvider.tryAutoLogin();
  });

  tearDown(() async {
    await db.close();
  });

  Future<void> addUnsyncedNutritionLogs(int count) async {
    for (var i = 1; i <= count; i++) {
      await NutritionRepository(db).upsert({
        'log_date': '2026-09-0$i',
        'calories': 2000,
        'protein_g': 150,
        'carbs_g': 200,
        'fat_g': 60,
        'water_ml': 2500,
      });
    }
  }

  Future<void> pumpProfile(WidgetTester tester) async {
    await tester.pumpWidget(
      MultiProvider(
        providers: [
          Provider<AccountDataGuard>.value(value: guard),
          ChangeNotifierProvider<AuthProvider>.value(value: authProvider),
          ChangeNotifierProvider<WeightUnitProvider>(
            create: (_) => WeightUnitProvider(),
          ),
        ],
        child: const MaterialApp(home: ProfileScreen()),
      ),
    );
    await tester.pumpAndSettle();
  }

  Future<void> tapLogoutIcon(WidgetTester tester) async {
    await tester.tap(find.byTooltip('Cerrar sesión'));
    await tester.runAsync(() => pumpEventQueue());
    await tester.pumpAndSettle();
  }

  testWidgets(
    'con cambios sin sincronizar muestra el aviso con la cantidad y Cancelar no cierra sesión',
    (tester) async {
      // El perfil cargado por tryAutoLogin no existe en la base: solo cuentan
      // los 3 registros de nutrición creados acá.
      await tester.runAsync(() => addUnsyncedNutritionLogs(3));
      await pumpProfile(tester);

      await tapLogoutIcon(tester);

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.textContaining('3 cambios sin sincronizar'), findsOneWidget);

      await tester.tap(find.text('Cancelar'));
      await tester.pumpAndSettle();

      expect(find.byType(AlertDialog), findsNothing);
      expect(authRepository.logoutCalls, 0);
      expect(authProvider.status, AuthStatus.authenticated);
    },
  );

  testWidgets('confirmar en el aviso sí cierra sesión', (tester) async {
    await tester.runAsync(() => addUnsyncedNutritionLogs(2));
    await pumpProfile(tester);

    await tapLogoutIcon(tester);
    expect(find.textContaining('2 cambios sin sincronizar'), findsOneWidget);

    await tester.tap(
      find.descendant(
        of: find.byType(AlertDialog),
        matching: find.text('Cerrar sesión'),
      ),
    );
    await tester.runAsync(() => pumpEventQueue());
    await tester.pumpAndSettle();

    expect(authRepository.logoutCalls, 1);
    expect(authProvider.status, AuthStatus.unauthenticated);
  });

  testWidgets('sin cambios pendientes cierra sesión directo, sin aviso', (
    tester,
  ) async {
    await pumpProfile(tester);

    await tapLogoutIcon(tester);

    expect(find.byType(AlertDialog), findsNothing);
    expect(authRepository.logoutCalls, 1);
  });
}
