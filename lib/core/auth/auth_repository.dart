import '../../models/user.dart';

enum AuthStatus { unknown, authenticated, unauthenticated }

/// Contrato único de autenticación (Fase 1 de `docs/ARQUITECTURA_BACKEND.md`).
/// `AuthProvider` y las pantallas dependen solo de esta interfaz -- nunca
/// saben si el proveedor real es Supabase, FastAPI, Firebase u otro. Cambiar
/// de proveedor en el futuro implica escribir una nueva implementación de
/// esta interfaz y wireearla en `main.dart`, sin tocar `AuthProvider` ni las
/// pantallas.
///
/// Cubre únicamente identidad/sesión: registro, login, logout, recuperar
/// contraseña, sesión persistida y usuario autenticado. La gestión de perfil
/// extendido (edad, sexo, altura, peso, objetivo, experiencia) sigue fuera de
/// este contrato -- ver la nota en `AuthProvider.updateProfile`.
abstract class AuthRepository {
  /// Resuelve el estado de sesión al arrancar la app, a partir de lo que el
  /// proveedor tenga persistido localmente. Nunca debe quedar sin resolver:
  /// si no hay sesión guardada, resuelve a [AuthStatus.unauthenticated].
  Future<AuthStatus> restoreSession();

  /// Emite un nuevo estado cada vez que cambia la sesión: login, logout,
  /// renovación automática de token, o expiración detectada por el proveedor.
  Stream<AuthStatus> get authStateChanges;

  /// Usuario actualmente autenticado, o `null` si no hay sesión activa.
  AppUser? get currentUser;

  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
  });

  Future<AppUser> login({required String email, required String password});

  Future<void> logout();

  /// Dispara el flujo de recuperación de contraseña del proveedor (típicamente
  /// un email con un link). No devuelve el usuario porque en ese momento
  /// todavía no hay sesión activa.
  Future<void> resetPassword({required String email});
}
