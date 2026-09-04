import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/calculators.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../providers/weight_unit_provider.dart';

class FatLossRateScreen extends StatefulWidget {
  const FatLossRateScreen({super.key});

  @override
  State<FatLossRateScreen> createState() => _FatLossRateScreenState();
}

class _FatLossRateScreenState extends State<FatLossRateScreen> {
  final _currentController = TextEditingController();
  final _targetController = TextEditingController();
  bool _loading = false;
  Map<String, double>? _result;
  String? _error;

  Future<void> _calculate() async {
    final enteredCurrent = double.tryParse(_currentController.text);
    final enteredTarget = double.tryParse(_targetController.text);
    if (enteredCurrent == null || enteredTarget == null) return;
    final weightUnit = context.read<WeightUnitProvider>().unit;
    final current = displayToKg(enteredCurrent, weightUnit);
    final target = displayToKg(enteredTarget, weightUnit);
    if (target >= current) {
      setState(() {
        _error = 'El peso objetivo debe ser menor al peso actual';
        _result = null;
      });
      return;
    }
    setState(() {
      _loading = true;
      _error = null;
    });
    setState(() {
      _result = Calculators.fatLossRate(current, target);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final weightUnit = context.watch<WeightUnitProvider>().unit;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Ritmo de pérdida de grasa')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Tu objetivo', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _currentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Peso actual (${weightUnit.label})',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Peso objetivo (${weightUnit.label})',
            ),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: AppSpacing.lg),
          FilledButton(
            onPressed: _loading ? null : _calculate,
            child: _loading
                ? const SizedBox(
                    height: 18,
                    width: 18,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text('Calcular'),
          ),
          if (_result != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Container(
              padding: const EdgeInsets.all(AppSpacing.lg),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: const Border(
                  left: BorderSide(color: AppColors.secondary, width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'TIEMPO ESTIMADO',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    '${_result!['estimated_weeks']} semanas',
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.secondary,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    'estimadas para llegar a tu objetivo',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  Text(
                    'Ritmo seguro: '
                    '${formatWeight(_result!['min_weekly_loss_kg']!, weightUnit, decimals: 2)}-'
                    '${formatWeight(_result!['max_weekly_loss_kg']!, weightUnit, decimals: 2)}/semana',
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
