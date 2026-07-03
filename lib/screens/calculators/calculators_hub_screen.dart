import 'package:flutter/material.dart';

import 'one_rep_max_screen.dart';
import 'body_composition_screen.dart';
import 'nutrition_calculator_screen.dart';
import 'fat_loss_rate_screen.dart';

class CalculatorsHubScreen extends StatelessWidget {
  const CalculatorsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_CalcItem>[
      _CalcItem(
        '1RM estimado',
        'Peso máximo estimado para 1 repetición',
        Icons.fitness_center,
        (context) => const OneRepMaxScreen(),
      ),
      _CalcItem(
        'IMC y masa magra',
        'Índice de masa corporal, masa magra y peso ideal',
        Icons.monitor_weight_outlined,
        (context) => const BodyCompositionScreen(),
      ),
      _CalcItem(
        'Nutrición diaria',
        'Calorías, proteínas, carbohidratos, grasas y agua',
        Icons.restaurant_outlined,
        (context) => const NutritionCalculatorScreen(),
      ),
      _CalcItem(
        'Ritmo de pérdida de grasa',
        'Semanas estimadas para llegar a tu peso objetivo',
        Icons.trending_down,
        (context) => const FatLossRateScreen(),
      ),
    ];

    return Scaffold(
      appBar: AppBar(title: const Text('Calculadoras')),
      body: ListView.separated(
        padding: const EdgeInsets.all(16),
        itemCount: items.length,
        separatorBuilder: (_, __) => const SizedBox(height: 8),
        itemBuilder: (context, index) {
          final item = items[index];
          return Card(
            child: ListTile(
              leading: Icon(item.icon),
              title: Text(item.title),
              subtitle: Text(item.subtitle),
              trailing: const Icon(Icons.chevron_right),
              onTap: () => Navigator.of(
                context,
              ).push(MaterialPageRoute(builder: item.builder)),
            ),
          );
        },
      ),
    );
  }
}

class _CalcItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final WidgetBuilder builder;

  _CalcItem(this.title, this.subtitle, this.icon, this.builder);
}
