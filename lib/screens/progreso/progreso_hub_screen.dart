import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/pill_tab_bar.dart';
import '../gamification/gamification_screen.dart';
import '../goals/goals_screen.dart';
import '../social/challenges_screen.dart';
import '../stats/stats_hub_screen.dart';
import 'progreso_resumen_tab.dart';

/// Hub "Progreso": agrupa Resumen, Estadísticas, Objetivos, Logros y Retos --
/// todo lo que responde "¿cómo voy?" (ver plan de rediseño v2). Antes vivían
/// como 4 destinos separados desde el Dashboard (Estadísticas, Objetivos,
/// Logros/Gamificación, Calendario) más Retos como tile de Social.
class ProgresoHubScreen extends StatelessWidget {
  const ProgresoHubScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      initialIndex: initialTabIndex,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Progreso')),
        body: Column(
          children: [
            const PillTabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Resumen'),
                Tab(text: 'Estadísticas'),
                Tab(text: 'Objetivos'),
                Tab(text: 'Logros'),
                Tab(text: 'Retos'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  ProgresoResumenTab(),
                  StatsHubScreen(),
                  GoalsScreen(),
                  GamificationScreen(),
                  ChallengesScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
