import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/app_updater.dart';
import 'core/local/database.dart';
import 'core/local/local_bootstrap.dart';
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

void main() {
  runApp(const AppGymApp());
}

class AppGymApp extends StatefulWidget {
  const AppGymApp({super.key});

  @override
  State<AppGymApp> createState() => _AppGymAppState();
}

class _AppGymAppState extends State<AppGymApp> {
  bool _updateCheckStarted = false;
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
    _authProvider = AuthProvider(_client)..tryAutoLogin();
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
          builder: (context, child) {
            if (!_updateCheckStarted) {
              _updateCheckStarted = true;
              WidgetsBinding.instance.addPostFrameCallback((_) {
                if (context.mounted) {
                  AppUpdater.checkForUpdate(context, slug: 'nexfit');
                }
              });
            }
            return child!;
          },
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
