import 'dart:convert';

import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../local/database.dart';
import '../syncable.dart';

/// Id a partir del cual arrancan los ejercicios propios -- debe coincidir
/// con `ExerciseRepository.customExerciseIdStart`. Duplicado acá (en vez de
/// importar el repositorio desde la capa de sync) para no acoplar
/// `core/sync` a `repositories/`.
const _customExerciseIdStart = 1000000;

/// Sync de ejercicios PROPIOS (A15, ver docs/AUDITORIA_2026-09-04.md) contra
/// `nexfit_custom_exercises`. El catálogo base (`assets/data/exercises.json`)
/// nunca viaja acá -- es estático e idéntico para todos los usuarios, lo
/// siembra `syncExerciseCatalog` y nunca marca `dirty`.
///
/// A diferencia de `RoutineSyncable`/`GoalSyncable` (create-once, sin
/// edición), acá sí hay edición (`ExerciseRepository.updateExercise`), así
/// que se resuelve con upsert por `(user_id, slug)` en vez de
/// insert-una-sola-vez: una fila editada vuelve a quedar `dirty` y esta
/// misma rama la sube de nuevo, actualizando la fila remota existente en
/// vez de crear una duplicada.
class ExerciseSyncable implements SyncableEntity {
  final sb.SupabaseClient client;

  ExerciseSyncable(this.client);

  @override
  String get name => 'exercises';

  @override
  Future<void> push(AppDatabase db) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final dirty =
        await (db.select(db.exercises)..where(
              (t) =>
                  t.dirty.equals(true) & t.id.isBiggerOrEqualValue(
                    _customExerciseIdStart,
                  ),
            ))
            .get();

    for (final exercise in dirty) {
      if (exercise.deleted) {
        if (exercise.serverId != null) {
          await client
              .from('nexfit_custom_exercises')
              .delete()
              .eq('id', exercise.serverId!);
        }
        await (db.delete(
          db.exercises,
        )..where((t) => t.id.equals(exercise.id))).go();
        continue;
      }

      final upserted = await client
          .from('nexfit_custom_exercises')
          .upsert({
            'user_id': userId,
            'slug': exercise.slug,
            'name': exercise.name,
            'muscle_group': exercise.muscleGroup,
            'difficulty': exercise.difficulty,
            'detail_json': jsonDecode(exercise.detailJson),
          }, onConflict: 'user_id,slug')
          .select()
          .single();

      await (db.update(db.exercises)..where((t) => t.id.equals(exercise.id)))
          .write(
            ExercisesCompanion(
              serverId: Value(upserted['id'] as String),
              dirty: const Value(false),
            ),
          );
    }
  }
}
