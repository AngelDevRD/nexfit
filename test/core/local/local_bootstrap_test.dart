import 'dart:convert';

import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/core/local/local_bootstrap.dart';
import 'package:appgym/repositories/exercise_repository.dart';
import 'package:drift/drift.dart';
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// E2: `mergeExerciseCatalog` reemplaza a la vieja `seedExercisesIfEmpty`,
/// que solo sembraba el catálogo una vez -- ampliar
/// `assets/data/exercises.json` no le llegaba a nadie que ya tuviera la app
/// instalada. Este es el test obligatorio que pidió la fase: catálogo viejo
/// + un ejercicio propio + series registradas -> fusión con catálogo
/// ampliado -> los nuevos aparecen, el propio sigue intacto, ninguna serie
/// perdió su ejercicio.
void main() {
  late local.AppDatabase db;

  String catalogJson(List<Map<String, dynamic>> exercises) =>
      jsonEncode(exercises);

  Map<String, dynamic> exercise({
    required int id,
    required String slug,
    required String name,
    String muscleGroup = 'Pecho',
  }) => {
    'id': id,
    'slug': slug,
    'name': name,
    'muscle_group': muscleGroup,
    'primary_muscles': const [],
    'secondary_muscles': const [],
    'equipment': const [],
    'difficulty': 'beginner',
    'movement_type': 'compound',
    'description': '',
    'instructions': const [],
    'tips': const [],
    'common_mistakes': const [],
    'variants': const [],
    'benefits': const [],
  };

  setUp(() {
    SharedPreferences.setMockInitialValues({});
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
  });

  tearDown(() async {
    await db.close();
  });

  test(
    'agrega ejercicios nuevos, actualiza los existentes, y nunca toca '
    'ejercicios propios ni series ya registradas',
    () async {
      final oldCatalog = catalogJson([
        exercise(id: 1, slug: 'press-banca', name: 'Press banca'),
        exercise(id: 2, slug: 'sentadilla', name: 'Sentadilla'),
      ]);
      await mergeExerciseCatalog(db, oldCatalog);

      final repo = ExerciseRepository(db);
      final customId = await repo.createExercise(
        name: 'Mi ejercicio inventado',
        muscleGroup: 'Core',
        equipment: const [],
        movementType: 'compound',
      );

      final session = await db
          .into(db.workoutSessions)
          .insertReturning(
            local.WorkoutSessionsCompanion.insert(
              startedAt: DateTime.now(),
              updatedAt: DateTime.now(),
            ),
          );
      // Serie contra el ejercicio propio y contra uno del catálogo viejo --
      // ninguna de las dos debe perder su ejercicio tras la fusión.
      await db
          .into(db.workoutSets)
          .insert(
            local.WorkoutSetsCompanion.insert(
              sessionId: session.id,
              exerciseId: customId,
              setNumber: 1,
            ),
          );
      await db
          .into(db.workoutSets)
          .insert(
            local.WorkoutSetsCompanion.insert(
              sessionId: session.id,
              exerciseId: 1,
              setNumber: 1,
            ),
          );

      // Catálogo ampliado: "Press banca" cambia de nombre (dato actualizado
      // del catálogo), "Sentadilla" sigue igual, y aparece un ejercicio
      // nuevo ("Peso muerto").
      final expandedCatalog = catalogJson([
        exercise(id: 1, slug: 'press-banca', name: 'Press de banca con barra'),
        exercise(id: 2, slug: 'sentadilla', name: 'Sentadilla'),
        exercise(id: 3, slug: 'peso-muerto', name: 'Peso muerto'),
      ]);
      await mergeExerciseCatalog(db, expandedCatalog);

      final all = await repo.list();
      // 3 del catálogo ampliado + 1 propio.
      expect(all, hasLength(4));

      final pressBanca = await repo.get(1);
      expect(pressBanca.name, 'Press de banca con barra');
      expect(pressBanca.slug, 'press-banca'); // mismo id, mismo slug

      final pesoMuerto = all.firstWhere((e) => e.slug == 'peso-muerto');
      expect(pesoMuerto.name, 'Peso muerto');

      // El ejercicio propio sigue intacto -- ni tocado ni renumerado.
      final custom = await repo.get(customId);
      expect(custom.name, 'Mi ejercicio inventado');
      expect(ExerciseRepository.isCustomExercise(custom.id), isTrue);

      // Ninguna serie perdió su ejercicio: los mismos ids siguen existiendo.
      final sets = await db.select(db.workoutSets).get();
      expect(sets.map((s) => s.exerciseId), containsAll([customId, 1]));
      expect(await repo.hasLoggedSets(customId), isTrue);
      expect(await repo.hasLoggedSets(1), isTrue);
    },
  );

  test('no vuelve a correr si el catálogo no cambió (no en cada arranque)', () async {
    final catalog = catalogJson([
      exercise(id: 1, slug: 'press-banca', name: 'Press banca'),
    ]);
    await mergeExerciseCatalog(db, catalog);

    // Un usuario renombra a mano el ejercicio del catálogo -- si la fusión
    // se re-ejecutara con el MISMO contenido, lo pisaría de nuevo.
    await (db.update(db.exercises)..where((t) => t.id.equals(1))).write(
      const local.ExercisesCompanion(name: Value('Nombre editado a mano')),
    );

    await mergeExerciseCatalog(db, catalog);

    final row = await (db.select(
      db.exercises,
    )..where((t) => t.id.equals(1))).getSingle();
    expect(row.name, 'Nombre editado a mano');
  });
}
