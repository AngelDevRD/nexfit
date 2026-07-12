import 'dart:convert';

import 'package:flutter/foundation.dart';

import '../../models/coach_context.dart';
import 'coach_context_source.dart';

/// Version de la app expuesta en `CoachContext.app.version`. Sin
/// `package_info_plus` en el proyecto todavia -- mantener sincronizado a
/// mano con `pubspec.yaml` (hoy 1.0.1+2) hasta que se agregue ese paquete.
const _appVersion = '1.0.1';

/// Arma el `CoachContext` v1 -- **completamente puro**: no conoce HTTP,
/// Supabase, FastAPI, Groq ni ningun widget. Su unica responsabilidad es
/// transformar lo que devuelve un `CoachContextSource` en el objeto del
/// contrato (docs/COACH_CONTEXT.md), incluida la ventana acotada de
/// entrenamientos recientes y el recorte de tamaño si hiciera falta.
class CoachContextBuilder {
  final CoachContextSource source;
  final String appVersion;
  final DateTime Function() now;
  final String Function() platformName;

  static const maxRecentSessions = 10;
  static const maxRecentDays = 14;
  static const maxContextBytes = 15 * 1024;

  CoachContextBuilder({
    required this.source,
    this.appVersion = _appVersion,
    DateTime Function()? now,
    String Function()? platformName,
  }) : now = now ?? DateTime.now,
       platformName = platformName ?? _defaultPlatformName;

  Future<CoachContext> build({required String sessionId}) async {
    final generatedAt = now();
    final since = generatedAt.subtract(const Duration(days: maxRecentDays));

    final profile = await source.loadProfile();
    final goals = await source.loadGoals();
    final recovery = await source.loadRecovery();
    final strengthProfile = await source.loadStrengthProfile();
    final streak = await source.loadStreak();
    final gamification = await source.loadGamification();
    final rawSessions = await source.loadRecentWorkoutSessions(
      maxSessions: maxRecentSessions,
      since: since,
    );
    final rawRecords = await source.loadPersonalRecords();

    final context = CoachContext(
      sessionId: sessionId,
      generatedAt: generatedAt,
      app: CoachAppMetadata(
        version: appVersion,
        platform: platformName(),
        timezone: _formatOffset(generatedAt.timeZoneOffset),
      ),
      profile: CoachProfile(
        name: profile?.name ?? '',
        age: profile?.age,
        sex: profile?.sex,
        heightCm: profile?.heightCm,
        weightKg: profile?.weightKg,
        bodyFatPct: profile?.bodyFatPct,
      ),
      preferences: CoachPreferences(
        goal: profile?.goal,
        experienceLevel: profile?.experienceLevel,
        // Sin concepto de "rutina activa" todavia (RoutineRepository solo
        // expone list()/get(id)) -- queda null hasta que exista una forma
        // no ambigua de derivarlo.
        trainingDaysPerWeek: null,
      ),
      settings: const CoachSettings(
        language: 'es',
        units: 'metric',
        notificationsEnabled: null,
      ),
      capabilities: CoachCapabilities(social: source.socialAvailable),
      goals: [
        for (final g in goals)
          CoachGoal(
            title: g.title,
            metric: g.metric,
            progressPct: g.progressPct,
            achieved: g.achieved,
            targetDate: g.targetDate,
          ),
      ],
      recovery: recovery == null
          ? null
          : CoachRecovery(
              recoveryIndex: recovery.recoveryIndex,
              level: recovery.level,
              sleepHours: recovery.sleepHours,
              perceivedFatigue: recovery.perceivedFatigue,
              checkinDate: recovery.checkinDate,
            ),
      stats: CoachStats(
        weeklyVolumeKg: strengthProfile.weeklyVolumeKg,
        currentStreakDays: streak.currentStreakDays,
        longestStreakDays: streak.longestStreakDays,
        maxStrengthByExercise: [
          for (final e in strengthProfile.maxStrengthByExercise)
            CoachMaxStrengthEntry(
              exerciseName: e.exerciseName,
              maxWeightKg: e.maxWeightKg,
            ),
        ],
      ),
      recentWorkouts: _summarizeSessions(rawSessions),
      personalRecords: [
        for (final r in rawRecords)
          CoachPersonalRecord(
            exerciseName: r.exerciseName,
            recordType: r.recordType,
            value: r.value,
            achievedAt: r.achievedAt,
          ),
      ],
      achievements: CoachAchievements(
        level: gamification.level,
        levelBand: gamification.levelBand,
        totalXp: gamification.totalXp,
        unlocked: [
          for (final a in gamification.achievements)
            if (a.unlocked) a.code,
        ],
      ),
    );

    return _enforceSizeBudget(context);
  }

  List<CoachRecentWorkout> _summarizeSessions(
    List<RawWorkoutSession> sessions,
  ) => [
    for (final session in sessions)
      CoachRecentWorkout(
        date: session.date,
        totalVolumeKg: session.sets.fold(
          0.0,
          (sum, s) => sum + s.weightKg * s.reps,
        ),
        exerciseSummaries: _condenseExercises(session.sets),
      ),
  ];

  /// Un resumen por ejercicio (el set de mayor peso), no serie por serie --
  /// ver docs/COACH_CONTEXT.md "Contexto resumido, no volcado completo".
  List<String> _condenseExercises(List<RawWorkoutSet> sets) {
    final topSetByExercise = <String, RawWorkoutSet>{};
    for (final set in sets) {
      final current = topSetByExercise[set.exerciseName];
      if (current == null || set.weightKg > current.weightKg) {
        topSetByExercise[set.exerciseName] = set;
      }
    }
    return [
      for (final entry in topSetByExercise.entries)
        '${entry.key} ${_formatWeight(entry.value.weightKg)}kg x '
            '${entry.value.reps} reps',
    ];
  }

  String _formatWeight(double kg) =>
      kg == kg.roundToDouble() ? kg.toInt().toString() : kg.toString();

  /// Aplica el orden de recorte de docs/COACH_CONTEXT.md si el contexto
  /// supera el presupuesto de 15KB: 1) recentWorkouts de 10 a 5 sesiones,
  /// 2) maximo 3 resumenes por sesion, 3) personalRecords a los 5 mas
  /// recientes.
  CoachContext _enforceSizeBudget(CoachContext context) {
    var current = context;
    if (_byteSize(current) <= maxContextBytes) return current;

    if (current.recentWorkouts.length > 5) {
      current = current.copyWith(
        recentWorkouts: current.recentWorkouts.take(5).toList(),
      );
      if (_byteSize(current) <= maxContextBytes) return current;
    }

    current = current.copyWith(
      recentWorkouts: [
        for (final w in current.recentWorkouts)
          CoachRecentWorkout(
            date: w.date,
            totalVolumeKg: w.totalVolumeKg,
            exerciseSummaries: w.exerciseSummaries.take(3).toList(),
          ),
      ],
    );
    if (_byteSize(current) <= maxContextBytes) return current;

    final sortedRecords = [...current.personalRecords]
      ..sort((a, b) => b.achievedAt.compareTo(a.achievedAt));
    return current.copyWith(personalRecords: sortedRecords.take(5).toList());
  }

  int _byteSize(CoachContext context) =>
      utf8.encode(jsonEncode(context.toJson())).length;

  static String _defaultPlatformName() {
    if (kIsWeb) return 'web';
    return defaultTargetPlatform == TargetPlatform.iOS ? 'ios' : 'android';
  }

  static String _formatOffset(Duration offset) {
    final sign = offset.isNegative ? '-' : '+';
    final abs = offset.abs();
    final hours = abs.inHours.toString().padLeft(2, '0');
    final minutes = (abs.inMinutes % 60).toString().padLeft(2, '0');
    return '$sign$hours:$minutes';
  }
}
