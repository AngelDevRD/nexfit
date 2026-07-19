import 'package:flutter/material.dart';

import '../../core/app_updater.dart';
import '../exercises/exercise_list_screen.dart';
import '../history/history_list_screen.dart';
import '../profile/profile_screen.dart';
import '../routines/routine_list_screen.dart';
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

  // Dashboard e Historial muestran datos que cambian desde otras pantallas
  // (un entrenamiento recien finalizado, XP/racha actualizada). Como el
  // IndexedStack mantiene vivas las pantallas, solo cargan una vez en su
  // initState; al reseleccionar su pestaña se recrea el widget (cambia la key)
  // para que vuelva a consultar la API. El resto de pestañas ya recargan por su
  // cuenta al volver de un push (p. ej. el constructor de rutinas).
  int _dashboardEpoch = 0;
  int _historyEpoch = 0;

  void _onDestinationSelected(int i) {
    setState(() {
      if (i == 0) _dashboardEpoch++;
      if (i == 3) _historyEpoch++;
      _index = i;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      body: IndexedStack(
        index: _index,
        children: [
          DashboardScreen(key: ValueKey('dashboard-$_dashboardEpoch')),
          const ExerciseListScreen(),
          const RoutineListScreen(),
          HistoryListScreen(key: ValueKey('history-$_historyEpoch')),
          const ProfileScreen(),
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
            label: 'Ejercicios',
          ),
          NavigationDestination(
            icon: Icon(Icons.list_alt_outlined),
            selectedIcon: Icon(Icons.list_alt),
            label: 'Rutinas',
          ),
          NavigationDestination(
            icon: Icon(Icons.history_outlined),
            selectedIcon: Icon(Icons.history),
            label: 'Historial',
          ),
          NavigationDestination(
            icon: Icon(Icons.person_outline),
            selectedIcon: Icon(Icons.person),
            label: 'Perfil',
          ),
        ],
      ),
    );
  }
}
