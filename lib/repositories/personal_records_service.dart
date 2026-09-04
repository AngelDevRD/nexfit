import 'package:drift/drift.dart';

import '../core/local/database.dart' as local;

/// Un set mínimo para el cálculo de récords: solo lo que importa (ejercicio,
/// peso, reps, si es calentamiento, cuándo y en qué sesión). Desacopla el
/// núcleo puro de las filas generadas por Drift para poder testearlo sin base.
class RecordInput {
  final int exerciseId;
  final double weightKg;
  final int reps;
  final bool isWarmup;
  final DateTime achievedAt;
  final int sessionId;
  final int setId;

  const RecordInput({
    required this.exerciseId,
    required this.weightKg,
    required this.reps,
    required this.isWarmup,
    required this.achievedAt,
    required this.sessionId,
    required this.setId,
  });
}

/// Un récord ya resuelto: valor vigente para un (ejercicio, tipo), con la
/// sesión y la fecha en que se logró y el valor anterior que superó.
class ResolvedRecord {
  final int exerciseId;
  final String recordType; // 'max_weight' | 'max_reps'
  final double value;
  final double? previousValue;
  final DateTime achievedAt;
  final int sessionId;
  final int setId;

  const ResolvedRecord({
    required this.exerciseId,
    required this.recordType,
    required this.value,
    required this.previousValue,
    required this.achievedAt,
    required this.sessionId,
    required this.setId,
  });
}

/// Replaya todos los sets en orden cronológico y emite un evento de récord por
/// **cada vez** que un set superó el máximo previo del ejercicio (la
/// progresión completa, no sólo el último). Función pura: misma entrada ->
/// misma salida, sin tocar la base.
///
/// Emitir toda la progresión (y no colapsarla al máximo) es deliberado: la
/// serie temporal alimenta la predicción de récords (regresión lineal). Para
/// "el récord vigente" se agrupa con [currentRecords].
///
/// Los calentamientos se ignoran. Un set puede establecer a la vez récord de
/// peso y de reps. Sólo cuenta si supera **estrictamente** el máximo previo
/// (empatar no es récord).
List<ResolvedRecord> computeRecords(List<RecordInput> sets) {
  final ordered = [...sets]
    ..sort((a, b) => a.achievedAt.compareTo(b.achievedAt));

  final maxWeight = <int, double>{};
  final maxReps = <int, int>{};
  final events = <ResolvedRecord>[];

  for (final set in ordered) {
    // Los calentamientos y las series placeholder en 0/0 (todavía sin editar
    // por el usuario) no cuentan -- ver C2. Sin este guard, `rebuildAll`
    // resucitaría PRs de 0kg/0 reps desde sets abandonados en 0.
    if (set.isWarmup || set.weightKg <= 0 || set.reps <= 0) continue;

    final prevWeight = maxWeight[set.exerciseId];
    if (prevWeight == null || set.weightKg > prevWeight) {
      events.add(
        ResolvedRecord(
          exerciseId: set.exerciseId,
          recordType: 'max_weight',
          value: set.weightKg,
          previousValue: prevWeight,
          achievedAt: set.achievedAt,
          sessionId: set.sessionId,
          setId: set.setId,
        ),
      );
      maxWeight[set.exerciseId] = set.weightKg;
    }

    final prevReps = maxReps[set.exerciseId];
    if (prevReps == null || set.reps > prevReps) {
      events.add(
        ResolvedRecord(
          exerciseId: set.exerciseId,
          recordType: 'max_reps',
          value: set.reps.toDouble(),
          previousValue: prevReps?.toDouble(),
          achievedAt: set.achievedAt,
          sessionId: set.sessionId,
          setId: set.setId,
        ),
      );
      maxReps[set.exerciseId] = set.reps;
    }
  }

  return events;
}

/// Agrupa una bitácora de récords al **récord vigente** por (ejercicio, tipo):
/// el de mayor valor. Es la deduplicación para mostrar "🏆 récords" sin repetir
/// el mismo ejercicio -- se hace en presentación, sin tocar la historia.
List<ResolvedRecord> currentRecords(List<ResolvedRecord> log) {
  final best = <String, ResolvedRecord>{};
  for (final r in log) {
    final key = '${r.exerciseId}:${r.recordType}';
    final current = best[key];
    if (current == null || r.value > current.value) best[key] = r;
  }
  return best.values.toList();
}

/// Detección y persistencia de récords personales. Extrae la lógica que vivía
/// inline en [WorkoutRepository]. Acá:
///
///  - [evaluateSet] inserta un evento de récord cuando un set supera el máximo
///    previo, con la fecha y sesión reales, y devuelve los récords nuevos para
///    avisarle al usuario.
///  - [rebuildAll] vacía y reconstruye la bitácora completa desde los sets
///    guardados. La usa la importación (Fase 4) y repara datos viejos (los que
///    tenían `achievedAt` = momento de importar).
class PersonalRecordsService {
  final local.AppDatabase db;

  PersonalRecordsService(this.db);

  /// Evalúa un set contra los máximos previos del ejercicio y hace upsert de
  /// los récords que supere. Devuelve los récords nuevos (peso y/o reps) para
  /// que la UI los muestre; lista vacía si no rompió ninguno.
  ///
  /// [setId] identifica la serie que se está evaluando: antes de calcular,
  /// se borra cualquier fila que ESTA MISMA serie haya generado antes. Así,
  /// reevaluar un set (p. ej. completarlo, editarlo, completarlo de nuevo)
  /// reemplaza su propia fila en vez de acumular una nueva cada vez.
  ///
  /// Este método se llama UNA VEZ por acción del usuario (completar una
  /// serie, o el replay de `rebuildAll`), nunca en cada escritura intermedia
  /// -- ver la regresión documentada en `WorkoutRepository.updateSet`: si se
  /// llama en cada toque de un stepper, 32 toques de +2.5kg generan 32 filas
  /// para una sola serie.
  Future<List<ResolvedRecord>> evaluateSet({
    required int exerciseId,
    required double weightKg,
    required int reps,
    required int sessionId,
    required int setId,
    required DateTime achievedAt,
  }) async {
    await (db.delete(
      db.personalRecords,
    )..where((t) => t.setId.equals(setId))).go();

    // Máximos previos del ejercicio (el mayor de la bitácora, ya sin la fila
    // de esta serie), contra los que se compara el set. Se lee de la tabla de
    // récords, no de todos los sets: es O(nº de récords del ejercicio), no
    // O(historial completo).
    final existing = await (db.select(
      db.personalRecords,
    )..where((t) => t.exerciseId.equals(exerciseId))).get();
    double? prevWeight;
    double? prevReps;
    for (final r in existing) {
      if (r.recordType == 'max_weight') {
        prevWeight = prevWeight == null || r.value > prevWeight
            ? r.value
            : prevWeight;
      }
      if (r.recordType == 'max_reps') {
        prevReps = prevReps == null || r.value > prevReps ? r.value : prevReps;
      }
    }

    final fresh = <ResolvedRecord>[];
    if (prevWeight == null || weightKg > prevWeight) {
      fresh.add(
        ResolvedRecord(
          exerciseId: exerciseId,
          recordType: 'max_weight',
          value: weightKg,
          previousValue: prevWeight,
          achievedAt: achievedAt,
          sessionId: sessionId,
          setId: setId,
        ),
      );
    }
    if (prevReps == null || reps > prevReps) {
      fresh.add(
        ResolvedRecord(
          exerciseId: exerciseId,
          recordType: 'max_reps',
          value: reps.toDouble(),
          previousValue: prevReps,
          achievedAt: achievedAt,
          sessionId: sessionId,
          setId: setId,
        ),
      );
    }

    for (final record in fresh) {
      await _insertEvent(record);
    }
    return fresh;
  }

  /// Vacía la tabla y la reconstruye replayando todos los sets guardados en
  /// orden cronológico. Idempotente. La lógica de decisión es [computeRecords]
  /// (pura, testeada); acá solo se hace la E/S contra la base.
  Future<void> rebuildAll() async {
    final setRows = await db.select(db.workoutSets).get();
    final sessions = await db.select(db.workoutSessions).get();
    final startedById = {for (final s in sessions) s.id: s.startedAt};

    final inputs = <RecordInput>[
      for (final s in setRows)
        RecordInput(
          exerciseId: s.exerciseId,
          weightKg: s.weightKg,
          reps: s.reps,
          isWarmup: s.isWarmup,
          // La fecha del récord es la de la sesión, no `DateTime.now()`: así
          // los PRs quedan anclados al día real en que se lograron.
          achievedAt: startedById[s.sessionId] ?? DateTime.now(),
          sessionId: s.sessionId,
          setId: s.id,
        ),
    ];

    final records = computeRecords(inputs);

    await db.transaction(() async {
      await db.delete(db.personalRecords).go();
      for (final record in records) {
        await _insertEvent(record);
      }
    });
  }

  Future<void> _insertEvent(ResolvedRecord record) async {
    await db
        .into(db.personalRecords)
        .insert(
          local.PersonalRecordsCompanion.insert(
            exerciseId: Value(record.exerciseId),
            sessionId: Value(record.sessionId),
            setId: Value(record.setId),
            recordType: record.recordType,
            value: record.value,
            previousValue: Value(record.previousValue),
            achievedAt: record.achievedAt,
          ),
        );
  }
}
