import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../widgets/pill_tab_bar.dart';
import '../calculators/calculators_hub_screen.dart';
import '../measurements/measurements_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../recovery/recovery_screen.dart';
import '../wearables/wearables_screen.dart';

/// Hub "Cuerpo": agrupa Nutrición, Recuperación, Medidas, Wearables y
/// Herramientas (calculadoras) -- todo lo que responde "¿cómo está mi cuerpo
/// hoy?" (ver plan de rediseño v2).
class CuerpoHubScreen extends StatelessWidget {
  const CuerpoHubScreen({super.key, this.initialTabIndex = 0});

  final int initialTabIndex;

  @override
  Widget build(BuildContext context) {
    return DefaultTabController(
      length: 5,
      initialIndex: initialTabIndex,
      child: Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Cuerpo')),
        body: Column(
          children: [
            const PillTabBar(
              isScrollable: true,
              tabs: [
                Tab(text: 'Nutrición'),
                Tab(text: 'Recuperación'),
                Tab(text: 'Medidas'),
                Tab(text: 'Wearables'),
                Tab(text: 'Herramientas'),
              ],
            ),
            const Expanded(
              child: TabBarView(
                children: [
                  NutritionScreen(),
                  RecoveryScreen(),
                  MeasurementsScreen(),
                  WearablesScreen(),
                  CalculatorsHubScreen(),
                ],
              ),
            ),
          ],
        ),
      ),
    );
  }
}
