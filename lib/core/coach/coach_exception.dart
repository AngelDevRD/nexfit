/// Modelo de error uniforme del Coach IA -- la UI nunca interpreta códigos
/// HTTP directamente, solo estos tipos. `CoachGateway` es el único lugar que
/// traduce docs/COACH_API.md a estas excepciones.
abstract class CoachException implements Exception {
  final String message;
  const CoachException(this.message);

  @override
  String toString() => message;
}

class CoachUnauthorizedException extends CoachException {
  const CoachUnauthorizedException(super.message);
}

class CoachForbiddenException extends CoachException {
  const CoachForbiddenException(super.message);
}

class CoachRateLimitedException extends CoachException {
  final int retryAfterSeconds;
  const CoachRateLimitedException(super.message, this.retryAfterSeconds);
}

class CoachInvalidContextException extends CoachException {
  const CoachInvalidContextException(super.message);
}

class CoachUnavailableException extends CoachException {
  const CoachUnavailableException(super.message);
}

class CoachTimeoutException extends CoachException {
  const CoachTimeoutException(super.message);
}

class CoachUnknownException extends CoachException {
  const CoachUnknownException(super.message);
}
