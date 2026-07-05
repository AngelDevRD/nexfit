import 'package:flutter/foundation.dart';

import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/user.dart';
import '../services/auth_service.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

class AuthProvider extends ChangeNotifier {
  final ApiClient client;
  late final AuthService authService;

  AuthStatus status = AuthStatus.unknown;
  AppUser? user;
  String? error;

  AuthProvider(this.client) {
    authService = AuthService(client);
  }

  Future<void> tryAutoLogin() async {
    final token = await client.token;
    if (token == null) {
      status = AuthStatus.unauthenticated;
      notifyListeners();
      return;
    }
    try {
      user = await authService.me();
      status = AuthStatus.authenticated;
    } on ApiException catch (e) {
      // El servidor rechazo explicitamente el token (401/403) -> invalido.
      // Cualquier otro error (sin conexion, timeout, DNS) no lo invalida:
      // se sigue offline con el token cacheado, sin loguear al usuario.
      if (e.statusCode == 401 || e.statusCode == 403) {
        await client.clearToken();
        status = AuthStatus.unauthenticated;
      } else {
        status = AuthStatus.authenticated;
      }
    } catch (_) {
      status = AuthStatus.authenticated;
    }
    notifyListeners();
  }

  Future<bool> login(String email, String password) => _run(() async {
    await authService.login(email, password);
    user = await authService.me();
    status = AuthStatus.authenticated;
  });

  Future<bool> register(String email, String password, String name) =>
      _run(() async {
        await authService.register(email, password, name);
        user = await authService.me();
        status = AuthStatus.authenticated;
      });

  Future<bool> updateProfile(Map<String, dynamic> fields) => _run(() async {
    user = await authService.updateProfile(fields);
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
    await authService.logout();
    user = null;
    status = AuthStatus.unauthenticated;
    notifyListeners();
  }
}
