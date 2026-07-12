import 'package:appgym/core/coach/coach_context_builder.dart';
import 'package:appgym/core/coach/coach_context_source.dart';
import 'package:appgym/core/coach/coach_exception.dart';
import 'package:appgym/core/coach/coach_gateway.dart';
import 'package:appgym/models/coach_context.dart';
import 'package:appgym/models/gamification.dart';
import 'package:appgym/models/goal.dart';
import 'package:appgym/models/profile.dart';
import 'package:appgym/models/recovery.dart';
import 'package:appgym/models/stats.dart';
import 'package:appgym/repositories/coach_repository.dart';
import 'package:flutter_test/flutter_test.dart';

class _EmptyCoachContextSource implements CoachContextSource {
  @override
  bool socialAvailable = true;

  @override
  Future<Profile?> loadProfile() async => null;

  @override
  Future<List<Goal>> loadGoals() async => [];

  @override
  Future<RecoveryIndex?> loadRecovery() async => null;

  @override
  Future<StrengthProfile> loadStrengthProfile() async => StrengthProfile(
    maxStrengthByExercise: const [],
    weeklyVolumeKg: 0,
    weeklyFrequencyByMuscle: const [],
  );

  @override
  Future<TrainingStreak> loadStreak() async =>
      TrainingStreak(currentStreakDays: 0, longestStreakDays: 0);

  @override
  Future<GamificationProfile> loadGamification() async => GamificationProfile(
    level: 1,
    levelBand: 'novice',
    totalXp: 0,
    xpToNextLevel: 100,
    progressPct: 0,
    sessionsCompleted: 0,
    recordsCount: 0,
    longestStreakDays: 0,
    lifetimeTonnageKg: 0,
    achievements: const [],
  );

  @override
  Future<List<RawWorkoutSession>> loadRecentWorkoutSessions({
    required int maxSessions,
    required DateTime since,
  }) async => [];

  @override
  Future<List<RawPersonalRecord>> loadPersonalRecords() async => [];
}

class _FakeGateway implements CoachGateway {
  CoachContext? lastContext;
  String? lastSessionId;
  String? lastMessage;
  String? lastToken;
  CoachReply Function()? replyBuilder;
  Object? throwOnSend;

  @override
  Future<CoachReply> sendMessage({
    required String sessionId,
    required String message,
    required CoachContext context,
    required String accessToken,
  }) async {
    lastSessionId = sessionId;
    lastMessage = message;
    lastContext = context;
    lastToken = accessToken;
    if (throwOnSend != null) throw throwOnSend!;
    return (replyBuilder ??
        () => const CoachReply(
          text: 'ok',
          model: 'fake',
          usage: CoachUsage(
            promptTokens: 1,
            completionTokens: 1,
            totalTokens: 2,
          ),
        ))();
  }

  @override
  Future<bool> checkStatus() async => true;
}

void main() {
  late _FakeGateway gateway;
  late CoachContextBuilder builder;

  setUp(() {
    gateway = _FakeGateway();
    builder = CoachContextBuilder(source: _EmptyCoachContextSource());
  });

  test(
    'sendMessage arma el contexto y lo manda con el mismo sessionId',
    () async {
      final repository = CoachRepository(
        contextBuilder: builder,
        gateway: gateway,
        accessTokenProvider: () => 'token-abc',
      );

      final reply = await repository.sendMessage('¿Cómo voy?');

      expect(reply.text, 'ok');
      expect(gateway.lastMessage, '¿Cómo voy?');
      expect(gateway.lastToken, 'token-abc');
      expect(gateway.lastSessionId, repository.sessionId);
      expect(gateway.lastContext, isNotNull);
    },
  );

  test(
    'el sessionId se mantiene estable entre mensajes de la misma conversacion',
    () async {
      final repository = CoachRepository(
        contextBuilder: builder,
        gateway: gateway,
        accessTokenProvider: () => 'token-abc',
      );

      await repository.sendMessage('primero');
      final firstSessionId = gateway.lastSessionId;
      await repository.sendMessage('segundo');

      expect(gateway.lastSessionId, firstSessionId);
    },
  );

  test(
    'sin token de acceso, levanta CoachUnauthorizedException sin llamar al gateway',
    () async {
      final repository = CoachRepository(
        contextBuilder: builder,
        gateway: gateway,
        accessTokenProvider: () => null,
      );

      await expectLater(
        () => repository.sendMessage('hola'),
        throwsA(isA<CoachUnauthorizedException>()),
      );
      expect(gateway.lastMessage, isNull);
    },
  );

  test('propaga las CoachException del gateway tal cual', () async {
    gateway.throwOnSend = const CoachRateLimitedException('esperá', 10);
    final repository = CoachRepository(
      contextBuilder: builder,
      gateway: gateway,
      accessTokenProvider: () => 'token-abc',
    );

    await expectLater(
      () => repository.sendMessage('hola'),
      throwsA(isA<CoachRateLimitedException>()),
    );
  });

  test('checkStatus delega en el gateway', () async {
    final repository = CoachRepository(
      contextBuilder: builder,
      gateway: gateway,
      accessTokenProvider: () => 'token-abc',
    );
    expect(await repository.checkStatus(), true);
  });

  test('genera un sessionId propio (uuid v4) si no se le pasa uno', () {
    final repository = CoachRepository(
      contextBuilder: builder,
      gateway: gateway,
      accessTokenProvider: () => null,
    );
    expect(
      repository.sessionId,
      matches(
        RegExp(
          r'^[0-9a-f]{8}-[0-9a-f]{4}-4[0-9a-f]{3}-[89ab][0-9a-f]{3}-[0-9a-f]{12}$',
        ),
      ),
    );
  });
}
