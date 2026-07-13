import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/features/import_export/domain/import_export_models.dart';
import 'package:appgym/features/measurements_import/data/measurement_import_engine.dart';
import 'package:appgym/features/measurements_import/data/measurement_mapper.dart';
import 'package:appgym/features/measurements_import/data/measurement_validator.dart';
import 'package:appgym/repositories/body_measurement_repository.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cubre el importador de medidas corporales con la forma real de
/// `measurement_data.csv`: encabezados `weight_kg`/`waist_cm`/... y fecha en
/// espanol abreviado con hora ("11 feb 2026, 00:00").
void main() {
  ParsedDataset realShapeDataset() {
    return const ParsedDataset(
      format: ImportSourceFormat.csv,
      sourceFileName: 'measurement_data.csv',
      columns: [
        'date',
        'weight_kg',
        'fat_percent',
        'neck_cm',
        'shoulder_cm',
        'chest_cm',
        'left_bicep_cm',
        'right_bicep_cm',
        'left_forearm_cm',
        'right_forearm_cm',
        'abdomen_cm',
        'waist_cm',
        'hips_cm',
        'left_thigh_cm',
        'right_thigh_cm',
        'left_calf_cm',
        'right_calf_cm',
      ],
      records: [
        RawRecord(
          rowIndex: 1,
          values: {
            'date': '11 feb 2026, 00:00',
            'weight_kg': '73.48',
            'fat_percent': null,
            'neck_cm': null,
            'shoulder_cm': null,
            'chest_cm': null,
            'left_bicep_cm': null,
            'right_bicep_cm': null,
            'left_forearm_cm': null,
            'right_forearm_cm': null,
            'abdomen_cm': null,
            'waist_cm': '81',
            'hips_cm': null,
            'left_thigh_cm': null,
            'right_thigh_cm': null,
            'left_calf_cm': null,
            'right_calf_cm': null,
          },
        ),
      ],
    );
  }

  test('mapea las columnas snake_case conocidas', () {
    final map = mapMeasurementColumns(realShapeDataset().columns);
    expect(map['weight_kg'], 'weight_kg');
    expect(map['waist_cm'], 'waist_cm');
    expect(map['date'], 'date');
  });

  test('valida sin error la fila real (fecha en espanol con hora)', () {
    final rows = MeasurementValidator().validate(realShapeDataset());

    expect(rows, hasLength(1));
    expect(rows.single.isValid, isTrue);
    expect(rows.single.date, DateTime(2026, 2, 11, 0, 0));
    expect(rows.single.fields['weight_kg'], 73.48);
    expect(rows.single.fields['waist_cm'], 81);
  });

  test('fila sin fecha queda invalida con mensaje claro', () {
    final dataset = realShapeDataset();
    final withoutDate = RawRecord(
      rowIndex: 1,
      values: {...dataset.records.single.values, 'date': ''},
    );
    final rows = MeasurementValidator().validate(
      ParsedDataset(
        format: dataset.format,
        sourceFileName: dataset.sourceFileName,
        columns: dataset.columns,
        records: [withoutDate],
      ),
    );

    expect(rows.single.isValid, isFalse);
    expect(rows.single.error, contains('fecha'));
  });

  test(
    'el engine importa la fila valida a BodyMeasurements y es idempotente',
    () async {
      final db = local.AppDatabase.forTesting(NativeDatabase.memory());
      final repository = BodyMeasurementRepository(db);
      final engine = MeasurementImportEngine(repository: repository);
      final rows = MeasurementValidator().validate(realShapeDataset());

      final first = await engine.import(rows);
      expect(first.imported, 1);
      expect(first.skipped, 0);

      // Reimportar el mismo archivo no duplica -- upsert por fecha.
      final second = await engine.import(rows);
      expect(second.imported, 1);

      final history = await repository.history();
      expect(history, hasLength(1));
      expect(history.single.weightKg, 73.48);
      expect(history.single.waistCm, 81);

      await db.close();
    },
  );
}
