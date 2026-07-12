/// Credenciales del proyecto Supabase ("AppGym", ver
/// `docs/ARQUITECTURA_BACKEND.md`). La URL y la publishable key no son
/// secretas -- están protegidas por RLS, no por ocultarlas -- así que se
/// pueden bundlear como default. Se pueden sobreescribir en build time
/// (staging/otro proyecto) con:
///   flutter build apk --dart-define=SUPABASE_URL=... --dart-define=SUPABASE_PUBLISHABLE_KEY=...
class SupabaseConfig {
  static const _urlOverride = String.fromEnvironment('SUPABASE_URL');
  static const _keyOverride = String.fromEnvironment(
    'SUPABASE_PUBLISHABLE_KEY',
  );

  static const _defaultUrl = 'https://vywkyuuuxpovoevwdewh.supabase.co';
  static const _defaultPublishableKey =
      'sb_publishable_7WFuSgZYH5KOLzoL2OO7zw_DusXo8C3';

  static String get url => _urlOverride.isNotEmpty ? _urlOverride : _defaultUrl;

  static String get publishableKey =>
      _keyOverride.isNotEmpty ? _keyOverride : _defaultPublishableKey;
}
