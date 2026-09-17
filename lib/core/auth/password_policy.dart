/// Política de contraseñas del proyecto, espejo EXACTO de la configurada en
/// Supabase Auth (Authentication → Sign In / Providers → Email): longitud
/// mínima 8 y *Password requirements* = "Lowercase, uppercase letters and
/// digits". Los símbolos se aceptan pero no se exigen.
///
/// Existe para que el formulario rechace la contraseña ANTES de llamar al
/// servidor y pueda decir qué falta: si valida solo la longitud, el rechazo
/// llega de Supabase en inglés y el usuario ve un mensaje genérico sin
/// saber qué corregir.
///
/// Si cambia la configuración del panel, este archivo cambia con ella --
/// ser más estricto acá rechazaría contraseñas que el servidor acepta, y ser
/// más laxo devuelve el problema al servidor.
class PasswordPolicy {
  PasswordPolicy._();

  static const minLength = 8;

  static final _lowercase = RegExp(r'[a-z]');
  static final _uppercase = RegExp(r'[A-Z]');
  static final _digit = RegExp(r'[0-9]');

  /// Texto para el `hintText` del campo: describe la política completa, para
  /// que el usuario no la descubra por error y error.
  static const hint =
      'Contraseña (mín. 8, con mayúscula, minúscula y número)';

  /// `null` si [password] cumple la política. Si no, un mensaje que nombra
  /// TODO lo que falta (no solo el primer requisito incumplido).
  static String? validate(String? password) {
    final value = password ?? '';
    if (value.isEmpty) return 'Ingresá una contraseña';

    final faltantes = <String>[
      if (!_lowercase.hasMatch(value)) 'una minúscula',
      if (!_uppercase.hasMatch(value)) 'una mayúscula',
      if (!_digit.hasMatch(value)) 'un número',
    ];

    if (value.length < minLength) {
      if (faltantes.isEmpty) return 'Mínimo $minLength caracteres';
      return 'Mínimo $minLength caracteres y te falta ${_enumerar(faltantes)}';
    }
    if (faltantes.isEmpty) return null;
    return 'Te falta ${_enumerar(faltantes)}';
  }

  static String _enumerar(List<String> items) {
    if (items.length == 1) return items.single;
    return '${items.sublist(0, items.length - 1).join(', ')} y ${items.last}';
  }
}
