import 'package:appgym/features/import_export/data/auto_mapper.dart';
import 'package:appgym/features/import_export/data/preview_builder.dart';
import 'package:appgym/features/import_export/data/validators.dart';
import 'package:appgym/features/import_export/domain/import_export_models.dart';
import 'package:appgym/features/import_export/domain/mapping_models.dart';
import 'package:flutter_test/flutter_test.dart';

/// Cubre el formato de exportacion de Hevy (`workout_data.csv`): encabezados
/// distintos a los sinonimos originales (`exercise_title` en vez de
/// `exercise`, `start_time` en vez de `date`, `set_index` en vez de `set`) y
/// fechas en espanol abreviado ("10 jul 2026, 15:44") en lugar de ISO-8601.
void main() {
  ParsedDataset hevyDataset() {
    return const ParsedDataset(
      format: ImportSourceFormat.csv,
      sourceFileName: 'workout_data.csv',
      columns: [
        'title',
        'start_time',
        'end_time',
        'description',
        'exercise_title',
        'superset_id',
        'exercise_notes',
        'set_index',
        'set_type',
        'weight_kg',
        'reps',
        'distance_km',
        'duration_seconds',
        'rpe',
      ],
      records: [
        RawRecord(
          rowIndex: 1,
          values: {
            'title': 'Viernes pierna volumen',
            'start_time': '10 jul 2026, 15:44',
            'end_time': '10 jul 2026, 16:46',
            'description': '',
            'exercise_title': 'Sentadilla Hack (Máquina)',
            'superset_id': null,
            'exercise_notes': '',
            'set_index': '0',
            'set_type': 'normal',
            'weight_kg': '40.82',
            'reps': '10',
            'distance_km': null,
            'duration_seconds': null,
            'rpe': null,
          },
        ),
        RawRecord(
          rowIndex: 2,
          values: {
            'title': 'Viernes pierna volumen',
            'start_time': '1 jul 2026, 15:47',
            'end_time': '1 jul 2026, 16:43',
            'description': '',
            'exercise_title': 'Sentadilla Búlgara',
            'superset_id': null,
            'exercise_notes': '',
            'set_index': '0',
            'set_type': 'warmup',
            'weight_kg': '22.68',
            'reps': '7',
            'distance_km': null,
            'duration_seconds': null,
            'rpe': null,
          },
        ),
      ],
    );
  }

  test('mapea exercise_title/start_time/set_index a los campos canonicos', () {
    final mapping = AutoMapper().map(hevyDataset().columns);

    expect(mapping.fieldFor('exercise_title'), CanonicalField.exerciseName);
    expect(mapping.fieldFor('start_time'), CanonicalField.date);
    expect(mapping.fieldFor('set_index'), CanonicalField.setNumber);
    expect(mapping.fieldFor('weight_kg'), CanonicalField.weightKg);
    expect(mapping.fieldFor('reps'), CanonicalField.reps);
  });

  test(
    'valida sin errores un dataset real de Hevy (fecha en espanol abreviado)',
    () {
      final dataset = hevyDataset();
      final mapping = AutoMapper().map(dataset.columns);
      final validated = Validators().validate(dataset, mapping);
      final summary = PreviewBuilder().build(validated, mapping);

      expect(summary.recordsWithErrors, 0);
      expect(summary.validRecords, 2);
    },
  );

  test('la fecha en espanol abreviado se parsea al dia/mes/hora correctos', () {
    final dataset = hevyDataset();
    final mapping = AutoMapper().map(dataset.columns);
    final validated = Validators().validate(dataset, mapping);

    final date = validated.first.values[CanonicalField.date] as DateTime;
    expect(date, DateTime(2026, 7, 10, 15, 44));
  });

  test('set_type "warmup" marca la serie como calentamiento', () {
    final dataset = hevyDataset();
    final mapping = AutoMapper().map(dataset.columns);
    final validated = Validators().validate(dataset, mapping);

    expect(validated[0].values[CanonicalField.isWarmup], false);
    expect(validated[1].values[CanonicalField.isWarmup], true);
  });
}
