import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/pill_tab_bar.dart';
import '../exercises/exercise_list_screen.dart';
import '../history/history_list_screen.dart';
import '../routines/routine_list_screen.dart';
import '../workout/start_workout_screen.dart';

/// Hub "Entrenar": agrupa Ejercicios, Rutinas e Historial en un mismo lugar
/// (reorganización de navegación acordada — ver plan de rediseño v2). Cada
/// pantalla embebida conserva el 100% de su lógica/estado propio, solo pierde
/// su Scaffold/AppBar individual (siempre vive dentro de este hub -- N5).
class EntrenarHubScreen extends StatefulWidget {
  const EntrenarHubScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  State<EntrenarHubScreen> createState() => _EntrenarHubScreenState();
}

class _EntrenarHubScreenState extends State<EntrenarHubScreen>
    with SingleTickerProviderStateMixin {
  late final TabController _tabController;
  // Recarga el historial cada vez que se entra a esa pestaña, igual que
  // hacía HomeShell antes de la reorganización (los datos cambian desde
  // otras pantallas: un entrenamiento recién finalizado).
  int _historyEpoch = 0;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(
      length: 3,
      vsync: this,
      initialIndex: widget.initialTabIndex,
    );
    _tabController.addListener(() {
      if (_tabController.indexIsChanging) return;
      if (_tabController.index == 2) setState(() => _historyEpoch++);
    });
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Entrenar')),
      floatingActionButton: FloatingActionButton.extended(
        backgroundColor: AppColors.primaryContainer,
        foregroundColor: AppColors.onPrimaryContainer,
        icon: const Icon(Icons.play_arrow),
        label: const Text('Empezar entrenamiento'),
        onPressed: () => Navigator.of(context).push(
          MaterialPageRoute(builder: (_) => const StartWorkoutScreen()),
        ),
      ),
      body: Column(
        children: [
          PillTabBar(
            controller: _tabController,
            tabs: const [
              Tab(text: 'Ejercicios'),
              Tab(text: 'Rutinas'),
              Tab(text: 'Historial'),
            ],
          ),
          Expanded(
            child: TabBarView(
              controller: _tabController,
              children: [
                const ExerciseListScreen(),
                const RoutineListScreen(),
                HistoryListScreen(key: ValueKey('history-$_historyEpoch')),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
