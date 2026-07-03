import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import 'core/api_client.dart';
import 'core/theme.dart';
import 'providers/auth_provider.dart';
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
  late final ApiClient _client;
  late final AuthProvider _authProvider;

  @override
  void initState() {
    super.initState();
    _client = ApiClient();
    _authProvider = AuthProvider(_client)..tryAutoLogin();
  }

  @override
  Widget build(BuildContext context) {
    return MultiProvider(
      providers: [
        Provider<ApiClient>.value(value: _client),
        ChangeNotifierProvider<AuthProvider>.value(value: _authProvider),
      ],
      child: MaterialApp(
        title: 'AppGym',
        debugShowCheckedModeBanner: false,
        theme: AppTheme.light(),
        darkTheme: AppTheme.dark(),
        themeMode: ThemeMode.system,
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
