import 'dart:convert';

import 'package:appgym/core/coach/coach_exception.dart';
import 'package:appgym/core/coach/http_coach_gateway.dart';
import 'package:appgym/models/coach_context.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:http/http.dart' as http;
import 'package:http/testing.dart';

CoachContext _context() => CoachContext(
  sessionId: 'session-1',
  generatedAt: DateTime(2026, 7, 12),
  app: const CoachAppMetadata(
    version: '1.0.1',
    platform: 'android',
    timezone: '-04:00',
  ),
  profile: const CoachProfile(name: 'Angel'),
  preferences: const CoachPreferences(),
  settings: const CoachSettings(language: 'es', units: 'metric'),
  capabilities: const CoachCapabilities(social: true),
  goals: const [],
  stats: const CoachStats(
    weeklyVolumeKg: 0,
    currentStreakDays: 0,
    longestStreakDays: 0,
    maxStrengthByExercise: [],
  ),
  recentWorkouts: const [],
  personalRecords: const [],
  achievements: const CoachAchievements(
    level: 1,
    levelBand: 'novice',
    totalXp: 0,
    unlocked: [],
  ),
);

void main() {
  test('sendMessage exitoso devuelve reply/model/usage', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/coach/chat');
      expect(request.headers['Authorization'], 'Bearer token-123');
      final body = jsonDecode(request.body) as Map<String, dynamic>;
      expect(body['sessionId'], 'session-1');
      expect(body['message'], '¿Cómo voy?');
      expect(body['context']['version'], 1);

      return http.Response(
        jsonEncode({
          'reply': 'Vas muy bien.',
          'model': 'groq/llama-3.3-70b-versatile',
          'usage': {
            'promptTokens': 100,
            'completionTokens': 20,
            'totalTokens': 120,
          },
        }),
        200,
      );
    });

    final gateway = HttpCoachGateway(
      baseUrl: 'https://coach.example.com',
      client: client,
    );

    final reply = await gateway.sendMessage(
      sessionId: 'session-1',
      message: '¿Cómo voy?',
      context: _context(),
      accessToken: 'token-123',
    );

    expect(reply.text, 'Vas muy bien.');
    expect(reply.model, 'groq/llama-3.3-70b-versatile');
    expect(reply.usage.totalTokens, 120);
  });

  Future<void> expectMapsToException<T extends CoachException>(
    int statusCode,
    String code,
  ) async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'error': {'code': code, 'message': 'mensaje de $code'},
        }),
        statusCode,
        headers: code == 'rate_limited' ? {'retry-after': '42'} : {},
      ),
    );
    final gateway = HttpCoachGateway(
      baseUrl: 'https://coach.example.com',
      client: client,
    );

    await expectLater(
      () => gateway.sendMessage(
        sessionId: 's',
        message: 'hola',
        context: _context(),
        accessToken: 'token',
      ),
      throwsA(isA<T>()),
    );
  }

  test('401 -> CoachUnauthorizedException', () async {
    await expectMapsToException<CoachUnauthorizedException>(
      401,
      'unauthorized',
    );
  });

  test('403 -> CoachForbiddenException', () async {
    await expectMapsToException<CoachForbiddenException>(403, 'forbidden');
  });

  test('429 -> CoachRateLimitedException con retryAfterSeconds', () async {
    final client = MockClient(
      (request) async => http.Response(
        jsonEncode({
          'error': {'code': 'rate_limited', 'message': 'Aguantá un toque'},
        }),
        429,
        headers: {'retry-after': '42'},
      ),
    );
    final gateway = HttpCoachGateway(
      baseUrl: 'https://coach.example.com',
      client: client,
    );

    try {
      await gateway.sendMessage(
        sessionId: 's',
        message: 'hola',
        context: _context(),
        accessToken: 'token',
      );
      fail('debia lanzar CoachRateLimitedException');
    } on CoachRateLimitedException catch (e) {
      expect(e.retryAfterSeconds, 42);
    }
  });

  test('400 invalid_request -> CoachInvalidContextException', () async {
    await expectMapsToException<CoachInvalidContextException>(
      400,
      'invalid_request',
    );
  });

  test('400 context_too_large -> CoachInvalidContextException', () async {
    await expectMapsToException<CoachInvalidContextException>(
      400,
      'context_too_large',
    );
  });

  test('503 llm_unavailable -> CoachUnavailableException', () async {
    await expectMapsToException<CoachUnavailableException>(
      503,
      'llm_unavailable',
    );
  });

  test('504 timeout -> CoachTimeoutException', () async {
    await expectMapsToException<CoachTimeoutException>(504, 'timeout');
  });

  test('timeout de cliente -> CoachTimeoutException', () async {
    final client = MockClient((request) async {
      await Future<void>.delayed(const Duration(milliseconds: 50));
      return http.Response('{}', 200);
    });
    final gateway = HttpCoachGateway(
      baseUrl: 'https://coach.example.com',
      client: client,
      timeout: const Duration(milliseconds: 5),
    );

    await expectLater(
      () => gateway.sendMessage(
        sessionId: 's',
        message: 'hola',
        context: _context(),
        accessToken: 'token',
      ),
      throwsA(isA<CoachTimeoutException>()),
    );
  });

  test('checkStatus true cuando available:true', () async {
    final client = MockClient((request) async {
      expect(request.url.path, '/api/v1/coach/status');
      return http.Response(jsonEncode({'available': true}), 200);
    });
    final gateway = HttpCoachGateway(
      baseUrl: 'https://coach.example.com',
      client: client,
    );
    expect(await gateway.checkStatus(), true);
  });

  test('checkStatus false si la respuesta no es 200', () async {
    final client = MockClient((request) async => http.Response('', 500));
    final gateway = HttpCoachGateway(
      baseUrl: 'https://coach.example.com',
      client: client,
    );
    expect(await gateway.checkStatus(), false);
  });

  test('checkStatus false si hay un error de red (nunca lanza)', () async {
    final client = MockClient((request) async => throw Exception('no network'));
    final gateway = HttpCoachGateway(
      baseUrl: 'https://coach.example.com',
      client: client,
    );
    expect(await gateway.checkStatus(), false);
  });
}
