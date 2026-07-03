import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/user.dart';
import '../../services/calculator_service.dart';

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
  Map<String, dynamic>? _result;

  Future<void> _calculate() async {
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    final age = int.tryParse(_ageController.text);
    if (weight == null || height == null || age == null) return;
    setState(() => _loading = true);
    final result = await CalculatorService(context.read<ApiClient>()).nutrition(
      weightKg: weight,
      heightCm: height,
      age: age,
      sex: _sex,
      activityLevel: _activityLevel,
      goal: _goal,
    );
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrición diaria')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _weightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Peso (kg)'),
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: TextField(
                  controller: _heightController,
                  keyboardType: const TextInputType.numberWithOptions(
                    decimal: true,
                  ),
                  decoration: const InputDecoration(labelText: 'Altura (cm)'),
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          Row(
            children: [
              Expanded(
                child: TextField(
                  controller: _ageController,
                  keyboardType: TextInputType.number,
                  decoration: const InputDecoration(labelText: 'Edad'),
                ),
              ),
              const SizedBox(width: 12),
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 12),
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
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _calculate,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Calcular'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 24),
            _ResultRow(
              label: 'Calorías objetivo',
              value: '${_result!['target_calories']} kcal',
            ),
            _ResultRow(label: 'Proteínas', value: '${_result!['protein_g']} g'),
            _ResultRow(
              label: 'Carbohidratos',
              value: '${_result!['carbs_g']} g',
            ),
            _ResultRow(label: 'Grasas', value: '${_result!['fat_g']} g'),
            _ResultRow(label: 'Agua', value: '${_result!['water_ml']} ml'),
          ],
        ],
      ),
    );
  }
}

class _ResultRow extends StatelessWidget {
  final String label;
  final String value;

  const _ResultRow({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 8),
      child: ListTile(
        title: Text(label),
        trailing: Text(value, style: Theme.of(context).textTheme.titleMedium),
      ),
    );
  }
}
