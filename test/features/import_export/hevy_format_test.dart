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

  test('mapea las columnas de Hevy a los campos canonicos correctos', () {
    final mapping = AutoMapper().map(hevyDataset().columns);

    expect(mapping.fieldFor('exercise_title'), CanonicalField.exerciseName);
    expect(mapping.fieldFor('title'), CanonicalField.sessionTitle);
    expect(mapping.fieldFor('start_time'), CanonicalField.startTime);
    expect(mapping.fieldFor('end_time'), CanonicalField.endTime);
    expect(mapping.fieldFor('set_index'), CanonicalField.setNumber);
    expect(mapping.fieldFor('set_type'), CanonicalField.setType);
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

  test(
    'start_time/end_time en espanol abreviado se parsean como hora real',
    () {
      final dataset = hevyDataset();
      final mapping = AutoMapper().map(dataset.columns);
      final validated = Validators().validate(dataset, mapping);

      final start =
          validated.first.values[CanonicalField.startTime] as DateTime;
      final end = validated.first.values[CanonicalField.endTime] as DateTime;
      expect(start, DateTime(2026, 7, 10, 15, 44));
      expect(end, DateTime(2026, 7, 10, 16, 46));
      // La duración real es 1 h 2 min, no miles de minutos.
      expect(end.difference(start), const Duration(minutes: 62));
    },
  );

  test('set_type se preserva como texto crudo para el ImportEngine', () {
    final dataset = hevyDataset();
    final mapping = AutoMapper().map(dataset.columns);
    final validated = Validators().validate(dataset, mapping);

    // La interpretación (warmup -> isWarmup, dropset -> technique) ya no ocurre
    // en la validación sino en el ImportEngine; acá solo se conserva el valor.
    expect(validated[0].values[CanonicalField.setType], 'normal');
    expect(validated[1].values[CanonicalField.setType], 'warmup');
  });
}
