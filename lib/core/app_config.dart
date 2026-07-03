import 'package:flutter/foundation.dart';

class AppConfig {
  // Emulador Android usa 10.0.2.2 para llegar al localhost de la máquina host.
  // iOS Simulator, web y desktop pueden usar localhost directamente.
  // Para dispositivo físico, reemplazar por la IP de la máquina en la red local.
  static String get apiBaseUrl {
    if (!kIsWeb && defaultTargetPlatform == TargetPlatform.android) {
      return 'http://10.0.2.2:8000';
    }
    return 'http://localhost:8000';
  }
}
