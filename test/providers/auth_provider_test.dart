// T-C1 (cierre del gate de cobertura) -- Tests escritos por el SUPERVISOR
// (Opus). Cubren caminos de AuthProvider que T-C1 tocó sin test directo
// (register con cambio de cuenta) y el comportamiento existente que quedaba
// en 0 % (errores, reset, perfil, borrado de cuenta).
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'dart:async';

import 'package:appgym/core/auth/account_data_guard.dart';
import 'package:appgym/core/auth/auth_repository.dart';
import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/models/user.dart';
import 'package:appgym/providers/auth_provider.dart';
import 'package:appgym/repositories/profile_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

class _FakeAuthRepository implements AuthRepository {
  AppUser? user;

  /// Si es true, `register` no deja sesión (proyecto que exige confirmar el
  /// email antes del primer login).
  bool registerRequiresEmailConfirmation = false;
  bool failLogin = false;
  bool failReset = false;
  bool failDelete = false;
  int deleteCalls = 0;
  String? lastResetEmail;

  AppUser _userFor(String email, [String? name]) => AppUser(
    id: 'id-$email',
    email: email,
    name: name ?? email.split('@').first,
  );

  @override
  AppUser? get currentUser => user;

  @override
  Stream<AuthStatus> get authStateChanges => const Stream.empty();

  @override
  Future<AuthStatus> restoreSession() async =>
      user == null ? AuthStatus.unauthenticated : AuthStatus.authenticated;

  @override
  Future<AppUser> login({required String email, required String password}) async {
    if (failLogin) throw AuthFailure('Email o contraseña incorrectos.');
    user = _userFor(email);
    return user!;
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final created = _userFor(email, name);
    if (!registerRequiresEmailConfirmation) user = created;
    return created;
  }

  @override
  Future<void> logout() async => user = null;

  @override
  Future<void> resetPassword({required String email}) async {
    if (failReset) throw AuthFailure('No se pudo enviar el correo.');
    lastResetEmail = email;
  }

  @override
  Future<void> deleteAccount() async {
    deleteCalls++;
    if (failDelete) throw AuthFailure('No se pudo eliminar la cuenta.');
    user = null;
  }
}

void main() {
  late local.AppDatabase db;
  late _FakeAuthRepository repo;
  late AccountDataGuard guard;
  late AuthProvider provider;

  Future<int> routineCount() async =>
      (await db.select(db.routines).get()).length;

  Future<void> insertRoutine(String name) => db
      .into(db.routines)
      .insert(
        local.RoutinesCompanion.insert(name: name, updatedAt: DateTime.now()),
      );

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    repo = _FakeAuthRepository();
    guard = AccountDataGuard(db);
    provider = AuthProvider(repo, ProfileRepository(db), accountGuard: guard);
  });

  tearDown(() async {
    provider.dispose();
    await db.close();
  });

  group('register', () {
    test('registrar una cuenta NUEVA en un teléfono con datos de otra los limpia', () async {
      expect(await provider.login('a@x.com', 'password1'), isTrue);
      await insertRoutine('Rutina de A');
      await provider.logout();

      expect(await provider.register('b@x.com', 'password1', 'Bea'), isTrue);

      expect(provider.status, AuthStatus.authenticated);
      expect(provider.user!.id, 'id-b@x.com');
      expect(provider.user!.name, 'Bea');
      expect(await routineCount(), 0);
      expect(guard.isReadyFor('id-b@x.com'), isTrue);
    });

    test(
      'registro que exige confirmar email: queda sin sesión y NO toca los datos locales',
      () async {
        expect(await provider.login('a@x.com', 'password1'), isTrue);
        await insertRoutine('Rutina de A');
        await provider.logout();
        repo.registerRequiresEmailConfirmation = true;

        expect(await provider.register('b@x.com', 'password1', 'Bea'), isTrue);

        expect(provider.status, AuthStatus.unauthenticated);
        expect(provider.user, isNull);
        expect(await routineCount(), 1);
        expect(guard.isReadyFor('id-b@x.com'), isFalse);
      },
    );
  });

  group('errores', () {
    test('login fallido: devuelve false, expone el mensaje y no cambia nada', () async {
      expect(await provider.login('a@x.com', 'password1'), isTrue);
      await insertRoutine('Rutina de A');
      await provider.logout();
      repo.failLogin = true;

      expect(await provider.login('b@x.com', 'malaclave'), isFalse);

      expect(provider.error, 'Email o contraseña incorrectos.');
      expect(provider.status, AuthStatus.unauthenticated);
      expect(await routineCount(), 1, reason: 'un login fallido no limpia datos');
      expect(guard.isReadyFor('id-b@x.com'), isFalse);
    });

    test('un intento exitoso posterior limpia el error anterior', () async {
      repo.failLogin = true;
      await provider.login('a@x.com', 'x');
      expect(provider.error, isNotNull);

      repo.failLogin = false;
      expect(await provider.login('a@x.com', 'password1'), isTrue);
      expect(provider.error, isNull);
    });
  });

  group('resetPassword', () {
    test('éxito: devuelve true y pide el reset para ese email', () async {
      expect(await provider.resetPassword('a@x.com'), isTrue);
      expect(repo.lastResetEmail, 'a@x.com');
      expect(provider.error, isNull);
    });

    test('fallo: devuelve false con el mensaje del proveedor', () async {
      repo.failReset = true;
      expect(await provider.resetPassword('a@x.com'), isFalse);
      expect(provider.error, 'No se pudo enviar el correo.');
    });
  });

  group('updateProfile', () {
    test('persiste en la base local y actualiza el usuario expuesto', () async {
      await provider.login('a@x.com', 'password1');

      expect(
        await provider.updateProfile({'age': 30, 'weight_kg': 82.5}),
        isTrue,
      );

      expect(provider.user!.age, 30);
      expect(provider.user!.weightKg, 82.5);
      final row = await (db.select(
        db.profiles,
      )..where((t) => t.id.equals('id-a@x.com'))).getSingle();
      expect(row.age, 30);
      expect(row.weightKg, 82.5);
      expect(row.dirty, isTrue, reason: 'debe quedar pendiente de sync');
    });

    test('sin sesión devuelve false y no escribe nada', () async {
      expect(await provider.updateProfile({'age': 30}), isFalse);
      expect(provider.error, isNotNull);
      expect(await db.select(db.profiles).get(), isEmpty);
    });
  });

  group('deleteAccount', () {
    test('éxito: sin sesión y sin usuario', () async {
      await provider.login('a@x.com', 'password1');

      expect(await provider.deleteAccount(), isTrue);

      expect(repo.deleteCalls, 1);
      expect(provider.status, AuthStatus.unauthenticated);
      expect(provider.user, isNull);
    });

    test('fallo: la sesión sigue activa y se informa el error', () async {
      await provider.login('a@x.com', 'password1');
      repo.failDelete = true;

      expect(await provider.deleteAccount(), isFalse);

      expect(provider.status, AuthStatus.authenticated);
      expect(provider.user!.id, 'id-a@x.com');
      expect(provider.error, 'No se pudo eliminar la cuenta.');
    });
  });
}
