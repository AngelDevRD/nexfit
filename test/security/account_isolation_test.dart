// T-C1 -- Tests escritos por el SUPERVISOR (Opus) ANTES de la implementación.
// Hallazgo C1/S1 de docs/AUDITORIA_2026-09-16_SUPERVISOR.md: los datos locales
// no estaban aislados por cuenta. Decisión D4 del dueño: al entrar una cuenta
// DISTINTA a la última, se limpian los datos locales.
// No modificar sin aprobación registrada en docs/qa/TEST_CHANGES.md.
import 'dart:async';
import 'dart:io';

import 'package:appgym/core/auth/account_data_guard.dart';
import 'package:appgym/core/auth/auth_repository.dart';
import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/core/sync/sync_engine.dart';
import 'package:appgym/core/sync/syncable.dart';
import 'package:appgym/models/user.dart';
import 'package:appgym/providers/auth_provider.dart';
import 'package:appgym/repositories/nutrition_repository.dart';
import 'package:appgym/repositories/profile_repository.dart';
import 'package:appgym/repositories/routine_repository.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Identificador fijo del catálogo semilla (id < 1.000.000) y de un
/// ejercicio propio (id >= 1.000.000, ver `ExerciseRepository`).
const _seedExerciseId = 1;
const _customExerciseId = 1000000;

class _FakeAuthRepository implements AuthRepository {
  _FakeAuthRepository({AppUser? initialUser}) : _user = initialUser;

  AppUser? _user;
  final _changes = StreamController<AuthStatus>.broadcast();
  int logoutCalls = 0;

  AppUser _userFor(String email) =>
      AppUser(id: 'id-$email', email: email, name: email.split('@').first);

  /// Simula un evento del proveedor (p. ej. sesión restaurada/renovada) para
  /// otro usuario sin pasar por `login()`.
  void emitSignedInAs(String email) {
    _user = _userFor(email);
    _changes.add(AuthStatus.authenticated);
  }

  @override
  AppUser? get currentUser => _user;

  @override
  Stream<AuthStatus> get authStateChanges => _changes.stream;

  @override
  Future<AuthStatus> restoreSession() async => _user == null
      ? AuthStatus.unauthenticated
      : AuthStatus.authenticated;

  @override
  Future<AppUser> login({required String email, required String password}) async {
    _user = _userFor(email);
    return _user!;
  }

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
  }) => login(email: email, password: password);

  @override
  Future<void> logout() async {
    logoutCalls++;
    _user = null;
  }

  @override
  Future<void> resetPassword({required String email}) async {}

  @override
  Future<void> deleteAccount() async {}

  Future<void> dispose() => _changes.close();
}

class _RecordingEntity implements SyncableEntity {
  int pushCount = 0;

  @override
  String get name => 'recording';

  @override
  Future<void> push(local.AppDatabase db) async => pushCount++;
}

Future<void> _seedCatalogExercise(local.AppDatabase db) => db
    .into(db.exercises)
    .insert(
      local.ExercisesCompanion.insert(
        id: const Value(_seedExerciseId),
        slug: 'press-banca',
        name: 'Press banca',
        muscleGroup: 'Pecho',
        difficulty: 'intermediate',
      ),
    );

/// Carga un conjunto representativo de datos "del usuario A" en todas las
/// tablas de negocio. Devuelve cuántos cambios pendientes de sync genera
/// (ver el test de `unsyncedChangesCount`).
Future<void> _seedUserData(local.AppDatabase db, String userId) async {
  await db
      .into(db.exercises)
      .insert(
        local.ExercisesCompanion.insert(
          id: const Value(_customExerciseId),
          slug: 'custom-$_customExerciseId',
          name: 'Mi ejercicio',
          muscleGroup: 'Pecho',
          difficulty: 'intermediate',
          dirty: const Value(true),
        ),
      );
  await RoutineRepository(db).create({
    'name': 'Rutina de A',
    'days': [
      {
        'day_index': 1,
        'name': 'Día 1',
        'exercises': [
          {'exercise_id': _seedExerciseId, 'order': 0},
        ],
      },
    ],
  });
  final workouts = WorkoutRepository(db);
  final session = await workouts.startSession();
  await workouts.addSet(session.id, {
    'exercise_id': _seedExerciseId,
    'set_number': 1,
    'weight_kg': 100.0,
    'reps': 5,
    'completed': true,
  });
  await workouts.finishSession(session.id);
  await db
      .into(db.activeWorkoutDrafts)
      .insert(
        local.ActiveWorkoutDraftsCompanion.insert(
          id: const Value(1),
          sessionId: session.id,
          updatedAt: DateTime.now(),
        ),
      );
  await db
      .into(db.profiles)
      .insert(
        local.ProfilesCompanion.insert(
          id: userId,
          updatedAt: DateTime.now(),
          weightKg: const Value(80.0),
        ),
      );
  await NutritionRepository(db).upsert({
    'log_date': '2026-09-01',
    'calories': 2500,
    'protein_g': 180,
    'carbs_g': 250,
    'fat_g': 70,
    'water_ml': 3000,
  });
  await db
      .into(db.bodyMeasurements)
      .insert(
        local.BodyMeasurementsCompanion.insert(
          measuredAt: DateTime(2026, 9, 1),
          weightKg: const Value(80.0),
          updatedAt: DateTime.now(),
        ),
      );
}

Future<Map<String, int>> _userDataCounts(local.AppDatabase db) async {
  Future<int> count(TableInfo table) async =>
      (await db.select(table).get()).length;
  return {
    'routines': await count(db.routines),
    'routineDays': await count(db.routineDays),
    'routineExercises': await count(db.routineExercises),
    'workoutSessions': await count(db.workoutSessions),
    'workoutSets': await count(db.workoutSets),
    'personalRecords': await count(db.personalRecords),
    'pendingSetOps': await count(db.pendingSetOps),
    'profiles': await count(db.profiles),
    'goals': await count(db.goals),
    'nutritionLogs': await count(db.nutritionLogs),
    'dailyCheckins': await count(db.dailyCheckins),
    'bodyMeasurements': await count(db.bodyMeasurements),
    'activeWorkoutDrafts': await count(db.activeWorkoutDrafts),
    'customExercises': (await (db.select(
      db.exercises,
    )..where((t) => t.id.isBiggerOrEqualValue(_customExerciseId))).get()).length,
  };
}

Matcher get _allZero => predicate<Map<String, int>>(
  (m) => m.values.every((v) => v == 0),
  'todas las tablas de datos del usuario vacías',
);

void main() {
  late local.AppDatabase db;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    await _seedCatalogExercise(db);
  });

  tearDown(() async {
    await db.close();
  });

  group('AccountDataGuard', () {
    test(
      'primera cuenta en una instalación existente adopta los datos (no borra)',
      () async {
        await _seedUserData(db, 'id-a@x.com');
        final guard = AccountDataGuard(db);

        final wiped = await guard.prepareForUser('id-a@x.com');

        expect(wiped, isFalse);
        expect((await _userDataCounts(db))['routines'], 1);
        expect(guard.isReadyFor('id-a@x.com'), isTrue);
      },
    );

    test('la misma cuenta que vuelve a entrar conserva sus datos', () async {
      final guard = AccountDataGuard(db);
      await guard.prepareForUser('id-a@x.com');
      await _seedUserData(db, 'id-a@x.com');

      final wiped = await guard.prepareForUser('id-a@x.com');

      expect(wiped, isFalse);
      expect((await _userDataCounts(db))['workoutSessions'], 1);
    });

    test(
      'una cuenta distinta limpia TODOS los datos del usuario anterior',
      () async {
        final guard = AccountDataGuard(db);
        await guard.prepareForUser('id-a@x.com');
        await _seedUserData(db, 'id-a@x.com');

        final wiped = await guard.prepareForUser('id-b@x.com');

        expect(wiped, isTrue);
        expect(await _userDataCounts(db), _allZero);
      },
    );

    test(
      'la limpieza conserva el catálogo semilla (si no, la lista de ejercicios queda vacía)',
      () async {
        final guard = AccountDataGuard(db);
        await guard.prepareForUser('id-a@x.com');
        await _seedUserData(db, 'id-a@x.com');

        await guard.prepareForUser('id-b@x.com');

        final remaining = await db.select(db.exercises).get();
        expect(remaining.map((e) => e.id), [_seedExerciseId]);
      },
    );

    test(
      'la última cuenta se recuerda entre reinicios (instancia nueva del guard)',
      () async {
        await AccountDataGuard(db).prepareForUser('id-a@x.com');
        await _seedUserData(db, 'id-a@x.com');

        // "Reinicio": nueva instancia, mismas preferencias persistidas.
        final afterRestart = AccountDataGuard(db);
        expect(await afterRestart.prepareForUser('id-a@x.com'), isFalse);
        expect(await afterRestart.prepareForUser('id-b@x.com'), isTrue);
      },
    );

    test('isReadyFor: falso antes de preparar, con null y para otra cuenta', () async {
      final guard = AccountDataGuard(db);
      expect(guard.isReadyFor('id-a@x.com'), isFalse);
      expect(guard.isReadyFor(null), isFalse);

      await guard.prepareForUser('id-a@x.com');

      expect(guard.isReadyFor('id-a@x.com'), isTrue);
      expect(guard.isReadyFor('id-b@x.com'), isFalse);
      expect(guard.isReadyFor(null), isFalse);
    });

    test('isReadyFor es falso MIENTRAS se limpia para la cuenta nueva', () async {
      final guard = AccountDataGuard(db);
      await guard.prepareForUser('id-a@x.com');
      await _seedUserData(db, 'id-a@x.com');

      final pending = guard.prepareForUser('id-b@x.com');
      expect(guard.isReadyFor('id-b@x.com'), isFalse);
      expect(guard.isReadyFor('id-a@x.com'), isFalse);
      await pending;
      expect(guard.isReadyFor('id-b@x.com'), isTrue);
    });

    test(
      'unsyncedChangesCount cuenta filas pendientes de sync de cada entidad sincronizable',
      () async {
        final guard = AccountDataGuard(db);
        expect(await guard.unsyncedChangesCount(), 0);

        await _seedUserData(db, 'id-a@x.com');

        // 1 ejercicio propio dirty + 1 rutina + 1 sesión + 1 op de serie
        // pendiente + 1 perfil + 1 registro de nutrición = 6.
        // (BodyMeasurements es solo local, no cuenta como "sin sincronizar".)
        expect(await guard.unsyncedChangesCount(), 6);

        await db.update(db.routines).write(
          const local.RoutinesCompanion(dirty: Value(false)),
        );
        await db.delete(db.pendingSetOps).go();
        expect(await guard.unsyncedChangesCount(), 4);
      },
    );

    test(
      'la limpieza sobrevive a reiniciar la app (base en archivo, cerrar y reabrir)',
      () async {
        final dir = Directory.systemTemp.createTempSync('account_guard_');
        final file = File('${dir.path}/appgym.sqlite');
        try {
          var fileDb = local.AppDatabase.forTesting(NativeDatabase(file));
          await _seedCatalogExercise(fileDb);
          await AccountDataGuard(fileDb).prepareForUser('id-a@x.com');
          await _seedUserData(fileDb, 'id-a@x.com');
          await fileDb.close();

          fileDb = local.AppDatabase.forTesting(NativeDatabase(file));
          await AccountDataGuard(fileDb).prepareForUser('id-b@x.com');
          await fileDb.close();

          fileDb = local.AppDatabase.forTesting(NativeDatabase(file));
          expect(await _userDataCounts(fileDb), _allZero);
          expect((await fileDb.select(fileDb.exercises).get()).length, 1);
          await fileDb.close();
        } finally {
          dir.deleteSync(recursive: true);
        }
      },
    );
  });

  group('AuthProvider con AccountDataGuard', () {
    late _FakeAuthRepository authRepository;
    late AccountDataGuard guard;
    late AuthProvider provider;

    Future<void> startAsUserAWithData() async {
      authRepository = _FakeAuthRepository();
      guard = AccountDataGuard(db);
      provider = AuthProvider(
        authRepository,
        ProfileRepository(db),
        accountGuard: guard,
      );
      expect(await provider.login('a@x.com', 'password1'), isTrue);
      await _seedUserData(db, 'id-a@x.com');
    }

    tearDown(() async {
      provider.dispose();
      await authRepository.dispose();
    });

    test('A cierra sesión y entra B: B no ve ningún dato de A', () async {
      await startAsUserAWithData();

      await provider.logout();
      expect(await provider.login('b@x.com', 'password1'), isTrue);

      expect(provider.status, AuthStatus.authenticated);
      expect(provider.user!.id, 'id-b@x.com');
      expect(await _userDataCounts(db), _allZero);
    });

    test(
      'nunca se notifica "autenticado como B" mientras los datos de A siguen en la base',
      () async {
        await startAsUserAWithData();
        await provider.logout();

        final routinesSeenWhenAuthenticatedAsB = <int>[];
        provider.addListener(() {
          if (provider.status == AuthStatus.authenticated &&
              provider.user?.id == 'id-b@x.com') {
            db
                .select(db.routines)
                .get()
                .then((r) => routinesSeenWhenAuthenticatedAsB.add(r.length));
          }
        });

        await provider.login('b@x.com', 'password1');
        await pumpEventQueue();

        expect(routinesSeenWhenAuthenticatedAsB, isNotEmpty);
        expect(routinesSeenWhenAuthenticatedAsB, everyElement(0));
      },
    );

    test(
      'cambio de cuenta que llega por authStateChanges (sin login()) también limpia',
      () async {
        await startAsUserAWithData();

        authRepository.emitSignedInAs('b@x.com');
        await pumpEventQueue();

        expect(provider.user?.id, 'id-b@x.com');
        expect(await _userDataCounts(db), _allZero);
      },
    );

    test('A cierra sesión y vuelve a entrar A: sus datos siguen ahí', () async {
      await startAsUserAWithData();

      await provider.logout();
      await provider.login('a@x.com', 'password1');

      final counts = await _userDataCounts(db);
      expect(counts['routines'], 1);
      expect(counts['workoutSessions'], 1);
      expect(counts['nutritionLogs'], 1);
    });

    test('cerrar sesión por sí solo no borra datos', () async {
      await startAsUserAWithData();

      await provider.logout();

      expect((await _userDataCounts(db))['workoutSessions'], 1);
    });

    test('tryAutoLogin con sesión persistida prepara al guard para ese usuario', () async {
      authRepository = _FakeAuthRepository(
        initialUser: AppUser(id: 'id-a@x.com', email: 'a@x.com', name: 'a'),
      );
      guard = AccountDataGuard(db);
      provider = AuthProvider(
        authRepository,
        ProfileRepository(db),
        accountGuard: guard,
      );

      await provider.tryAutoLogin();

      expect(provider.status, AuthStatus.authenticated);
      expect(guard.isReadyFor('id-a@x.com'), isTrue);
    });
  });

  group('SyncEngine respeta el guard', () {
    test('canSync falso -> no sube nada ni registra error', () async {
      final entity = _RecordingEntity();
      final engine = SyncEngine(
        db: db,
        entities: [entity],
        canSync: () => false,
      );

      await engine.syncNow();

      expect(entity.pushCount, 0);
      expect(engine.lastError, isNull);
    });

    test('canSync verdadero -> sube normalmente', () async {
      final entity = _RecordingEntity();
      final engine = SyncEngine(db: db, entities: [entity], canSync: () => true);

      await engine.syncNow();

      expect(entity.pushCount, 1);
    });

    test(
      'con el guard real: no sube mientras la cuenta actual no está preparada',
      () async {
        final guard = AccountDataGuard(db);
        String? currentUserId = 'id-b@x.com';
        final entity = _RecordingEntity();
        final engine = SyncEngine(
          db: db,
          entities: [entity],
          canSync: () => guard.isReadyFor(currentUserId),
        );

        await engine.syncNow();
        expect(entity.pushCount, 0, reason: 'B todavía no fue preparado');

        await guard.prepareForUser('id-b@x.com');
        await engine.syncNow();
        expect(entity.pushCount, 1);

        currentUserId = null;
        await engine.syncNow();
        expect(entity.pushCount, 1, reason: 'sin sesión no se sube');
      },
    );
  });
}
