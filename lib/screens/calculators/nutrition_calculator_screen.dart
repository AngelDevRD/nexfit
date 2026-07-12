import 'package:flutter/material.dart';

import '../../core/calculators.dart';
import '../../core/theme.dart';
import '../../models/user.dart';

class NutritionCalculatorScreen extends StatefulWidget {
  const NutritionCalculatorScreen({super.key});

  @override
  State<NutritionCalculatorScreen> createState() =>
      _NutritionCalculatorScreenState();
}

class _NutritionCalculatorScreenState extends State<NutritionCalculatorScreen> {
  final _weightController = TextEditingController();
  final _heightController = TextEditingController();
  final _ageController = TextEditingController();
  String _sex = 'male';
  String _activityLevel = 'moderate';
  String _goal = 'hypertrophy';
  bool _loading = false;
  Map<String, double>? _result;

  Future<void> _calculate() async {
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    final age = int.tryParse(_ageController.text);
    if (weight == null || height == null || age == null) return;
    setState(() => _loading = true);
    setState(() {
      _result = Calculators.nutrition(
        weightKg: weight,
        heightCm: height,
        age: age,
        sex: _sex,
        activityLevel: _activityLevel,
        goal: _goal,
      );
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Nutrición diaria')),
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
                  decoration: const InputDecoration(labelText: 'Peso (kg)'),
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
          Row(
            children: [
              Expanded(
                child: TextFormField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Edad'),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: DropdownButtonFormField<String>(
                  initialValue: _sex,
                  decoration: const InputDecoration(labelText: 'Sexo'),
                  items: sexOptions.entries
                      .map(
                        (e) => DropdownMenuItem(
                          value: e.key,
                          child: Text(e.value),
                        ),
                      )
                      .toList(),
                  onChanged: (v) => setState(() => _sex = v ?? 'male'),
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _activityLevel,
            decoration: const InputDecoration(labelText: 'Nivel de actividad'),
            items: activityLevelOptions.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _activityLevel = v ?? 'moderate'),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _goal,
            decoration: const InputDecoration(labelText: 'Objetivo'),
            items: goalOptions.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _goal = v ?? 'hypertrophy'),
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
            Text('Resultados', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.md),
            _ResultRow(
              label: 'Calorías objetivo',
              value: '${_result!['target_calories']!.toStringAsFixed(0)} kcal',
              accent: AppColors.primary,
            ),
            _ResultRow(
              label: 'Proteínas',
              value: '${_result!['protein_g']!.toStringAsFixed(0)} g',
              accent: AppColors.secondary,
            ),
            _ResultRow(
              label: 'Carbohidratos',
              value: '${_result!['carbs_g']!.toStringAsFixed(0)} g',
              accent: AppColors.tertiary,
            ),
            _ResultRow(
              label: 'Grasas',
              value: '${_result!['fat_g']!.toStringAsFixed(0)} g',
              accent: AppColors.warning,
            ),
            _ResultRow(
              label: 'Agua',
              value: '${_result!['water_ml']!.toStringAsFixed(0)} ml',
              accent: AppColors.onSurfaceVariant,
            ),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;
  final Color accent;

  const _ResultRow({
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
