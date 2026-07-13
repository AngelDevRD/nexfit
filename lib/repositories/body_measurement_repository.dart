import 'package:drift/drift.dart';

import '../core/local/database.dart' as local;
import '../models/body_measurement.dart';

/// Historial de medidas corporales -- offline-first vía Drift, solo local
/// (sin sync a Supabase por ahora, ver comentario en `BodyMeasurements` en
/// `core/local/database.dart`). Un registro por día, mismo patrón
/// upsert-por-fecha que [RecoveryRepository]/[ProfileRepository].
///
/// [fields] usa las mismas claves snake_case que trae el CSV de origen
/// (weight_kg, fat_percent, neck_cm, ...) para que el importador de medidas
/// pueda pasar los valores parseados sin transformarlos.
class BodyMeasurementRepository {
  final local.AppDatabase db;

  BodyMeasurementRepository(this.db);

  DateTime _dateOnly(DateTime d) => DateTime(d.year, d.month, d.day);

  Future<List<BodyMeasurement>> history() async {
    final rows = await db.select(db.bodyMeasurements).get();
    rows.sort((a, b) => b.measuredAt.compareTo(a.measuredAt));
    return rows.map(_toModel).toList();
  }

  Future<void> upsertForDate(DateTime date, Map<String, double?> fields) async {
    final day = _dateOnly(date);
    final existing = await (db.select(
      db.bodyMeasurements,
    )..where((t) => t.measuredAt.equals(day))).getSingleOrNull();

    Value<double?> v(String key) =>
        fields.containsKey(key) ? Value(fields[key]) : const Value.absent();

    final companion = local.BodyMeasurementsCompanion(
      measuredAt: Value(day),
      weightKg: v('weight_kg'),
      fatPercent: v('fat_percent'),
      neckCm: v('neck_cm'),
      shoulderCm: v('shoulder_cm'),
      chestCm: v('chest_cm'),
      leftBicepCm: v('left_bicep_cm'),
      rightBicepCm: v('right_bicep_cm'),
      leftForearmCm: v('left_forearm_cm'),
      rightForearmCm: v('right_forearm_cm'),
      abdomenCm: v('abdomen_cm'),
      waistCm: v('waist_cm'),
      hipsCm: v('hips_cm'),
      leftThighCm: v('left_thigh_cm'),
      rightThighCm: v('right_thigh_cm'),
      leftCalfCm: v('left_calf_cm'),
      rightCalfCm: v('right_calf_cm'),
      updatedAt: Value(DateTime.now()),
    );

    if (existing == null) {
      await db.into(db.bodyMeasurements).insert(companion);
    } else {
      await (db.update(
        db.bodyMeasurements,
      )..where((t) => t.id.equals(existing.id))).write(companion);
    }
  }

  BodyMeasurement _toModel(local.BodyMeasurement row) => BodyMeasurement(
    measuredAt: row.measuredAt,
    weightKg: row.weightKg,
    fatPercent: row.fatPercent,
    neckCm: row.neckCm,
    shoulderCm: row.shoulderCm,
    chestCm: row.chestCm,
    leftBicepCm: row.leftBicepCm,
    rightBicepCm: row.rightBicepCm,
    leftForearmCm: row.leftForearmCm,
    rightForearmCm: row.rightForearmCm,
    abdomenCm: row.abdomenCm,
    waistCm: row.waistCm,
    hipsCm: row.hipsCm,
    leftThighCm: row.leftThighCm,
    rightThighCm: row.rightThighCm,
    leftCalfCm: row.leftCalfCm,
    rightCalfCm: row.rightCalfCm,
  );
}
