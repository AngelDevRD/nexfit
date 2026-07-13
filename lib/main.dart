import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/auth/auth_repository.dart';
import 'core/auth/supabase_auth_repository.dart';
import 'core/auth/unavailable_auth_repository.dart';
import 'core/local/database.dart';
import 'core/local/local_bootstrap.dart';
import 'core/supabase_config.dart';
import 'core/sync/entities/goal_syncable.dart';
import 'core/sync/entities/nutrition_syncable.dart';
import 'core/sync/entities/profile_syncable.dart';
import 'core/sync/entities/recovery_syncable.dart';
import 'core/sync/entities/routine_syncable.dart';
import 'core/sync/entities/workout_session_syncable.dart';
import 'core/sync/sync_engine.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'repositories/body_measurement_repository.dart';
import 'repositories/exercise_repository.dart';
import 'repositories/gamification_repository.dart';
import 'repositories/goal_repository.dart';
import 'repositories/nutrition_repository.dart';
import 'repositories/profile_repository.dart';
import 'repositories/recovery_repository.dart';
import 'repositories/routine_repository.dart';
import 'repositories/social_repository.dart';
import 'repositories/stats_repository.dart';
import 'repositories/workout_repository.dart';
import 'screens/auth/login_screen.dart';
import 'screens/home/home_shell.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  // Fase 1 (ver docs/ARQUITECTURA_BACKEND.md): la sesión/identidad ya
  // depende de que esta inicialización haya funcionado. Si falla, en vez de
  // crashear al usar `Supabase.instance` más abajo, se cae a
  // [UnavailableAuthRepository] -- la app sigue arrancando, solo con las
  // acciones de auth deshabilitadas hasta el próximo intento.
  // TODO(fase-posterior): reportar este error a un servicio real (Crashlytics
  // o similar) en vez de solo loguearlo -- ver observación del usuario.
  AuthRepository authRepository;
  SupabaseClient? supabaseClient;
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    supabaseClient = Supabase.instance.client;
    authRepository = SupabaseAuthRepository(supabaseClient);
  } catch (e, st) {
    developer.log(
      'Supabase.initialize fallo -- auth deshabilitada esta sesión',
      error: e,
      stackTrace: st,
      name: 'main',
    );
    authRepository = const UnavailableAuthRepository();
  }
  runApp(
    AppGymApp(authRepository: authRepository, supabaseClient: supabaseClient),
  );
}

class AppGymApp extends StatefulWidget {
  const AppGymApp({
    super.key,
    required this.authRepository,
    required this.supabaseClient,
  });

  final AuthRepository authRepository;
  // Null solo si Supabase.initialize falló en main() -- ver comentario ahí.
  // En ese caso el SyncEngine sigue arrancando pero sin las entidades que
  // dependen de Supabase (no hay nada a lo que sincronizar).
  final SupabaseClient? supabaseClient;

  @override
  State<AppGymApp> createState() => _AppGymAppState();
}

class _AppGymAppState extends State<AppGymApp> {
  late final AppDatabase _db;
  late final ProfileRepository _profileRepository;
  late final AuthProvider _authProvider;
  late final RoutineRepository _routineRepository;
  late final WorkoutRepository _workoutRepository;
  late final GoalRepository _goalRepository;
  late final NutritionRepository _nutritionRepository;
  late final RecoveryRepository _recoveryRepository;
  late final StatsRepository _statsRepository;
  late final GamificationRepository _gamificationRepository;
  late final ExerciseRepository _exerciseRepository;
  late final BodyMeasurementRepository _bodyMeasurementRepository;
  SocialRepository? _socialRepository;
  late final SyncEngine _syncEngine;
  late final ThemeProvider _themeProvider;

  @override
  void initState() {
    super.initState();
    _themeProvider = ThemeProvider();

    _db = AppDatabase();
    seedExercisesIfEmpty(_db);
    _profileRepository = ProfileRepository(_db);
    _authProvider = AuthProvider(widget.authRepository, _profileRepository)
      ..tryAutoLogin();
    _routineRepository = RoutineRepository(_db);
    _workoutRepository = WorkoutRepository(_db);
    _goalRepository = GoalRepository(_db);
    _nutritionRepository = NutritionRepository(_db);
    _recoveryRepository = RecoveryRepository(_db);
    _statsRepository = StatsRepository(_db);
    _gamificationRepository = GamificationRepository(_db);
    _exerciseRepository = ExerciseRepository(_db);
    _bodyMeasurementRepository = BodyMeasurementRepository(_db);

    final supabase = widget.supabaseClient;
    _socialRepository = supabase != null ? SocialRepository(supabase) : null;

    // Orden importa: las rutinas deben sincronizar antes que las sesiones de
    // entrenamiento, porque una sesión offline referencia su rutina por id
    // local y necesita el serverId ya resuelto para mandarse al servidor.
    _syncEngine = SyncEngine(
      db: _db,
      entities: supabase == null
          ? const []
          : [
              ProfileSyncable(supabase),
              RoutineSyncable(supabase),
              WorkoutSessionSyncable(supabase),
              GoalSyncable(supabase),
              NutritionSyncable(supabase),
              RecoverySyncable(supabase),
            ],
    )..start();
  }

  @override
  void dispose() {
    _syncEngine.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        Provider<AppDatabase>.value(value: _db),
        Provider<ProfileRepository>.value(value: _profileRepository),
        Provider<RoutineRepository>.value(value: _routineRepository),
        Provider<WorkoutRepository>.value(value: _workoutRepository),
        Provider<GoalRepository>.value(value: _goalRepository),
        Provider<NutritionRepository>.value(value: _nutritionRepository),
        Provider<RecoveryRepository>.value(value: _recoveryRepository),
        Provider<StatsRepository>.value(value: _statsRepository),
        Provider<GamificationRepository>.value(value: _gamificationRepository),
        Provider<ExerciseRepository>.value(value: _exerciseRepository),
        Provider<BodyMeasurementRepository>.value(
          value: _bodyMeasurementRepository,
        ),
        Provider<SocialRepository?>.value(value: _socialRepository),
        ChangeNotifierProvider<ThemeProvider>.value(value: _themeProvider),
      ],
      child: Consumer<ThemeProvider>(
        builder: (context, themeProvider, _) => MaterialApp(
          title: 'NexFit',
          debugShowCheckedModeBanner: false,
          theme: AppTheme.light(),
          darkTheme: AppTheme.dark(),
          themeMode: themeProvider.mode,
          home: Consumer<AuthProvider>(
            builder: (context, auth, _) {
              switch (auth.status) {
                case AuthStatus.unknown:
                  return const _SplashScreen();
                case AuthStatus.unauthenticated:
                  return const LoginScreen();
                case AuthStatus.authenticated:
                  return const HomeShell();
              }
            },
          ),
        ),
      ),
    );
  }
}

class _SplashScreen extends StatelessWidget {
  const _SplashScreen();

  @override
  Widget build(BuildContext context) {
    return const Scaffold(
      body: Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.fitness_center, size: 64),
            SizedBox(height: 16),
            CircularProgressIndicator(),
          ],
        ),
      ),
    );
  }
}
