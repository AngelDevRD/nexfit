import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/calculators.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../models/user.dart';
import '../../providers/weight_unit_provider.dart';

class BodyCompositionScreen extends StatefulWidget {
  const BodyCompositionScreen({super.key});

  @override
  State<BodyCompositionScreen> createState() => _BodyCompositionScreenState();
}

class _BodyCompositionScreenState extends State<BodyCompositionScreen> {
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _bodyFatController = TextEditingController();
  String _sex = 'male';
  bool _loading = false;

  double? _bmi;
  String? _bmiCategory;
  double? _leanBodyMass;
  double? _idealWeight;

  Future<void> _calculate() async {
    final enteredWeight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    if (enteredWeight == null || height == null) return;
    setState(() => _loading = true);

    final weightUnit = context.read<WeightUnitProvider>().unit;
    // Las fórmulas de los calculadores operan en kg -- el peso ingresado en
    // la unidad elegida se convierte antes de calcular (U1).
    final weight = displayToKg(enteredWeight, weightUnit);
    final bodyFat = double.tryParse(_bodyFatController.text);
    final (bmiValue, bmiCategory) = Calculators.bmi(weight, height);

    setState(() {
      _bmi = bmiValue;
      _bmiCategory = bmiCategory;
      _leanBodyMass = Calculators.leanBodyMass(
        weight,
        height,
        _sex,
        bodyFatPct: bodyFat,
      );
      _idealWeight = Calculators.idealWeight(height, _sex);
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    final weightUnit = context.watch<WeightUnitProvider>().unit;
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('IMC y masa magra')),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text('Tus datos', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.md),
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: InputDecoration(
                    labelText: 'Peso (${weightUnit.label})',
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: TextFormField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Altura (cm)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _sex,
            decoration: const InputDecoration(labelText: 'Sexo'),
            items: sexOptions.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _sex = v ?? 'male'),
          ),
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _bodyFatController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText:
                  '% Grasa corporal (opcional, mejora precisión de masa magra)',
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
          if (_bmi != null) ...[
            const SizedBox(height: AppSpacing.lg),
            Text('Resultados', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            _ResultTile(
              label: 'IMC',
              value: '$_bmi (${_bmiCategoryLabel(_bmiCategory!)})',
              accent: AppColors.primary,
            ),
            _ResultTile(
              label: 'Masa magra estimada',
              value: formatWeight(_leanBodyMass!, weightUnit),
              accent: AppColors.secondary,
            ),
            _ResultTile(
              label: 'Peso ideal de referencia',
              value: formatWeight(_idealWeight!, weightUnit),
              accent: AppColors.tertiary,
            ),
          ],
        ],
      ),
    );
  }

  String _bmiCategoryLabel(String category) {
    switch (category) {
      case 'bajo_peso':
        return 'Bajo peso';
      case 'normal':
        return 'Normal';
      case 'sobrepeso':
        return 'Sobrepeso';
      default:
        return 'Obesidad';
    }
  }
}

class _ResultTile extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _ResultTile({
    required this.label,
    required this.value,
    required this.accent,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border(left: BorderSide(color: accent, width: 4)),
      ),
      child: Row(
        children: [
          Expanded(
            child: Text(label, style: Theme.of(context).textTheme.bodyLarge),
          ),
          Text(
            value,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
