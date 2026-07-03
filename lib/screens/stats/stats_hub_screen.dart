import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'muscle_analysis_tab.dart';
import 'progress_tab.dart';
import 'strength_profile_tab.dart';
import 'strength_standards_tab.dart';
import 'tonnage_tab.dart';

class StatsHubScreen extends StatelessWidget {
  const StatsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(
          title: const Text('Estadísticas'),
          bottom: TabBar(
            isScrollable: true,
            labelColor: AppColors.primary,
            unselectedLabelColor: AppColors.onSurfaceVariant,
            indicatorColor: AppColors.primary,
            tabs: const [
              Tab(text: 'Músculos'),
              Tab(text: 'Fuerza'),
              Tab(text: 'Progreso'),
              Tab(text: 'Tonelaje'),
              Tab(text: 'Estándares'),
            ],
          ),
        ),
        body: const TabBarView(
          children: [
            MuscleAnalysisTab(),
            StrengthProfileTab(),
            ProgressTab(),
            TonnageTab(),
            StrengthStandardsTab(),
          ],
        ),
      ),
    );
  }
}
