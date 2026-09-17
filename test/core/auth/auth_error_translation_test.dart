// Tests escritos por el SUPERVISOR (Opus) ANTES de la implementación.
// Con la política de contraseñas activada en Supabase, el servidor rechaza
// contraseñas débiles con mensajes en inglés que hoy caen en el genérico
// "No se pudo completar la operación. Intentá de nuevo.".
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'package:appgym/core/auth/auth_error_messages.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('translateAuthErrorMessage', () {
    test('contraseña débil por requisitos de caracteres', () {
      // Mensaje real de Supabase Auth (GoTrue) con la política activada.
      const raw =
          'Password should contain at least one character of each: '
          'abcdefghijklmnopqrstuvwxyz, ABCDEFGHIJKLMNOPQRSTUVWXYZ, '
          '0123456789, !@#\$%^&*()_+-=[]{};\'\\:"|<>?,./`~.';

      final translated = translateAuthErrorMessage(raw);

      expect(translated.toLowerCase(), contains('contraseña'));
      expect(translated, isNot(contains('Password should')));
      expect(
        translated.toLowerCase(),
        anyOf(contains('mayúscula'), contains('número')),
        reason: 'debe explicar qué pide la política, no un genérico',
      );
    });

    test('contraseña demasiado corta', () {
      final translated = translateAuthErrorMessage(
        'Password should be at least 8 characters.',
      );
      expect(translated, contains('8'));
      expect(translated.toLowerCase(), contains('contraseña'));
    });

    test('mantiene las traducciones que ya existían', () {
      expect(
        translateAuthErrorMessage('Email not confirmed'),
        contains('confirmado'),
      );
      expect(
        translateAuthErrorMessage('Invalid login credentials'),
        'Email o contraseña incorrectos.',
      );
      expect(
        translateAuthErrorMessage('User already registered'),
        contains('Ya existe una cuenta'),
      );
    });

    test('un mensaje desconocido cae en el genérico y NO filtra el original', () {
      final translated = translateAuthErrorMessage(
        'pgrst: relation "auth.users" does not exist',
      );
      expect(translated, 'No se pudo completar la operación. Intentá de nuevo.');
      expect(translated, isNot(contains('auth.users')));
    });

    test('rate limit se explica en vez de caer en el genérico', () {
      final translated = translateAuthErrorMessage(
        'Email rate limit exceeded',
      );
      expect(translated.toLowerCase(), contains('intentos'));
    });
  });
}
