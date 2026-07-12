import 'dart:convert';
import 'dart:io';

import 'package:drift/drift.dart';
import 'package:file_picker/file_picker.dart';

import '../core/local/database.dart' as local;

/// Se lanza cuando el archivo elegido no tiene la forma mínima de un backup
/// de NexFit (falta `version` o `data`).
class InvalidBackupFileException implements Exception {
  final String message;
  const InvalidBackupFileException(this.message);

  @override
  String toString() => message;
}

/// Importa un backup generado por [DataExportService] -- reemplaza al
/// `DataTransferService` (FastAPI) de la Fase 4.
///
/// `importEnvelope()` es la parte pura (recibe el Map ya decodificado, sin
/// tocar el sistema de archivos) para poder testearla; `importAll()` la
/// envuelve con el selector de archivos.
///
/// Mismas reglas que tenía el backend: rutinas/entrenamientos/metas se crean
/// siempre de cero (no mergean con lo existente); nutrition_logs y
/// daily_checkins tienen una fecha "natural" por registro, así que una fecha
/// ya cargada se omite en vez de duplicarse. Cualquier campo/entidad
/// desconocida en el JSON (de una versión futura del formato) se ignora en
/// silencio -- forward compatibility, ver docs/ARQUITECTURA_BACKEND.md.
class DataImportService {
  final local.AppDatabase db;

  DataImportService(this.db);

  Future<Map<String, dynamic>?> importAll() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json'],
    );
    if (result == null || result.files.single.path == null) return null;

    final file = File(result.files.single.path!);
    final content = await file.readAsString();
    final envelope = jsonDecode(content) as Map<String, dynamic>;
    return importEnvelope(envelope);
  }

  Future<Map<String, dynamic>> importEnvelope(
    Map<String, dynamic> envelope,
  ) async {
    if (envelope['version'] == null) {
      throw const InvalidBackupFileException(
        'El archivo no tiene un campo "version" -- no parece un backup de NexFit.',
      );
    }
    final data = envelope['data'] as Map<String, dynamic>?;
    if (data == null) {
      throw const InvalidBackupFileException(
        'El archivo no tiene la sección "data" esperada.',
      );
    }

    return db.transaction(() async {
      final routineIds = await _importRoutines(
        (data['routines'] as List?) ?? const [],
      );
      final sessionsCreated = await _importSessions(
        (data['workout_sessions'] as List?) ?? const [],
        routineIds,
      );
      final nutrition = await _importNutritionLogs(
        (data['nutrition_logs'] as List?) ?? const [],
      );
      final checkins = await _importCheckins(
        (data['daily_checkins'] as List?) ?? const [],
      );
      final goalsCreated = await _importGoals(
        (data['goals'] as List?) ?? const [],
      );

      return {
        'routines_created': routineIds.length,
        'workout_sessions_created': sessionsCreated.sessions,
        'workout_sets_created': sessionsCreated.sets,
        'nutrition_logs_created': nutrition.created,
        'nutrition_logs_skipped': nutrition.skipped,
        'daily_checkins_created': checkins.created,
        'daily_checkins_skipped': checkins.skipped,
        'goals_created': goalsCreated,
      };
    });
  }

  Future<List<int>> _importRoutines(List<dynamic> routines) async {
    final ids = <int>[];
    for (final raw in routines) {
      final routine = raw as Map<String, dynamic>;
      final routineId = await db
          .into(db.routines)
          .insert(
            local.RoutinesCompanion.insert(
              name: routine['name'] as String,
              goal: Value(routine['goal'] as String?),
              daysPerWeek: Value(
                (routine['days_per_week'] as num?)?.toInt() ?? 3,
              ),
              updatedAt: DateTime.now(),
            ),
          );
      ids.add(routineId);

      for (final rawDay in (routine['days'] as List? ?? const [])) {
        final day = rawDay as Map<String, dynamic>;
        final dayId = await db
            .into(db.routineDays)
            .insert(
              local.RoutineDaysCompanion.insert(
                routineId: routineId,
                dayIndex: (day['day_index'] as num).toInt(),
                name: day['name'] as String,
                muscleFocus: Value(day['muscle_focus'] as String?),
              ),
            );

        for (final rawEx in (day['exercises'] as List? ?? const [])) {
          final ex = rawEx as Map<String, dynamic>;
          await db
              .into(db.routineExercises)
              .insert(
                local.RoutineExercisesCompanion.insert(
                  dayId: dayId,
                  exerciseId: (ex['exercise_id'] as num).toInt(),
                  orderIndex: (ex['order'] as num).toInt(),
                  targetSets: Value((ex['target_sets'] as num?)?.toInt() ?? 3),
                  targetRepsMin: Value(
                    (ex['target_reps_min'] as num?)?.toInt() ?? 8,
                  ),
                  targetRepsMax: Value(
                    (ex['target_reps_max'] as num?)?.toInt() ?? 12,
                  ),
                  targetRestSeconds: Value(
                    (ex['target_rest_seconds'] as num?)?.toInt() ?? 90,
                  ),
                  notes: Value(ex['notes'] as String?),
                ),
              );
        }
      }
    }
    return ids;
  }

  Future<({int sessions, int sets})> _importSessions(
    List<dynamic> sessions,
    List<int> routineIds,
  ) async {
    var setsCreated = 0;
    for (final raw in sessions) {
      final session = raw as Map<String, dynamic>;
      final routineIndex = (session['routine_index'] as num?)?.toInt();
      final routineId =
          (routineIndex != null && routineIndex < routineIds.length)
          ? routineIds[routineIndex]
          : null;

      final now = DateTime.now();
      final sessionId = await db
          .into(db.workoutSessions)
          .insert(
            local.WorkoutSessionsCompanion.insert(
              routineId: Value(routineId),
              startedAt: DateTime.parse(session['started_at'] as String),
              endedAt: Value(
                session['ended_at'] != null
                    ? DateTime.parse(session['ended_at'] as String)
                    : null,
              ),
              notes: Value(session['notes'] as String?),
              updatedAt: now,
            ),
          );

      for (final rawSet in (session['sets'] as List? ?? const [])) {
        final set = rawSet as Map<String, dynamic>;
        await db
            .into(db.workoutSets)
            .insert(
              local.WorkoutSetsCompanion.insert(
                sessionId: sessionId,
                exerciseId: (set['exercise_id'] as num).toInt(),
                setNumber: (set['set_number'] as num).toInt(),
                weightKg: Value((set['weight_kg'] as num?)?.toDouble() ?? 0),
                reps: Value((set['reps'] as num?)?.toInt() ?? 0),
                rpe: Value((set['rpe'] as num?)?.toDouble()),
                rir: Value((set['rir'] as num?)?.toInt()),
                restSeconds: Value((set['rest_seconds'] as num?)?.toInt()),
                techniques: Value(jsonEncode(set['techniques'] ?? const [])),
                supersetGroupId: Value(
                  (set['superset_group_id'] as num?)?.toInt(),
                ),
                tempo: Value(set['tempo'] as String?),
                isWarmup: Value(set['is_warmup'] as bool? ?? false),
                notes: Value(set['notes'] as String?),
              ),
            );
        setsCreated += 1;
      }
    }
    return (sessions: sessions.length, sets: setsCreated);
  }

  Future<({int created, int skipped})> _importNutritionLogs(
    List<dynamic> logs,
  ) async {
    var created = 0;
    var skipped = 0;
    for (final raw in logs) {
      final log = raw as Map<String, dynamic>;
      final date = DateTime.parse(log['log_date'] as String);
      final existing = await (db.select(
        db.nutritionLogs,
      )..where((t) => t.logDate.equals(date))).getSingleOrNull();
      if (existing != null) {
        skipped += 1;
        continue;
      }
      await db
          .into(db.nutritionLogs)
          .insert(
            local.NutritionLogsCompanion.insert(
              logDate: date,
              calories: Value((log['calories'] as num?)?.toDouble() ?? 0),
              proteinG: Value((log['protein_g'] as num?)?.toDouble() ?? 0),
              carbsG: Value((log['carbs_g'] as num?)?.toDouble() ?? 0),
              fatG: Value((log['fat_g'] as num?)?.toDouble() ?? 0),
              waterMl: Value((log['water_ml'] as num?)?.toDouble() ?? 0),
              notes: Value(log['notes'] as String?),
              updatedAt: DateTime.now(),
            ),
          );
      created += 1;
    }
    return (created: created, skipped: skipped);
  }

  Future<({int created, int skipped})> _importCheckins(
    List<dynamic> checkins,
  ) async {
    var created = 0;
    var skipped = 0;
    for (final raw in checkins) {
      final checkin = raw as Map<String, dynamic>;
      final date = DateTime.parse(checkin['checkin_date'] as String);
      final existing = await (db.select(
        db.dailyCheckins,
      )..where((t) => t.checkinDate.equals(date))).getSingleOrNull();
      if (existing != null) {
        skipped += 1;
        continue;
      }
      await db
          .into(db.dailyCheckins)
          .insert(
            local.DailyCheckinsCompanion.insert(
              checkinDate: date,
              sleepHours: (checkin['sleep_hours'] as num).toDouble(),
              perceivedFatigue: (checkin['perceived_fatigue'] as num).toInt(),
              updatedAt: DateTime.now(),
            ),
          );
      created += 1;
    }
    return (created: created, skipped: skipped);
  }

  Future<int> _importGoals(List<dynamic> goals) async {
    for (final raw in goals) {
      final goal = raw as Map<String, dynamic>;
      await db
          .into(db.goals)
          .insert(
            local.GoalsCompanion.insert(
              title: goal['title'] as String,
              metric: goal['metric'] as String,
              exerciseId: Value((goal['exercise_id'] as num?)?.toInt()),
              startingValue: (goal['starting_value'] as num).toDouble(),
              targetValue: (goal['target_value'] as num).toDouble(),
              targetDate: Value(
                goal['target_date'] != null
                    ? DateTime.parse(goal['target_date'] as String)
                    : null,
              ),
              achievedAt: Value(
                goal['achieved_at'] != null
                    ? DateTime.parse(goal['achieved_at'] as String)
                    : null,
              ),
              updatedAt: DateTime.now(),
            ),
          );
    }
    return goals.length;
  }
}
