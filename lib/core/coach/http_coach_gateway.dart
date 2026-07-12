import 'dart:async';
import 'dart:convert';

import 'package:http/http.dart' as http;

import '../../models/coach_context.dart';
import 'coach_exception.dart';
import 'coach_gateway.dart';

/// Única implementación de `CoachGateway` -- habla HTTP con el backend
/// inteligente (`backend_ia/`) exactamente como lo define docs/COACH_API.md.
/// No decide nada de negocio: solo serializa el request, interpreta la
/// respuesta y traduce cada `error.code` a su `CoachException`.
class HttpCoachGateway implements CoachGateway {
  final String baseUrl;
  final http.Client _client;
  final Duration timeout;

  HttpCoachGateway({
    required this.baseUrl,
    http.Client? client,
    this.timeout = const Duration(seconds: 35),
  }) : _client = client ?? http.Client();

  Uri get _chatUri =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r"/$"), "")}/api/v1/coach/chat');
  Uri get _statusUri =>
      Uri.parse('${baseUrl.replaceAll(RegExp(r"/$"), "")}/api/v1/coach/status');

  @override
  Future<CoachReply> sendMessage({
    required String sessionId,
    required String message,
    required CoachContext context,
    required String accessToken,
  }) async {
    http.Response response;
    try {
      response = await _client
          .post(
            _chatUri,
            headers: {
              'Authorization': 'Bearer $accessToken',
              'Content-Type': 'application/json',
            },
            body: jsonEncode({
              'sessionId': sessionId,
              'message': message,
              'context': context.toJson(),
            }),
          )
          .timeout(timeout);
    } on TimeoutException {
      throw const CoachTimeoutException(
        'El Coach tardó demasiado en responder, probá de nuevo.',
      );
    } on http.ClientException catch (e) {
      throw CoachUnknownException(
        'No se pudo conectar con el Coach: ${e.message}',
      );
    }

    final body = _tryDecode(response.body);

    if (response.statusCode == 200 && body != null) {
      final usageJson = body['usage'] as Map<String, dynamic>? ?? const {};
      return CoachReply(
        text: body['reply'] as String? ?? '',
        model: body['model'] as String? ?? 'desconocido',
        usage: CoachUsage(
          promptTokens: (usageJson['promptTokens'] as num?)?.toInt() ?? 0,
          completionTokens:
              (usageJson['completionTokens'] as num?)?.toInt() ?? 0,
          totalTokens: (usageJson['totalTokens'] as num?)?.toInt() ?? 0,
        ),
      );
    }

    throw _errorFor(response, body);
  }

  @override
  Future<bool> checkStatus() async {
    try {
      final response = await _client.get(_statusUri).timeout(timeout);
      if (response.statusCode != 200) return false;
      final body = _tryDecode(response.body);
      return body?['available'] as bool? ?? false;
    } catch (_) {
      // GET /coach/status nunca debe tirar -- si falla, se interpreta como
      // no disponible (ver docs/COACH_API.md).
      return false;
    }
  }

  Map<String, dynamic>? _tryDecode(String raw) {
    if (raw.isEmpty) return null;
    try {
      return jsonDecode(raw) as Map<String, dynamic>;
    } catch (_) {
      return null;
    }
  }

  CoachException _errorFor(http.Response response, Map<String, dynamic>? body) {
    final errorJson = body?['error'] as Map<String, dynamic>?;
    final code = errorJson?['code'] as String?;
    final message =
        errorJson?['message'] as String? ??
        'Error del Coach (${response.statusCode})';

    switch (code) {
      case 'unauthorized':
        return CoachUnauthorizedException(message);
      case 'forbidden':
        return CoachForbiddenException(message);
      case 'rate_limited':
        final retryAfterHeader = response.headers['retry-after'];
        final retryAfter = int.tryParse(retryAfterHeader ?? '') ?? 60;
        return CoachRateLimitedException(message, retryAfter);
      case 'invalid_request':
      case 'context_too_large':
        return CoachInvalidContextException(message);
      case 'llm_unavailable':
        return CoachUnavailableException(message);
      case 'timeout':
        return CoachTimeoutException(message);
      default:
        // Sin sobre de error reconocible (ej. 5xx de un proxy intermedio) --
        // se cae por status HTTP como respaldo.
        switch (response.statusCode) {
          case 401:
            return CoachUnauthorizedException(message);
          case 403:
            return CoachForbiddenException(message);
          case 429:
            return CoachRateLimitedException(message, 60);
          case 503:
            return CoachUnavailableException(message);
          case 504:
            return CoachTimeoutException(message);
          default:
            return CoachUnknownException(message);
        }
    }
  }
}
