import '../../models/user.dart';
import 'auth_repository.dart';

/// Fallback usado únicamente si `Supabase.initialize` falló en `main()` (ver
/// el try/catch ahí). Sin esto, acceder a `Supabase.instance.client` con la
/// inicialización fallida tira una excepción y la app no arranca -- lo que
/// viola la regla de "nunca romper el arranque" ya establecida en la Fase 0.
/// Todas las acciones fallan con un mensaje claro en vez de crashear.
class UnavailableAuthRepository implements AuthRepository {
  const UnavailableAuthRepository();

  static const _message =
      'Servicio de autenticación no disponible. Intenta de nuevo más tarde.';

  @override
  AppUser? get currentUser => null;

  @override
  Future<AuthStatus> restoreSession() async => AuthStatus.unauthenticated;

  @override
  Stream<AuthStatus> get authStateChanges => const Stream.empty();

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
  }) async {
    throw Exception(_message);
  }

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async {
    throw Exception(_message);
  }

  @override
  Future<void> logout() async {}

  @override
  Future<void> resetPassword({required String email}) async {
    throw Exception(_message);
  }
}
