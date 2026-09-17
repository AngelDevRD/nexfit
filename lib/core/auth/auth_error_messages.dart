/// Traduce los mensajes de Supabase Auth (siempre en inglés) a algo
/// mostrable. Este es el único lugar de la app que conoce el texto exacto
/// que devuelve Supabase -- si el día de mañana cambia de proveedor, esta
/// traducción se va con este archivo. Top-level (y no un método privado)
/// para poder probar cada caso sin un `SupabaseClient` de verdad.
///
/// Un mensaje desconocido cae en el genérico A PROPÓSITO: devolver el texto
/// original filtraría detalles internos del backend al usuario.
String translateAuthErrorMessage(String rawMessage) {
  final msg = rawMessage.toLowerCase();
  if (msg.contains('email not confirmed')) {
    return 'Tu email todavía no fue confirmado. Revisá tu bandeja de entrada '
        '(y spam) y hacé click en el link que te enviamos.';
  }
  if (msg.contains('invalid login credentials')) {
    return 'Email o contraseña incorrectos.';
  }
  if (msg.contains('user already registered')) {
    return 'Ya existe una cuenta con ese email.';
  }
  // Política de contraseñas del proyecto (ver `PasswordPolicy`): el
  // formulario ya la valida antes de llegar acá, así que esto cubre los
  // caminos que no pasan por el formulario (deep link de recuperación,
  // cambio de contraseña) y el caso de que el panel se endurezca sin que la
  // app se actualice.
  if (msg.contains('password should contain at least one character')) {
    return 'La contraseña necesita al menos una minúscula, una mayúscula y '
        'un número.';
  }
  if (msg.contains('password should be at least')) {
    final digits = RegExp(r'\d+').firstMatch(msg)?.group(0);
    return digits == null
        ? 'La contraseña es demasiado corta.'
        : 'La contraseña necesita al menos $digits caracteres.';
  }
  if (msg.contains('rate limit')) {
    return 'Demasiados intentos seguidos. Esperá unos minutos y probá de '
        'nuevo.';
  }
  return 'No se pudo completar la operación. Intentá de nuevo.';
}
