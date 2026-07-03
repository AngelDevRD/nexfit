import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/user.dart';
import '../../services/calculator_service.dart';

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
    final weight = double.tryParse(_weightController.text);
    final height = double.tryParse(_heightController.text);
    if (weight == null || height == null) return;
    setState(() => _loading = true);

    final service = CalculatorService(context.read<ApiClient>());
    final bodyFat = double.tryParse(_bodyFatController.text);
    final results = await Future.wait([
      service.bmi(weight, height),
      service.leanBodyMass(weight, height, _sex, bodyFatPct: bodyFat),
      service.idealWeight(height, _sex),
    ]);

    setState(() {
      _bmi = (results[0]['bmi'] as num).toDouble();
      _bmiCategory = results[0]['category'] as String;
      _leanBodyMass = (results[1]['lean_body_mass_kg'] as num).toDouble();
      _idealWeight = (results[2]['ideal_weight_kg'] as num).toDouble();
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('IMC y masa magra')),
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
          const SizedBox(height: 12),
          TextField(
            controller: _bodyFatController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(
              labelText:
                  '% Grasa corporal (opcional, mejora precisión de masa magra)',
            ),
          ),
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _calculate,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Calcular'),
          ),
          if (_bmi != null) ...[
            const SizedBox(height: 24),
            _ResultTile(
              label: 'IMC',
              value: '$_bmi (${_bmiCategoryLabel(_bmiCategory!)})',
            ),
            _ResultTile(
              label: 'Masa magra estimada',
              value: '$_leanBodyMass kg',
            ),
            _ResultTile(
              label: 'Peso ideal de referencia',
              value: '$_idealWeight kg',
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

  const _ResultTile({required this.label, required this.value});

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
