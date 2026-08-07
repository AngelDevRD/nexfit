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

  /// Traduce los mensajes de Supabase Auth (siempre en inglés) a algo
  /// mostrable. Este es el único lugar de la app que conoce el texto exacto
  /// que devuelve Supabase -- si el día de mañana cambia de proveedor, esta
  /// traducción se va con este archivo.
  Never _rethrowAsFailure(sb.AuthException e) {
    final msg = e.message.toLowerCase();
    if (msg.contains('email not confirmed')) {
      throw AuthFailure(
        'Tu email todavía no fue confirmado. Revisá tu bandeja de entrada '
        '(y spam) y hacé click en el link que te enviamos.',
      );
    }
    if (msg.contains('invalid login credentials')) {
      throw AuthFailure('Email o contraseña incorrectos.');
    }
    if (msg.contains('user already registered')) {
      throw AuthFailure('Ya existe una cuenta con ese email.');
    }
    throw AuthFailure('No se pudo completar la operación. Intentá de nuevo.');
  }

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
    try {
      final res = await _client.auth.signUp(
        email: email,
        password: password,
        data: {'name': name},
      );
      final user = _toAppUser(res.user);
      if (user == null) {
        throw AuthFailure('No se pudo completar el registro.');
      }
      return user;
    } on sb.AuthException catch (e) {
      _rethrowAsFailure(e);
    }
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    try {
      final res = await _client.auth.signInWithPassword(
        email: email,
        password: password,
      );
      final user = _toAppUser(res.user);
      if (user == null) {
        throw AuthFailure('Email o contraseña incorrectos.');
      }
      return user;
    } on sb.AuthException catch (e) {
      _rethrowAsFailure(e);
    }
  }

  @override
  Future<void> logout() => _client.auth.signOut();

  @override
  Future<void> resetPassword({required String email}) async {
    try {
      await _client.auth.resetPasswordForEmail(email);
    } on sb.AuthException catch (e) {
      _rethrowAsFailure(e);
    }
  }
}
