// Test escrito por el SUPERVISOR (Opus). Cierra el riesgo que dejó las 12
// tablas de Supabase en 0 filas durante meses: el cliente mandaba una clave
// que no existía como columna (`completed`), PostgREST respondía PGRST204, el
// SyncEngine lo capturaba y reintentaba para siempre, y nadie se enteraba.
//
// No reemplaza la verificación de punta a punta (hace falta una sesión real
// escribiendo filas: ver docs/qa/ESTADO_2026-09-17.md), pero sí detecta de
// forma automática el desajuste esquema/payload, que es la causa conocida.
//
// El esquema remoto vive en test/fixtures/supabase_schema.json, leído del
// proyecto real con information_schema. Si una migración cambia el esquema,
// ese fixture se actualiza en la misma tarea.
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'dart:convert';
import 'dart:io';

import 'package:flutter_test/flutter_test.dart';

/// Palabras que aparecen como `'x':` en el código pero NO son columnas: son
/// etiquetas de `switch` sobre el tipo de operación de `PendingSetOps`.
const _notColumns = {'insert', 'update', 'delete'};

/// Claves que `WorkoutRepository.addSet`/`updateSet` pueden poner en el
/// payload de `PendingSetOps`, que `WorkoutSessionSyncable._drainPendingOps`
/// manda TAL CUAL a `nexfit_workout_sets`. Se mantiene a mano porque el
/// payload se arma en las pantallas, no en el syncable.
const _workoutSetPayloadKeys = {
  'exercise_id',
  'set_number',
  'weight_kg',
  'reps',
  'rpe',
  'rir',
  'rest_seconds',
  'techniques',
  'superset_group_id',
  'tempo',
  'is_warmup',
  'notes',
  'completed',
  'exercise_notes',
  'exercise_order',
};

Map<String, dynamic> _loadSchema() {
  final raw = File('test/fixtures/supabase_schema.json').readAsStringSync();
  return (jsonDecode(raw) as Map<String, dynamic>)['tables']
      as Map<String, dynamic>;
}

Set<String> _columnsOf(Map<String, dynamic> schema, String table) {
  final entry = schema[table] as Map<String, dynamic>?;
  expect(entry, isNotNull, reason: 'el fixture no describe $table');
  return (entry!['columns'] as List).cast<String>().toSet();
}

Set<String> _requiredOf(Map<String, dynamic> schema, String table) =>
    ((schema[table] as Map<String, dynamic>)['required'] as List)
        .cast<String>()
        .toSet();

void main() {
  final schema = _loadSchema();

  test('el fixture cubre las tablas que usa el código de sync', () {
    final referenced = <String>{};
    for (final file in Directory('lib/core/sync/entities').listSync()) {
      if (file is! File) continue;
      referenced.addAll(
        RegExp(r"\.from\('([a-z_]+)'\)")
            .allMatches(file.readAsStringSync())
            .map((m) => m.group(1)!),
      );
    }
    expect(referenced, isNotEmpty);
    expect(referenced.difference(schema.keys.toSet()), isEmpty);
  });

  group('claves enviadas que no existen como columna (PGRST204)', () {
    for (final file in Directory('lib/core/sync/entities')
        .listSync()
        .whereType<File>()
        .where((f) => f.path.endsWith('.dart'))) {
      final name = file.path.replaceAll('\\', '/').split('/').last;
      test(name, () {
        final source = file.readAsStringSync();
        final tables = RegExp(r"\.from\('([a-z_]+)'\)")
            .allMatches(source)
            .map((m) => m.group(1)!)
            .toSet();
        expect(tables, isNotEmpty, reason: '$name no referencia ninguna tabla');

        final allowed = {
          for (final table in tables) ..._columnsOf(schema, table),
        };
        final sent = RegExp(r"'([a-z_]+)':")
            .allMatches(source)
            .map((m) => m.group(1)!)
            .toSet()
            .difference(_notColumns);

        expect(
          sent.difference(allowed),
          isEmpty,
          reason:
              '$name manda claves que no existen en ${tables.join(', ')} -- '
              'PostgREST devolvería PGRST204 y el sync fallaría en silencio',
        );
      });
    }
  });

  test('el payload de series cabe en nexfit_workout_sets', () {
    final columns = _columnsOf(schema, 'nexfit_workout_sets');
    expect(_workoutSetPayloadKeys.difference(columns), isEmpty);
  });

  test('el payload de series incluye todas las columnas obligatorias', () {
    // `session_id` lo agrega el syncable al drenar la cola, no el payload.
    final required = _requiredOf(schema, 'nexfit_workout_sets')
      ..remove('session_id');
    expect(required.difference(_workoutSetPayloadKeys), isEmpty);
  });

  test('las claves del payload de series siguen existiendo en el repositorio', () {
    final source = File(
      'lib/repositories/workout_repository.dart',
    ).readAsStringSync();
    // Si alguien agrega una clave nueva al payload sin sumarla a este test,
    // esta comprobación no la ve -- pero sí detecta que una clave listada
    // acá dejó de usarse, señal de que el contrato quedó viejo.
    for (final key in _workoutSetPayloadKeys) {
      expect(
        source.contains("'$key'"),
        isTrue,
        reason: '$key ya no aparece en workout_repository.dart',
      );
    }
  });
}
