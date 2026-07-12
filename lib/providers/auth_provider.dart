import 'dart:async';

import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/auth/auth_repository.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

export '../core/auth/auth_repository.dart' show AuthStatus;

class AuthProvider extends ChangeNotifier {
  final AuthRepository _authRepository;

  // Fase 1 (ver docs/ARQUITECTURA_BACKEND.md): la identidad/sesión ya no pasa
  // por FastAPI, pero el perfil extendido (edad, sexo, altura, peso,
  // objetivo, experiencia -- `PATCH /users/me`) todavía no migró a ningún
  // lado. Se mantiene sin tocar para no ampliar el alcance de esta fase, pero
  // como ya no hay ningún login contra FastAPI que emita un JWT, esta llamada
  // fallará (401) hasta que el perfil se migre en una fase futura.
  final AuthService _legacyProfileService;

  StreamSubscription<AuthStatus>? _authStateSub;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  String? error;

  AuthProvider(this._authRepository, ApiClient legacyApiClient)
    : _legacyProfileService = AuthService(legacyApiClient) {
    _authStateSub = _authRepository.authStateChanges.listen((newStatus) {
      status = newStatus;
      user = _authRepository.currentUser;
      notifyListeners();
    });
  }

  Future<void> tryAutoLogin() async {
    status = await _authRepository.restoreSession();
    user = _authRepository.currentUser;
    notifyListeners();
  }

  Future<bool> login(String email, String password) => _run(() async {
    user = await _authRepository.login(email: email, password: password);
    status = AuthStatus.authenticated;
  });

  Future<bool> register(String email, String password, String name) =>
      _run(() async {
        user = await _authRepository.register(
          email: email,
          password: password,
          name: name,
        );
        // Si el proyecto Supabase exige confirmar el email, signUp no deja
        // sesión activa todavía -- currentUser será null hasta que el
        // usuario confirme y haga login.
        status = _authRepository.currentUser != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
      });

  Future<bool> resetPassword(String email) =>
      _run(() => _authRepository.resetPassword(email: email));

  /// Perfil extendido -- ver nota en el campo `_legacyProfileService`.
  Future<bool> updateProfile(Map<String, dynamic> fields) => _run(() async {
    user = await _legacyProfileService.updateProfile(fields);
  });

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

  @override
  void dispose() {
    _authStateSub?.cancel();
    super.dispose();
  }
}
