// Tests escritos por el SUPERVISOR (Opus) ANTES de la implementación.
// El dueño activó en Supabase la política de contraseñas "Lowercase,
// uppercase letters and digits" (sin exigir símbolos). La app solo validaba
// longitud >= 8, así que una contraseña sin mayúscula o sin número la rechaza
// el SERVIDOR y el usuario ve "No se pudo completar la operación. Intentá de
// nuevo." -- sin forma de saber qué le falta. La política del cliente debe
// ser un espejo EXACTO de la del servidor: ni más estricta (rechazaría
// contraseñas que el servidor acepta) ni más laxa.
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'package:appgym/core/auth/password_policy.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  group('PasswordPolicy.validate (null = válida)', () {
    test('acepta una contraseña con mayúscula, minúscula y número', () {
      expect(PasswordPolicy.validate('Gimnasio1'), isNull);
    });

    test('los símbolos son opcionales: se aceptan, no se exigen', () {
      for (final password in ['Gimnasio1', 'Abcdefg1#', 'Abcdefg1_']) {
        expect(PasswordPolicy.validate(password), isNull, reason: password);
      }
    });

    test('rechaza null y vacío', () {
      expect(PasswordPolicy.validate(null), isNotNull);
      expect(PasswordPolicy.validate(''), isNotNull);
    });

    test('rechaza menos de 8 caracteres diciendo el mínimo', () {
      final error = PasswordPolicy.validate('Abc1xyz');
      expect(error, isNotNull);
      expect(error, contains('8'));
    });

    test('rechaza sin mayúscula y lo dice', () {
      final error = PasswordPolicy.validate('gimnasio1');
      expect(error, isNotNull);
      expect(error!.toLowerCase(), contains('mayúscula'));
    });

    test('rechaza sin minúscula y lo dice', () {
      final error = PasswordPolicy.validate('GIMNASIO1');
      expect(error, isNotNull);
      expect(error!.toLowerCase(), contains('minúscula'));
    });

    test('rechaza sin número y lo dice', () {
      final error = PasswordPolicy.validate('Gimnasiooo');
      expect(error, isNotNull);
      expect(error!.toLowerCase(), contains('número'));
    });

    test('NO exige símbolos: el mensaje nunca los pide', () {
      final error = PasswordPolicy.validate('gimnasio');
      expect(error!.toLowerCase(), isNot(contains('símbolo')));
      expect(PasswordPolicy.hint.toLowerCase(), isNot(contains('símbolo')));
    });

    test('el mensaje nombra TODO lo que falta, no solo lo primero', () {
      final error = PasswordPolicy.validate('gimnasio')!.toLowerCase();
      expect(error, contains('mayúscula'));
      expect(error, contains('número'));
    });

    test('hint describe la política para mostrar en el formulario', () {
      final hint = PasswordPolicy.hint.toLowerCase();
      expect(hint, contains('8'));
      expect(hint, contains('mayúscula'));
      expect(hint, contains('número'));
    });
  });
}
