import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/auth/account_data_guard.dart';
import '../core/auth/auth_repository.dart';
import '../models/profile.dart';
import '../models/user.dart';
import '../repositories/profile_repository.dart';

export '../core/auth/auth_repository.dart' show AuthStatus;

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  // Fase 2 (ver docs/ARQUITECTURA_BACKEND.md): el perfil extendido (edad,
  // sexo, altura, peso, objetivo, experiencia) ya no depende de FastAPI --
  // vive en su propio dominio offline-first (Drift + Supabase), separado de
  // la identidad/sesión que maneja este provider. `AuthProvider` solo lo
  // combina con `AppUser` para no tener que tocar `profile_screen.dart`.
  final ProfileRepository _profileRepository;

  // T-C1: garantiza que los datos locales están aislados por cuenta (limpios
  // si cambió de usuario) ANTES de notificar como autenticada la cuenta
  // nueva -- ver docs/AUDITORIA_2026-09-16_SUPERVISOR.md hallazgo C1.
  final AccountDataGuard _accountGuard;

  StreamSubscription<AuthStatus>? _authStateSub;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  String? error;

  AuthProvider(
    this._authRepository,
    this._profileRepository, {
    required AccountDataGuard accountGuard,
  }) : _accountGuard = accountGuard {
    _authStateSub = _authRepository.authStateChanges.listen((newStatus) async {
      if (newStatus == AuthStatus.authenticated) {
        final identity = _authRepository.currentUser;
        if (identity != null) await _accountGuard.prepareForUser(identity.id);
      }
      status = newStatus;
      await _refreshUser();
      notifyListeners();
    });
  }

  Future<void> tryAutoLogin() async {
    final newStatus = await _authRepository.restoreSession();
    if (newStatus == AuthStatus.authenticated) {
      final identity = _authRepository.currentUser;
      if (identity != null) await _accountGuard.prepareForUser(identity.id);
    }
    status = newStatus;
    await _refreshUser();
    notifyListeners();
  }

  Future<bool> login(String email, String password) => _run(() async {
    final identity = await _authRepository.login(
      email: email,
      password: password,
    );
    await _accountGuard.prepareForUser(identity.id);
    status = AuthStatus.authenticated;
    await _refreshUser();
  });

  Future<bool> register(String email, String password, String name) =>
      _run(() async {
        await _authRepository.register(
          email: email,
          password: password,
          name: name,
        );
        // Si el proyecto Supabase exige confirmar el email, signUp no deja
        // sesión activa todavía -- currentUser será null hasta que el
        // usuario confirme y haga login.
        final identity = _authRepository.currentUser;
        if (identity != null) {
          await _accountGuard.prepareForUser(identity.id);
          status = AuthStatus.authenticated;
        } else {
          status = AuthStatus.unauthenticated;
        }
        await _refreshUser();
      });

  Future<bool> resetPassword(String email) =>
      _run(() => _authRepository.resetPassword(email: email));

  /// Perfil extendido -- ver nota en el campo `_profileRepository`. Escribe
  /// local (offline-first); `ProfileSyncable` sube el cambio cuando haya
  /// conexión.
  Future<bool> updateProfile(Map<String, dynamic> fields) => _run(() async {
    final identity = _authRepository.currentUser;
    if (identity == null) throw StateError('No hay sesión activa');
    await _profileRepository.upsert(identity.id, identity.name, fields);
    await _refreshUser();
  });

  Future<void> _refreshUser() async {
    final identity = _authRepository.currentUser;
    if (identity == null) {
      user = null;
      return;
    }
    final profile = await _profileRepository.get(identity.id);
    user = _merge(identity, profile);
  }

  AppUser _merge(AppUser identity, Profile? profile) => AppUser(
    id: identity.id,
    email: identity.email,
    name: identity.name,
    age: profile?.age,
    sex: profile?.sex,
    heightCm: profile?.heightCm,
    weightKg: profile?.weightKg,
    bodyFatPct: profile?.bodyFatPct,
    goal: profile?.goal,
    experienceLevel: profile?.experienceLevel,
  );

  Future<bool> _run(Future<void> Function() action) async {
    error = null;
    try {
      await action();
      notifyListeners();
      return true;
    } catch (e) {
      error = e.toString();
      notifyListeners();
      return false;
    }
  }

  Future<void> logout() async {
    await _authRepository.logout();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }

  /// Borra la cuenta (identidad + datos remotos) y cierra la sesión.
  /// Irreversible -- la pantalla que llama a esto es responsable de pedir
  /// confirmación explícita antes.
  Future<bool> deleteAccount() => _run(() async {
    await _authRepository.deleteAccount();
    user = null;
    status = AuthStatus.unauthenticated;
  });

  @override
  void dispose() {
    _authStateSub?.cancel();
    super.dispose();
  }
}
