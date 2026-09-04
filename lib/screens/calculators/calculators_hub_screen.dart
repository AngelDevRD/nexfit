import 'package:flutter/material.dart';

import '../../core/theme.dart';
import 'one_rep_max_screen.dart';
import 'body_composition_screen.dart';
import 'nutrition_calculator_screen.dart';
import 'fat_loss_rate_screen.dart';

/// N5: siempre vive dentro de [CuerpoHubScreen] -- el hub provee
/// Scaffold/AppBar, esta pantalla solo devuelve contenido.
class CalculatorsHubScreen extends StatelessWidget {
  const CalculatorsHubScreen({super.key});

  @override
  Widget build(BuildContext context) {
    final items = <_CalcItem>[
      _CalcItem(
        '1RM estimado',
        'Peso máximo estimado para 1 repetición',
        Icons.fitness_center,
        AppColors.primaryContainer,
        AppColors.onPrimaryContainer,
        (context) => const OneRepMaxScreen(),
      ),
      _CalcItem(
        'IMC y masa magra',
        'Índice de masa corporal, masa magra y peso ideal',
        Icons.monitor_weight_outlined,
        AppColors.surfaceContainerHighest,
        AppColors.secondary,
        (context) => const BodyCompositionScreen(),
      ),
      _CalcItem(
        'Nutrición diaria',
        'Calorías, proteínas, carbohidratos, grasas y agua',
        Icons.restaurant_outlined,
        AppColors.tertiaryContainer,
        AppColors.onTertiaryContainer,
        (context) => const NutritionCalculatorScreen(),
      ),
      _CalcItem(
        'Ritmo de pérdida de grasa',
        'Semanas estimadas para llegar a tu peso objetivo',
        Icons.trending_down,
        AppColors.surfaceContainerHighest,
        AppColors.warning,
        (context) => const FatLossRateScreen(),
      ),
    ];

    final content = Column(
          children: [
            Expanded(
              child: ListView(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.md,
                  0,
                  AppSpacing.md,
                  AppSpacing.lg,
                ),
                children: [
                  Text(
                    'Herramientas',
                    style: Theme.of(context).textTheme.titleLarge,
                  ),
                  Text(
                    'Métricas de precisión para tu rendimiento y objetivos.',
                    style: Theme.of(context).textTheme.bodySmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.md),
                  for (final item in items)
                    Padding(
                      padding: const EdgeInsets.only(bottom: AppSpacing.md),
                      child: _CalcTile(item: item),
                    ),
                ],
              ),
            ),
          ],
        );

    return content;
  }
}

class _CalcItem {
  final String title;
  final String subtitle;
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final WidgetBuilder builder;

  _CalcItem(
    this.title,
    this.subtitle,
    this.icon,
    this.iconBg,
    this.iconColor,
    this.builder,
  );
}

class _CalcTile extends StatelessWidget {
  final _CalcItem item;

  const _CalcTile({required this.item});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: () => Navigator.of(
          context,
        ).push(MaterialPageRoute(builder: item.builder)),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 44,
                height: 44,
                decoration: BoxDecoration(
                  color: item.iconBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(item.icon, color: item.iconColor, size: 22),
              ),
              const SizedBox(height: AppSpacing.md),
              Text(
                item.title,
                style: Theme.of(
                  context,
                ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
              ),
              const SizedBox(height: 4),
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
