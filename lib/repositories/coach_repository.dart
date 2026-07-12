import 'dart:math';

import '../core/coach/coach_context_builder.dart';
import '../core/coach/coach_exception.dart';
import '../core/coach/coach_gateway.dart';

String generateUuidV4() {
  final random = Random.secure();
  final bytes = List<int>.generate(16, (_) => random.nextInt(256));
  bytes[6] = (bytes[6] & 0x0f) | 0x40; // version 4
  bytes[8] = (bytes[8] & 0x3f) | 0x80; // variant RFC 4122
  String hex(int start, int end) => bytes
      .sublist(start, end)
      .map((b) => b.toRadixString(16).padLeft(2, '0'))
      .join();
  return '${hex(0, 4)}-${hex(4, 6)}-${hex(6, 8)}-${hex(8, 10)}-${hex(10, 16)}';
}

/// Único punto de entrada de la UI hacia el Coach IA -- la pantalla nunca
/// habla directo con `CoachGateway`/HTTP/JSON (ver docs/FASE_4_DISENO.md
/// sección 3). Mantiene el `sessionId` estable durante toda la conversación
/// (docs/COACH_API.md: "no cambia entre mensajes de la misma conversación").
///
/// Diseñado para poder crecer sin romper el contrato de `sendMessage`:
/// historial de conversación, streaming o múltiples modelos son cambios
/// internos de esta clase, no de la UI que la consume.
class CoachRepository {
  final CoachContextBuilder contextBuilder;
  final CoachGateway gateway;
  final String? Function() accessTokenProvider;
  final String sessionId;

  CoachRepository({
    required this.contextBuilder,
    required this.gateway,
    required this.accessTokenProvider,
    String? sessionId,
  }) : sessionId = sessionId ?? generateUuidV4();

  /// El `CoachContext` se arma bajo demanda, solo cuando el usuario manda un
  /// mensaje (docs/COACH_CONTEXT.md) -- nunca se construye de forma continua
  /// ni en segundo plano.
  Future<CoachReply> sendMessage(String message) async {
    final token = accessTokenProvider();
    if (token == null || token.isEmpty) {
      throw const CoachUnauthorizedException(
        'No hay una sesión activa. Iniciá sesión de nuevo.',
      );
    }

    final context = await contextBuilder.build(sessionId: sessionId);

    return gateway.sendMessage(
      sessionId: sessionId,
      message: message,
      context: context,
      accessToken: token,
    );
  }

  Future<bool> checkStatus() => gateway.checkStatus();
}
