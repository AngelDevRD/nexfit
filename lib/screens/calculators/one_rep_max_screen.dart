import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/calculators.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../providers/weight_unit_provider.dart';

class OneRepMaxScreen extends StatefulWidget {
  const OneRepMaxScreen({super.key});

  @override
  State<OneRepMaxScreen> createState() => _OneRepMaxScreenState();
}

class _OneRepMaxScreenState extends State<OneRepMaxScreen> {
  final _weightController = TextEditingController();
  final _repsController = TextEditingController();
  double? _result;
  bool _loading = false;

  Future<void> _calculate() async {
    final enteredWeight = double.tryParse(_weightController.text);
    final reps = int.tryParse(_repsController.text);
    if (enteredWeight == null || reps == null) return;
    setState(() => _loading = true);
    final weightUnit = context.read<WeightUnitProvider>().unit;
    final weight = displayToKg(enteredWeight, weightUnit);
    setState(() {
      _result = Calculators.oneRepMax(weight, reps);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final weightUnit = context.watch<WeightUnitProvider>().unit;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('1RM estimado')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Datos de la serie',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          TextFormField(
            controller: _weightController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: InputDecoration(
              labelText: 'Peso levantado (${weightUnit.label})',
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _repsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(
              labelText: 'Repeticiones realizadas',
            ),
          ),
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
                  left: BorderSide(color: AppColors.primary, width: 4),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    '1RM ESTIMADO',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                  const SizedBox(height: 4),
                  Text(
                    formatWeight(_result!, weightUnit),
                    style: Theme.of(context).textTheme.headlineMedium?.copyWith(
                      color: AppColors.primary,
                    ),
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
