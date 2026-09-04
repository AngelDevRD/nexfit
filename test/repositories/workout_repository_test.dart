import 'dart:convert';

import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/repositories/workout_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';

void main() {
  late local.AppDatabase db;
  late WorkoutRepository repo;

  setUp(() {
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    repo = WorkoutRepository(db);
  });

  tearDown(() async {
    await db.close();
  });

  Future<int> addExercise(
    int id,
    String slug, {
    String muscleGroup = 'legs',
  }) => db
      .into(db.exercises)
      .insert(
        local.ExercisesCompanion.insert(
          id: Value(id),
          slug: slug,
          name: slug,
          muscleGroup: muscleGroup,
          difficulty: 'intermediate',
        ),
      );

  test(
    'C1: updateSet mergea el payload sobre el insert pendiente en vez de '
    'sobreescribirlo',
    () async {
      await addExercise(1, 'sentadilla');
      final session = await repo.startSession();

      // Reproduce exactamente la secuencia documentada en la auditoría:
      // addSet en 0/0, después dos updateSet parciales (peso, después reps).
      final outcome = await repo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 0.0,
        'reps': 0,
      });
      final setId = outcome.set.id;

      await repo.updateSet(setId, {'weight_kg': 80.0});
      await repo.updateSet(setId, {'reps': 8});

      final pending = await (db.select(db.pendingSetOps)..where(
            (t) => t.localSetId.equals(setId) & t.op.equals('insert'),
          ))
          .getSingle();
      final payload = jsonDecode(pending.payloadJson) as Map<String, dynamic>;

      // Antes del fix, el segundo updateSet pisaba el payload del primero y
      // el insert pendiente quedaba como {'reps': 8}, sin exercise_id ni
      // set_number ni weight_kg -- el insert que viaja a Supabase fallaba o
      // creaba filas basura.
      expect(payload['exercise_id'], 1);
      expect(payload['set_number'], 1);
      expect((payload['weight_kg'] as num).toDouble(), 80.0);
      expect(payload['reps'], 8);
    },
  );

  test(
    'C2: addSet no crea récord con la serie placeholder en 0/0',
    () async {
      await addExercise(1, 'sentadilla');
      final session = await repo.startSession();

      final outcome = await repo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 0.0,
        'reps': 0,
      });

      expect(outcome.newRecords, isEmpty);
      expect(await db.select(db.personalRecords).get(), isEmpty);
    },
  );

  test(
    'REGRESIÓN: updateSet NUNCA evalúa récords, sin importar cuántas veces '
    'se llame -- StepperField dispara un updateSet por cada toque de +/-, '
    'así que subir 0 -> 80kg en pasos de 2.5 son 32 llamadas. Evaluar ahí '
    'generaba 32 filas en personalRecords para una sola serie.',
    () async {
      await addExercise(1, 'sentadilla');
      final session = await repo.startSession();

      final outcome = await repo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 0.0,
        'reps': 0,
      });
      final setId = outcome.set.id;

      // 32 toques de +2.5kg (0 -> 80) tal como los produce StepperField.
      for (var i = 1; i <= 32; i++) {
        await repo.updateSet(setId, {'weight_kg': i * 2.5});
      }
      // 8 toques de +1 rep (0 -> 8).
      for (var i = 1; i <= 8; i++) {
        await repo.updateSet(setId, {'reps': i});
      }

      expect(
        await db.select(db.personalRecords).get(),
        isEmpty,
        reason: 'updateSet no debe crear ni una fila por sí solo',
      );

      // El check de "serie completada" (C5) es el único punto que evalúa --
      // una vez, con el valor final ya estable.
      final newRecords = await repo.setCompleted(setId, true);
      expect(newRecords, hasLength(2));

      final records = await db.select(db.personalRecords).get();
      expect(records, hasLength(2), reason: 'una fila por tipo, no 32');
      final weight = records.firstWhere((r) => r.recordType == 'max_weight');
      final reps = records.firstWhere((r) => r.recordType == 'max_reps');
      expect(weight.value, 80.0);
      expect(reps.value, 8.0);
    },
  );

  test(
    'setCompleted no acumula filas al reevaluar la misma serie (completar, '
    'editar, volver a completar reemplaza la fila de esa serie)',
    () async {
      await addExercise(1, 'sentadilla');
      final session = await repo.startSession();

      final outcome = await repo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 80.0,
        'reps': 8,
      });
      final setId = outcome.set.id;

      await repo.setCompleted(setId, true);
      expect(await db.select(db.personalRecords).get(), hasLength(2));

      // Se descompleta, se corrige a un peso mayor y se vuelve a completar.
      await repo.setCompleted(setId, false);
      await repo.updateSet(setId, {'weight_kg': 85.0});
      await repo.setCompleted(setId, true);

      final records = await db.select(db.personalRecords).get();
      expect(records, hasLength(2), reason: 'reemplaza, no acumula');
      final weight = records.firstWhere((r) => r.recordType == 'max_weight');
      expect(weight.value, 85.0);
    },
  );

  test(
    'setCompleted no evalúa récords para series de calentamiento',
    () async {
      await addExercise(1, 'sentadilla');
      final session = await repo.startSession();

      final outcome = await repo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 0.0,
        'reps': 0,
        'is_warmup': true,
      });
      final setId = outcome.set.id;

      await repo.updateSet(setId, {'weight_kg': 80.0, 'reps': 8});
      await repo.setCompleted(setId, true);

      expect(await db.select(db.personalRecords).get(), isEmpty);
    },
  );

  test(
    'finishSession reconstruye los récords (red de seguridad) para series '
    'corregidas por el editor avanzado después de completadas',
    () async {
      await addExercise(1, 'sentadilla');
      final session = await repo.startSession();

      final outcome = await repo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 0.0,
        'reps': 0,
      });
      final setId = outcome.set.id;
      await repo.setCompleted(setId, true); // 0/0 -> no genera nada.

      // Editor avanzado: corrige valores sin pasar por setCompleted.
      await repo.updateSet(setId, {'weight_kg': 80.0, 'reps': 8});
      expect(await db.select(db.personalRecords).get(), isEmpty);

      await repo.finishSession(session.id);

      final records = await db.select(db.personalRecords).get();
      expect(records, hasLength(2));
    },
  );

  test(
    'T3: previousVolumeByMuscle resuelve varios músculos en una sola pasada '
    'y toma la sesión anterior más reciente de cada uno',
    () async {
      await addExercise(1, 'sentadilla', muscleGroup: 'legs');
      await addExercise(2, 'press-banca', muscleGroup: 'chest');

      final old = await repo.startSession(
        startedAt: DateTime(2026, 1, 1),
      );
      await repo.addSet(old.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 100.0,
        'reps': 10,
      });
      await repo.finishSession(old.id, endedAt: DateTime(2026, 1, 1, 1));

      final recent = await repo.startSession(
        startedAt: DateTime(2026, 1, 5),
      );
      await repo.addSet(recent.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 120.0,
        'reps': 10,
      });
      await repo.addSet(recent.id, {
        'exercise_id': 2,
        'set_number': 1,
        'weight_kg': 60.0,
        'reps': 8,
      });
      await repo.finishSession(recent.id, endedAt: DateTime(2026, 1, 5, 1));

      final today = await repo.startSession(startedAt: DateTime(2026, 1, 10));
      await repo.addSet(today.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 130.0,
        'reps': 10,
      });

      final result = await repo.previousVolumeByMuscle(
        muscleGroups: {'legs', 'chest'},
        excludeSessionId: today.id,
      );

      // legs: la sesión de 'recent' (120x10=1200), no la de 'old' (más vieja).
      expect(result['legs'], 1200.0);
      // chest: solo tiene volumen en 'recent' (60x8=480).
      expect(result['chest'], 480.0);
    },
  );

  test(
    'previousVolumeByMuscle no incluye un músculo sin sesiones anteriores',
    () async {
      await addExercise(1, 'sentadilla', muscleGroup: 'legs');
      final session = await repo.startSession();
      await repo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 100.0,
        'reps': 10,
      });

      final result = await repo.previousVolumeByMuscle(
        muscleGroups: {'legs'},
        excludeSessionId: session.id,
      );

      expect(result, isEmpty);
    },
  );

  test(
    'U2: lastSessionFor devuelve todas las series de la sesión terminada '
    'más reciente que entrenó ese ejercicio, no solo la mejor',
    () async {
      await addExercise(1, 'sentadilla');

      final old = await repo.startSession(startedAt: DateTime(2026, 1, 1));
      await repo.addSet(old.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 150.0, // más pesada que la reciente, pero es vieja.
        'reps': 5,
      });
      await repo.finishSession(old.id, endedAt: DateTime(2026, 1, 1, 1));

      final recent = await repo.startSession(startedAt: DateTime(2026, 1, 10));
      await repo.addSet(recent.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 100.0,
        'reps': 10,
      });
      await repo.addSet(recent.id, {
        'exercise_id': 1,
        'set_number': 2,
        'weight_kg': 100.0,
        'reps': 8,
      });
      await repo.finishSession(recent.id, endedAt: DateTime(2026, 1, 10, 1));

      final result = await repo.lastSessionFor(1);

      expect(result != null, isTrue);
      expect(result!.startedAt, DateTime(2026, 1, 10));
      expect(result.sets.length, 2);
      expect(result.sets[0].weightKg, 100.0);
      expect(result.sets[0].reps, 10);
      expect(result.sets[1].reps, 8);
    },
  );

  test(
    'U2: lastSessionFor ignora sesiones sin terminar y devuelve null si '
    'nunca se entrenó el ejercicio',
    () async {
      await addExercise(1, 'sentadilla');
      final session = await repo.startSession();
      await repo.addSet(session.id, {
        'exercise_id': 1,
        'set_number': 1,
        'weight_kg': 100.0,
        'reps': 10,
      });
      // Sesión nunca finalizada -- no cuenta.

      final result = await repo.lastSessionFor(1);

      expect(result == null, isTrue);
    },
  );

  test(
    'U3: history() con limit/offset pagina las sesiones más recientes '
    'primero sin traer todo el historial de una vez',
    () async {
      await addExercise(1, 'sentadilla');
      for (var i = 1; i <= 5; i++) {
        final session = await repo.startSession(
          startedAt: DateTime(2026, 1, i),
        );
        await repo.addSet(session.id, {
          'exercise_id': 1,
          'set_number': 1,
          'weight_kg': 50.0,
          'reps': 10,
        });
        await repo.finishSession(session.id, endedAt: DateTime(2026, 1, i, 1));
      }

      final page1 = await repo.history(limit: 2, offset: 0);
      final page2 = await repo.history(limit: 2, offset: 2);
      final page3 = await repo.history(limit: 2, offset: 4);

      expect(page1.map((s) => s.startedAt.day), [5, 4]);
      expect(page2.map((s) => s.startedAt.day), [3, 2]);
      expect(page3.map((s) => s.startedAt.day), [1]);
    },
  );

  test(
    'REGRESIÓN: history() con muscleGroup filtra en SQL antes de paginar -- '
    'sesiones viejas del músculo buscado detrás de muchas sesiones recientes '
    'de otro músculo tienen que aparecer en la primera página, no perderse',
    () async {
      await addExercise(1, 'press-banca', muscleGroup: 'chest');
      await addExercise(2, 'remo', muscleGroup: 'back');

      // 5 sesiones viejas de pecho.
      for (var i = 1; i <= 5; i++) {
        final session = await repo.startSession(
          startedAt: DateTime(2026, 1, i),
        );
        await repo.addSet(session.id, {
          'exercise_id': 1,
          'set_number': 1,
          'weight_kg': 50.0,
          'reps': 10,
        });
        await repo.finishSession(session.id, endedAt: DateTime(2026, 1, i, 1));
      }
      // 20 sesiones más recientes de espalda, encima en la fecha.
      for (var i = 1; i <= 20; i++) {
        final session = await repo.startSession(
          startedAt: DateTime(2026, 2, i),
        );
        await repo.addSet(session.id, {
          'exercise_id': 2,
          'set_number': 1,
          'weight_kg': 40.0,
          'reps': 10,
        });
        await repo.finishSession(session.id, endedAt: DateTime(2026, 2, i, 1));
      }

      final page1 = await repo.history(
        muscleGroup: 'chest',
        limit: 20,
        offset: 0,
      );

      // Antes: el filtro corría en Dart DESPUÉS del limit/offset de SQL, así
      // que la página 1 (las 20 sesiones de espalda más recientes) no traía
      // ninguna de pecho -- page1 quedaba vacía pese a haber 5 sesiones
      // reales. Con el filtro en SQL, limit/offset ya operan sobre el
      // conjunto filtrado.
      expect(page1.length, 5);
      expect(page1.every((s) => s.startedAt.month == 1), isTrue);
    },
  );

  test(
    'REGRESIÓN: offset de history() con muscleGroup cuenta sobre el mismo '
    'conjunto filtrado que devuelve -- paginar no repite ni salta sesiones',
    () async {
      await addExercise(1, 'press-banca', muscleGroup: 'chest');
      await addExercise(2, 'remo', muscleGroup: 'back');

      for (var i = 1; i <= 5; i++) {
        final session = await repo.startSession(
          startedAt: DateTime(2026, 1, i),
        );
        await repo.addSet(session.id, {
          'exercise_id': 1,
          'set_number': 1,
          'weight_kg': 50.0,
          'reps': 10,
        });
        await repo.finishSession(session.id, endedAt: DateTime(2026, 1, i, 1));
      }
      for (var i = 1; i <= 20; i++) {
        final session = await repo.startSession(
          startedAt: DateTime(2026, 2, i),
        );
        await repo.addSet(session.id, {
          'exercise_id': 2,
          'set_number': 1,
          'weight_kg': 40.0,
          'reps': 10,
        });
        await repo.finishSession(session.id, endedAt: DateTime(2026, 2, i, 1));
      }

      final page1 = await repo.history(
        muscleGroup: 'chest',
        limit: 3,
        offset: 0,
      );
      final page2 = await repo.history(
        muscleGroup: 'chest',
        limit: 3,
        offset: page1.length,
      );

      expect(page1.map((s) => s.startedAt.day), [5, 4, 3]);
      expect(page2.map((s) => s.startedAt.day), [2, 1]);
    },
  );
}
