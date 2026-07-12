import 'package:drift/drift.dart';

import '../core/local/database.dart' as local;
import '../models/profile.dart';

/// Reemplaza a `AuthService.updateProfile` (FastAPI) como punto de acceso de
/// `profile_screen.dart` para el perfil extendido -- lee y escribe contra la
/// base local (offline-first). Cada mutación marca `dirty=true` para que
/// `ProfileSyncable` la suba a Supabase cuando haya conexión.
class ProfileRepository {
  final local.AppDatabase db;

  ProfileRepository(this.db);

  Future<Profile?> get(String userId) async {
    final row = await (db.select(
      db.profiles,
    )..where((t) => t.id.equals(userId))).getSingleOrNull();
    if (row == null) return null;
    return Profile(
      id: row.id,
      name: row.name,
      age: row.age,
      sex: row.sex,
      heightCm: row.heightCm,
      weightKg: row.weightKg,
      bodyFatPct: row.bodyFatPct,
      goal: row.goal,
      experienceLevel: row.experienceLevel,
    );
  }

  /// [fields] usa las mismas claves que ya armaba `profile_screen.dart` para
  /// el backend (age/sex/height_cm/weight_kg/body_fat_pct/goal/experience_level).
  Future<void> upsert(
    String userId,
    String name,
    Map<String, dynamic> fields,
  ) async {
    await db
        .into(db.profiles)
        .insertOnConflictUpdate(
          local.ProfilesCompanion(
            id: Value(userId),
            name: Value(name),
            age: fields.containsKey('age')
                ? Value(fields['age'] as int?)
                : const Value.absent(),
            sex: fields.containsKey('sex')
                ? Value(fields['sex'] as String?)
                : const Value.absent(),
            heightCm: fields.containsKey('height_cm')
                ? Value(fields['height_cm'] as double?)
                : const Value.absent(),
            weightKg: fields.containsKey('weight_kg')
                ? Value(fields['weight_kg'] as double?)
                : const Value.absent(),
            bodyFatPct: fields.containsKey('body_fat_pct')
                ? Value(fields['body_fat_pct'] as double?)
                : const Value.absent(),
            goal: fields.containsKey('goal')
                ? Value(fields['goal'] as String?)
                : const Value.absent(),
            experienceLevel: fields.containsKey('experience_level')
                ? Value(fields['experience_level'] as String?)
                : const Value.absent(),
            updatedAt: Value(DateTime.now()),
            dirty: const Value(true),
          ),
        );
  }
}
