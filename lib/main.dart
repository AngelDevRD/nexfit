import 'dart:developer' as developer;

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import 'package:supabase_flutter/supabase_flutter.dart';

import 'core/api_client.dart';
import 'core/auth/auth_repository.dart';
import 'core/auth/supabase_auth_repository.dart';
import 'core/auth/unavailable_auth_repository.dart';
import 'core/local/database.dart';
import 'core/local/local_bootstrap.dart';
import 'core/supabase_config.dart';
import 'core/sync/entities/routine_syncable.dart';
import 'core/sync/entities/workout_session_syncable.dart';
import 'core/sync/sync_engine.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
import 'providers/theme_provider.dart';
import 'repositories/routine_repository.dart';
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
  try {
    await Supabase.initialize(
      url: SupabaseConfig.url,
      publishableKey: SupabaseConfig.publishableKey,
    );
    authRepository = SupabaseAuthRepository(Supabase.instance.client);
  } catch (e, st) {
    developer.log(
      'Supabase.initialize fallo -- auth deshabilitada esta sesión',
      error: e,
      stackTrace: st,
      name: 'main',
    );
    authRepository = const UnavailableAuthRepository();
  }
  runApp(AppGymApp(authRepository: authRepository));
}

class AppGymApp extends StatefulWidget {
  const AppGymApp({super.key, required this.authRepository});

  final AuthRepository authRepository;

  @override
  State<AppGymApp> createState() => _AppGymAppState();
}

class _AppGymAppState extends State<AppGymApp> {
  late final ApiClient _client;
  late final AuthProvider _authProvider;
  late final AppDatabase _db;
  late final RoutineRepository _routineRepository;
  late final WorkoutRepository _workoutRepository;
  late final SyncEngine _syncEngine;
  late final ThemeProvider _themeProvider;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _authProvider = AuthProvider(widget.authRepository, _client)
      ..tryAutoLogin();
    _themeProvider = ThemeProvider();

    _db = AppDatabase();
    seedExercisesIfEmpty(_db);
    _routineRepository = RoutineRepository(_db);
    _workoutRepository = WorkoutRepository(_db);
    // Orden importa: las rutinas deben sincronizar antes que las sesiones de
    // entrenamiento, porque una sesión offline referencia su rutina por id
    // local y necesita el serverId ya resuelto para mandarse al backend.
    _syncEngine = SyncEngine(
      db: _db,
      entities: [RoutineSyncable(_client), WorkoutSessionSyncable(_client)],
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
        Provider<ApiClient>.value(value: _client),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
        Provider<AppDatabase>.value(value: _db),
        Provider<RoutineRepository>.value(value: _routineRepository),
        Provider<WorkoutRepository>.value(value: _workoutRepository),
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
