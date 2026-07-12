import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';

import '../core/local/database.dart' as local;

/// Exporta todos los datos del usuario (rutinas, entrenamientos, nutrición,
/// check-ins, metas) como un backup .json, leyendo directamente de Drift --
/// reemplaza al `DataTransferService` (FastAPI) de la Fase 4.
///
/// `buildEnvelope()` es la parte pura (arma el Map, sin tocar el sistema de
/// archivos) para poder testearla sin I/O; `exportAll()` la envuelve con la
/// escritura a archivo temporal y la hoja de compartir nativa.
///
/// `version` es obligatoria en el JSON de salida (contrato de
/// forward-compatibility con `DataImportService`, ver docs/ARQUITECTURA_BACKEND.md).
class DataExportService {
  static const currentVersion = 1;

  final local.AppDatabase db;
  final String? userEmail;

  DataExportService(this.db, {this.userEmail});

  Future<Map<String, dynamic>> buildEnvelope() async {
    final profile = await db.select(db.profiles).getSingleOrNull();

    final routineRows = await (db.select(
      db.routines,
    )..where((t) => t.deleted.equals(false))).get();
    final routineIndexById = <int, int>{};
    final routinesJson = <Map<String, dynamic>>[];
    for (var i = 0; i < routineRows.length; i++) {
      final routine = routineRows[i];
      routineIndexById[routine.id] = i;
      routinesJson.add(await _routineToJson(routine));
    }

    final sessionRows =
        await (db.select(db.workoutSessions)
              ..where((t) => t.deleted.equals(false))
              ..orderBy([(t) => OrderingTerm.asc(t.startedAt)]))
            .get();
    final sessionsJson = <Map<String, dynamic>>[];
    for (final session in sessionRows) {
      sessionsJson.add(
        await _sessionToJson(session, routineIndexById[session.routineId]),
      );
    }

    final nutritionRows = await (db.select(
      db.nutritionLogs,
    )..orderBy([(t) => OrderingTerm.asc(t.logDate)])).get();
    final checkinRows = await (db.select(
      db.dailyCheckins,
    )..orderBy([(t) => OrderingTerm.asc(t.checkinDate)])).get();
    final goalRows = await (db.select(
      db.goals,
    )..where((t) => t.deleted.equals(false))).get();

    return {
      'version': currentVersion,
      'exported_at': DateTime.now().toUtc().toIso8601String(),
      'data': {
        'profile': {
          'name': profile?.name,
          'email': userEmail,
          'sex': profile?.sex,
          'age': profile?.age,
          'height_cm': profile?.heightCm,
          'weight_kg': profile?.weightKg,
          'body_fat_pct': profile?.bodyFatPct,
          'goal': profile?.goal,
          'experience_level': profile?.experienceLevel,
        },
        'routines': routinesJson,
        'workout_sessions': sessionsJson,
        'nutrition_logs': [for (final r in nutritionRows) _nutritionToJson(r)],
        'daily_checkins': [for (final r in checkinRows) _checkinToJson(r)],
        'goals': [for (final r in goalRows) _goalToJson(r)],
      },
    };
  }

  /// Pide confirmación al SO para compartir el backup ya armado en
  /// [buildEnvelope]. Escribe a un archivo temporal y abre la hoja de
  /// compartir nativa para que el usuario lo guarde donde quiera (Drive,
  /// Archivos, WhatsApp, etc.).
  Future<void> exportAll() async {
    final envelope = await buildEnvelope();
    final dir = await getTemporaryDirectory();
    final date = DateTime.now().toIso8601String().split('T').first;
    final file = File('${dir.path}/nexfit_backup_$date.json');
    await file.writeAsString(jsonEncode(envelope));
    await Share.shareXFiles([
      XFile(file.path),
    ], text: 'Backup de datos de NexFit');
  }

  Future<Map<String, dynamic>> _routineToJson(local.Routine routine) async {
    final dayRows = await (db.select(
      db.routineDays,
    )..where((t) => t.routineId.equals(routine.id))).get();
    dayRows.sort((a, b) => a.dayIndex.compareTo(b.dayIndex));

    final days = <Map<String, dynamic>>[];
    for (final day in dayRows) {
      final exerciseRows = await (db.select(
        db.routineExercises,
      )..where((t) => t.dayId.equals(day.id))).get();
      exerciseRows.sort((a, b) => a.orderIndex.compareTo(b.orderIndex));

      days.add({
        'day_index': day.dayIndex,
        'name': day.name,
        'muscle_focus': day.muscleFocus,
        'exercises': [
          for (final ex in exerciseRows)
            {
              'exercise_id': ex.exerciseId,
              'order': ex.orderIndex,
              'target_sets': ex.targetSets,
              'target_reps_min': ex.targetRepsMin,
              'target_reps_max': ex.targetRepsMax,
              'target_rest_seconds': ex.targetRestSeconds,
              'notes': ex.notes,
            },
        ],
      });
    }

    return {
      'name': routine.name,
      'goal': routine.goal,
      'days_per_week': routine.daysPerWeek,
      'days': days,
    };
  }

  Future<Map<String, dynamic>> _sessionToJson(
    local.WorkoutSession session,
    int? routineIndex,
  ) async {
    final setRows = await (db.select(
      db.workoutSets,
    )..where((t) => t.sessionId.equals(session.id))).get();

    return {
      'routine_index': routineIndex,
      'started_at': session.startedAt.toIso8601String(),
      'ended_at': session.endedAt?.toIso8601String(),
      'notes': session.notes,
      'sets': [
        for (final s in setRows)
          {
            'exercise_id': s.exerciseId,
            'set_number': s.setNumber,
            'weight_kg': s.weightKg,
            'reps': s.reps,
            'rpe': s.rpe,
            'rir': s.rir,
            'rest_seconds': s.restSeconds,
            'techniques': jsonDecode(s.techniques),
            'superset_group_id': s.supersetGroupId,
            'tempo': s.tempo,
            'is_warmup': s.isWarmup,
            'notes': s.notes,
          },
      ],
    };
  }

  Map<String, dynamic> _nutritionToJson(local.NutritionLog r) => {
    'log_date': r.logDate.toIso8601String(),
    'calories': r.calories,
    'protein_g': r.proteinG,
    'carbs_g': r.carbsG,
    'fat_g': r.fatG,
    'water_ml': r.waterMl,
    'notes': r.notes,
  };

  Map<String, dynamic> _checkinToJson(local.DailyCheckin r) => {
    'checkin_date': r.checkinDate.toIso8601String(),
    'sleep_hours': r.sleepHours,
    'perceived_fatigue': r.perceivedFatigue,
  };

  Map<String, dynamic> _goalToJson(local.Goal r) => {
    'title': r.title,
    'metric': r.metric,
    'exercise_id': r.exerciseId,
    'starting_value': r.startingValue,
    'target_value': r.targetValue,
    'target_date': r.targetDate?.toIso8601String(),
    'achieved_at': r.achievedAt?.toIso8601String(),
  };
}
