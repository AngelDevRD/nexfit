import '../../models/coach_context.dart';

class CoachUsage {
  final int promptTokens;
  final int completionTokens;
  final int totalTokens;

  const CoachUsage({
    required this.promptTokens,
    required this.completionTokens,
    required this.totalTokens,
  });
}

class CoachReply {
  final String text;
  final String model;
  final CoachUsage usage;

  const CoachReply({
    required this.text,
    required this.model,
    required this.usage,
  });
}

/// Contrato HTTP del backend inteligente -- ver docs/COACH_API.md. Sin
/// lógica de negocio: no arma el contexto, no lo transforma, solo
/// serializa/envía/recibe/mapea errores a `CoachException`.
abstract class CoachGateway {
  Future<CoachReply> sendMessage({
    required String sessionId,
    required String message,
    required CoachContext context,
    required String accessToken,
  });

  /// Ver `GET /api/v1/coach/status` en docs/COACH_API.md.
  Future<bool> checkStatus();
}
