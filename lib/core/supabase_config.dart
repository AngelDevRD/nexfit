/// Credenciales del proyecto Supabase ("AppGym", ver
/// `docs/ARQUITECTURA_BACKEND.md`), inyectadas en build time (AG-CORE-004:
/// las claves nunca van en el código):
///   flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_ANON_KEY=...
///
/// Sin estas variables `Supabase.initialize` falla -- main.dart ya lo captura
/// y cae a [UnavailableAuthRepository], la app sigue arrancando sin auth.
class SupabaseConfig {
  static const url = String.fromEnvironment('SUPABASE_URL');
  static const publishableKey = String.fromEnvironment('SUPABASE_ANON_KEY');
}
