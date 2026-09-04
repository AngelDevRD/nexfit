import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/app_updater.dart';
import '../../core/theme.dart';
import '../../repositories/active_workout_repository.dart';
import '../cuerpo/cuerpo_hub_screen.dart';
import '../entrenar/entrenar_hub_screen.dart';
import '../profile/profile_screen.dart';
import '../progreso/progreso_hub_screen.dart';
import '../workout/active_workout_screen.dart';
import 'dashboard_screen.dart';

class HomeShell extends StatefulWidget {
  const HomeShell({super.key});

  @override
  State<HomeShell> createState() => _HomeShellState();
}

class _HomeShellState extends State<HomeShell> {
  int _index = 0;

  @override
  void initState() {
    super.initState();
    // Despues del primer frame para no bloquear el arranque, y aqui (en vez
    // de en main.dart) porque este es el primer widget con un BuildContext
    // real montado bajo el Navigator/Overlay del MaterialApp: main.dart solo
    // decide que pantalla mostrar segun el estado de auth (splash/login/home),
    // asi que su propio context no sirve para abrir un dialogo con showDialog.
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (mounted) {
        AppUpdater.checkForUpdate(context, slug: 'nexfit');
      }
    });
  }

  // Dashboard muestra datos que cambian desde otras pantallas (un
  // entrenamiento recien finalizado, XP/racha actualizada). Como el
  // IndexedStack mantiene vivas las pantallas, solo carga una vez en su
  // initState; al reseleccionar su tab se recrea el widget (cambia la key)
  // para que vuelva a consultar la API. Historial ahora recarga por su cuenta
  // al entrar a esa pestaña dentro de EntrenarHubScreen.
  int _dashboardEpoch = 0;

  // N2: para que las tiles que quedan en el Dashboard (la insignia de XP,
  // "Ver progreso") lleven a Progreso CAMBIANDO de pestaña -- no apilando una
  // instancia nueva del hub encima del shell, sin barra inferior. El epoch
  // fuerza que `ProgresoHubScreen` se reconstruya con el sub-tab pedido
  // incluso si ya estaba montado en el `IndexedStack`.
  int _progresoInitialTab = 0;
  int _progresoEpoch = 0;

  void _onDestinationSelected(int i) {
    setState(() {
      if (i == 0) _dashboardEpoch++;
      _index = i;
    });
  }

  void _openProgresoTab(int subTab) {
    setState(() {
      _index = 2;
      _progresoInitialTab = subTab;
      _progresoEpoch++;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: Stack(
        children: [
          IndexedStack(
            index: _index,
            children: [
              DashboardScreen(
                key: ValueKey('dashboard-$_dashboardEpoch'),
                onOpenProgresoTab: _openProgresoTab,
              ),
              const EntrenarHubScreen(),
              ProgresoHubScreen(
                key: ValueKey('progreso-$_progresoEpoch'),
                initialTabIndex: _progresoInitialTab,
              ),
              const CuerpoHubScreen(),
              const ProfileScreen(),
            ],
          ),
          // N3: banner de "entrenamiento en curso" visible en TODO el shell
          // (no solo en una pestaña) -- antes el único punto de reanudación
          // era una tarjeta enterrada en Entrenar -> Historial.
          const Positioned(
            left: 0,
            right: 0,
            bottom: 0,
            child: _ActiveWorkoutBanner(),
          ),
        ],
      ),
      bottomNavigationBar: NavigationBar(
        selectedIndex: _index,
        onDestinationSelected: _onDestinationSelected,
        destinations: const [
          NavigationDestination(
            icon: Icon(Icons.home_outlined),
            selectedIcon: Icon(Icons.home),
            label: 'Inicio',
          ),
          NavigationDestination(
            icon: Icon(Icons.fitness_center_outlined),
            selectedIcon: Icon(Icons.fitness_center),
            label: 'Entrenar',
          ),
          NavigationDestination(
            icon: Icon(Icons.bar_chart_outlined),
            selectedIcon: Icon(Icons.bar_chart),
            label: 'Progreso',
          ),
          NavigationDestination(
            icon: Icon(Icons.favorite_outline),
            selectedIcon: Icon(Icons.favorite),
            label: 'Cuerpo',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Cuenta',
          ),
        ],
      ),
    );
  }
}

class _ActiveWorkoutBanner extends StatelessWidget {
  const _ActiveWorkoutBanner();

  @override
  Widget build(BuildContext context) {
    final activeRepository = context.watch<ActiveWorkoutRepository>();
    return StreamBuilder<int?>(
      stream: activeRepository.watchCurrentSessionId(),
      builder: (context, snapshot) {
        final sessionId = snapshot.data;
        if (sessionId == null) return const SizedBox.shrink();
        return Material(
          color: Colors.transparent,
          child: InkWell(
            onTap: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ActiveWorkoutScreen(sessionId: sessionId),
              ),
            ),
            child: Container(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              decoration: BoxDecoration(
                color: AppColors.primary,
                boxShadow: AppGlow.primary,
              ),
              child: SafeArea(
                top: false,
                bottom: false,
                child: Row(
                  children: [
                    const Icon(
                      Icons.fitness_center,
                      color: AppColors.onPrimary,
                      size: 18,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        'Entrenamiento en curso',
                        style: Theme.of(context).textTheme.labelLarge
                            ?.copyWith(color: AppColors.onPrimary),
                      ),
                    ),
                    Text(
                      'Continuar',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.onPrimary,
                        fontWeight: FontWeight.bold,
                      ),
                    ),
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.onPrimary,
                      size: 18,
                    ),
                  ],
                ),
              ),
            ),
          ),
        );
      },
    );
  }
}
