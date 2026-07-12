/// Indica si el backend inteligente (Coach IA / chat / tool-calling, ver
/// `docs/ARQUITECTURA_BACKEND.md` sección 2.1) está configurado en este
/// build. Ninguna pantalla debe llamar a `backend_ia` sin consultar antes
/// `isConfigured` -- si es falso, debe mostrarse `ComingSoonView` en vez de
/// intentar la llamada de red.
class SmartBackendAvailability {
  // flutter build apk --dart-define=SMART_BACKEND_URL=https://...
  static const _override = String.fromEnvironment('SMART_BACKEND_URL');

  static bool get isConfigured => _override.isNotEmpty;

  static String? get baseUrl => isConfigured ? _override : null;
}
