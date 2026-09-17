import 'package:appgym/core/auth/auth_repository.dart';
import 'package:appgym/core/exercise_animation/animation_repository.dart';
import 'package:appgym/core/local/database.dart' as local;
import 'package:appgym/models/user.dart';
import 'package:appgym/providers/auth_provider.dart';
import 'package:appgym/providers/weight_unit_provider.dart';
import 'package:appgym/repositories/active_workout_repository.dart';
import 'package:appgym/repositories/exercise_repository.dart';
import 'package:appgym/repositories/gamification_repository.dart';
import 'package:appgym/repositories/goal_repository.dart';
import 'package:appgym/repositories/nutrition_repository.dart';
import 'package:appgym/repositories/profile_repository.dart';
import 'package:appgym/repositories/routine_repository.dart';
import 'package:appgym/repositories/stats_repository.dart';
import 'package:appgym/repositories/workout_repository.dart';
import 'package:appgym/screens/home/home_shell.dart';
// Ver la nota en `active_workout_repository_test.dart`: se ocultan los
// `isNull`/`isNotNull` de drift para que ganen los matchers de flutter_test.
import 'package:drift/drift.dart' hide isNotNull, isNull;
import 'package:drift/native.dart';
import 'package:flutter/material.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:provider/provider.dart';
import 'package:shared_preferences/shared_preferences.dart';

/// Repositorio de auth falso: siempre autenticado, sin red de por medio --
/// lo único que necesita `HomeShell`/`ProfileScreen`/`DashboardScreen` es un
/// `AuthProvider` con `status == authenticated` y un `AppUser`.
class _FakeAuthenticatedRepository implements AuthRepository {
  final _user = AppUser(id: 'u1', email: 'test@nexfit.app', name: 'Test');

  @override
  AppUser? get currentUser => _user;

  @override
  Future<AuthStatus> restoreSession() async => AuthStatus.authenticated;

  @override
  Stream<AuthStatus> get authStateChanges => const Stream.empty();

  @override
  Future<AppUser> register({
    required String email,
    required String password,
    required String name,
  }) async => _user;

  @override
  Future<AppUser> login({
    required String email,
    required String password,
  }) async => _user;

  @override
  Future<void> logout() async {}

  @override
  Future<void> resetPassword({required String email}) async {}

  @override
  Future<void> deleteAccount() async {}
}

/// A2 (deuda conocida, ver docs/PROMPT_FASES_2-6.md sección 4): sigue
/// colgado ("A Timer is still pending even after the widget tree was
/// disposed") pese a resolver las dos causas que parecían explicarlo:
/// - A26: el `Timer` de `AppUpdater.checkForUpdate` (resuelto vía
///   `onCheckForUpdate`, ver `HomeShell`).
/// - `_ActiveWorkoutBanner` recreando su `Stream` de Drift en cada
///   `build()` (mismo defecto que A10 en `ExerciseThumb` -- se corrigió
///   igual, cacheándolo en `initState`; mejora válida por sí sola, pero NO
///   era la causa del cuelgue).
///
/// Aislado más allá de lo anterior: un `StreamBuilder` desnudo sobre
/// `ActiveWorkoutRepository.watchCurrentSessionId()`, sin ningún widget de
/// `HomeShell` alrededor y con el stream creado una sola vez (no en
/// `build`), ya deja el mismo `Timer` pendiente contra
/// `NativeDatabase.memory()`. Es decir: no es un problema de qué widget lo
/// usa ni de cuántas veces se suscribe -- es la combinación
/// `.watchSingleOrNull()` de Drift + `NativeDatabase.memory()` +
/// `flutter_test`, en este entorno. No se investigó más allá (haría falta
/// meterse en el executor de Drift/sqlite3 en modo test) -- se deja
/// `skip` con este mensaje en vez de borrar el test, para no repetir la
/// investigación. A2 sigue cubierto solo por verificación manual (ver
/// sección 4 del prompt).
///
/// Deliberadamente usa `pump()` con duraciones fijas, nunca `pumpAndSettle`:
/// hay streams y posibles indicadores de carga vivos que no convergen.
void main() {
  late local.AppDatabase db;
  late WorkoutRepository workoutRepo;
  late ActiveWorkoutRepository activeRepo;

  setUp(() async {
    SharedPreferences.setMockInitialValues({});
    db = local.AppDatabase.forTesting(NativeDatabase.memory());
    workoutRepo = WorkoutRepository(db);
    activeRepo = ActiveWorkoutRepository(db, workoutRepo);

    await db
        .into(db.exercises)
        .insert(
          local.ExercisesCompanion.insert(
            id: const Value(1),
            slug: 'press-banca',
            name: 'Press banca',
            muscleGroup: 'Pecho',
            difficulty: 'intermediate',
          ),
        );
  });

  tearDown(() async {
    await db.close();
  });

  Widget wrap() {
    final authRepository = _FakeAuthenticatedRepository();
    final profileRepository = ProfileRepository(db);
    return MultiProvider(
      providers: [
        Provider<local.AppDatabase>.value(value: db),
        Provider<WorkoutRepository>.value(value: workoutRepo),
        Provider<ActiveWorkoutRepository>.value(value: activeRepo),
        Provider<RoutineRepository>(create: (_) => RoutineRepository(db)),
        Provider<StatsRepository>(create: (_) => StatsRepository(db)),
        Provider<GamificationRepository>(
          create: (_) => GamificationRepository(db),
        ),
        Provider<ExerciseRepository>(create: (_) => ExerciseRepository(db)),
        Provider<GoalRepository>(create: (_) => GoalRepository(db)),
        Provider<NutritionRepository>(create: (_) => NutritionRepository(db)),
        Provider<ProfileRepository>.value(value: profileRepository),
        Provider<AnimationRepository>.value(
          value: AnimationRepository(providers: const []),
        ),
        ChangeNotifierProvider<WeightUnitProvider>(
          create: (_) => WeightUnitProvider(),
        ),
        ChangeNotifierProvider<AuthProvider>(
          create: (_) =>
              AuthProvider(authRepository, profileRepository)
                ..tryAutoLogin(),
        ),
      ],
      child: MaterialApp(
        home: HomeShell(onCheckForUpdate: (_) async {}),
      ),
    );
  }

  testWidgets(
    'A2: con un entrenamiento activo, "Empezar entrenamiento" ofrece las 3 salidas',
    (tester) async {
      final session = await activeRepo.begin();
      final sessionId = session.id;

      await tester.pumpWidget(wrap());
      // Deja resolver tryAutoLogin(), _load() de Dashboard, etc. sin esperar
      // a que converjan indicadores de carga que puedan seguir vivos.
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));
      await tester.pump(const Duration(milliseconds: 300));

      // El banner de entrenamiento en curso (N3) confirma que el shell se
      // montó con la sesión activa detectada.
      expect(find.text('Entrenamiento en curso'), findsOneWidget);

      await tester.tap(find.text('Entrenar'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.text('Empezar entrenamiento'), findsOneWidget);
      await tester.tap(find.text('Empezar entrenamiento'));
      await tester.pump();
      await tester.pump(const Duration(milliseconds: 300));

      expect(find.byType(AlertDialog), findsOneWidget);
      expect(find.text('Continuar entrenamiento'), findsOneWidget);
      expect(find.text('Descartar y empezar uno nuevo'), findsOneWidget);
      expect(find.text('Cancelar'), findsOneWidget);

      // La sesión sigue viva: solo se abrió el diálogo, no se decidió nada.
      expect(await activeRepo.currentSessionId(), sessionId);
    },
    // Cuelga por un Timer pendiente de Drift .watchSingleOrNull() contra
    // NativeDatabase.memory() en flutter_test -- ver el comentario de este
    // archivo. No es un bug de HomeShell.
    // SKIP-APPROVED: Q4 (temporal: Q4 debe quitar este skip)
    skip: true,
  );
}
