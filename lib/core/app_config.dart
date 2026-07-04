import 'package:flutter/foundation.dart';

class AppConfig {
  // Host del backend configurable en tiempo de build, sin tocar codigo:
  //   flutter build apk --dart-define=API_BASE_URL=http://192.168.x.x:8000
  // (dispositivo fisico apunta a la IP LAN de la PC, o al backend desplegado).
  static const _override = String.fromEnvironment('API_BASE_URL');

  // Sin override: 10.0.2.2 para el emulador Android (alias del localhost del
  // host), localhost para web/desktop.
  static String get apiBaseUrl {
    if (_override.isNotEmpty) return _override;
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }
}
