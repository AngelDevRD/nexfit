import 'package:drift/drift.dart';
import 'package:supabase_flutter/supabase_flutter.dart' as sb;

import '../../local/database.dart';
import '../syncable.dart';

/// Sync del perfil (Fase 2) contra la tabla `profiles` de Supabase. A
/// diferencia de Routines, el "serverId" del perfil siempre es el propio id
/// del usuario logueado -- no hay paso de "crear y esperar id", es upsert
/// directo por clave primaria.
class ProfileSyncable implements SyncableEntity {
  final sb.SupabaseClient client;

  ProfileSyncable(this.client);

  @override
  String get name => 'profile';

  @override
  Future<void> push(AppDatabase db) async {
    final userId = client.auth.currentUser?.id;
    if (userId == null) return;

    final row =
        await (db.select(db.profiles)
              ..where((t) => t.id.equals(userId) & t.dirty.equals(true)))
            .getSingleOrNull();
    if (row == null) return;

    await client.from('profiles').upsert({
      'id': userId,
      'name': row.name,
      'age': row.age,
      'sex': row.sex,
      'height_cm': row.heightCm,
      'weight_kg': row.weightKg,
      'body_fat_pct': row.bodyFatPct,
      'goal': row.goal,
      'experience_level': row.experienceLevel,
      'updated_at': row.updatedAt.toIso8601String(),
    });

    await (db.update(db.profiles)..where((t) => t.id.equals(userId))).write(
      const ProfilesCompanion(dirty: Value(false)),
    );
  }
}
