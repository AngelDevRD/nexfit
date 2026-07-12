import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../models/user.dart';
import 'auth_repository.dart';

/// Implementación de [AuthRepository] sobre Supabase Auth. Persistencia de
/// sesión y renovación automática de token las maneja el propio
/// `supabase_flutter` (configurado en `Supabase.initialize`, ver `main.dart`)
/// -- esta clase no reimplementa nada de eso, solo traduce la API de
/// Supabase al contrato de la app.
class SupabaseAuthRepository implements AuthRepository {
  final sb.SupabaseClient _client;

  SupabaseAuthRepository(this._client);

  AppUser? _toAppUser(sb.User? user) {
    if (user == null) return null;
    final metadataName = user.userMetadata?['name'] as String?;
    final name = (metadataName != null && metadataName.trim().isNotEmpty)
        ? metadataName
        : (user.email?.split('@').first ?? '');
    return AppUser(id: user.id, email: user.email ?? '', name: name);
  }

  @override
  AppUser? get currentUser => _toAppUser(_client.auth.currentUser);

  @override
  Future<AuthStatus> restoreSession() async {
    // Supabase.initialize ya restauró la sesión persistida (si existía) antes
    // de que se llegue acá -- solo se lee el resultado.
    return _client.auth.currentSession != null
        ? AuthStatus.authenticated
        : AuthStatus.unauthenticated;
  }

  @override
  Stream<AuthStatus> get authStateChanges =>
      _client.auth.onAuthStateChange.map((data) {
        if (data.event == sb.AuthChangeEvent.signedOut) {
          return AuthStatus.unauthenticated;
        }
        return data.session != null
            ? AuthStatus.authenticated
            : AuthStatus.unauthenticated;
      });

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
  }) async {
    final res = await _client.auth.signUp(
      email: email,
      password: password,
      data: {'name': name},
    );
    final user = _toAppUser(res.user);
    if (user == null) {
      throw sb.AuthException('No se pudo completar el registro.');
    }
    return user;
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    final res = await _client.auth.signInWithPassword(
      email: email,
      password: password,
    );
    final user = _toAppUser(res.user);
    if (user == null) {
      throw sb.AuthException('Credenciales inválidas.');
    }
    return user;
  }

  @override
  Future<void> logout() => _client.auth.signOut();

  @override
  Future<void> resetPassword({required String email}) =>
      _client.auth.resetPasswordForEmail(email);
}
