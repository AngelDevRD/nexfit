import 'package:flutter/material.dart';

import '../../core/theme.dart';
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

    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Container(
                    width: 40,
                    height: 40,
                    decoration: const BoxDecoration(
                      shape: BoxShape.circle,
                      color: AppColors.primaryContainer,
                    ),
                    child: const Icon(
                      Icons.calculate,
                      color: AppColors.onPrimaryContainer,
                      size: 20,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      'Calculadoras',
                      style: Theme.of(context).textTheme.headlineSmall
                          ?.copyWith(fontWeight: FontWeight.bold),
                    ),
                  ),
                ],
              ),
            ),
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
                  const SizedBox(height: AppSpacing.md),
                  GridView.count(
                    crossAxisCount: 2,
                    shrinkWrap: true,
                    physics: const NeverScrollableScrollPhysics(),
                    mainAxisSpacing: AppSpacing.md,
                    crossAxisSpacing: AppSpacing.md,
                    childAspectRatio: 1.1,
                    children: [for (final item in items) _CalcTile(item: item)],
                  ),
                ],
              ),
            ),
          ],
        ),
      ),
    );
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
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: item.iconBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(item.icon, color: item.iconColor, size: 20),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(
                item.title,
                style: Theme.of(context).textTheme.labelLarge,
                maxLines: 2,
              ),
              const SizedBox(height: 2),
              Text(
                item.subtitle,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                maxLines: 2,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
