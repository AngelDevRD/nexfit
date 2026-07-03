import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../services/calculator_service.dart';

class FatLossRateScreen extends StatefulWidget {
  const FatLossRateScreen({super.key});

  @override
  State<FatLossRateScreen> createState() => _FatLossRateScreenState();
}

class _FatLossRateScreenState extends State<FatLossRateScreen> {
  final _currentController = TextEditingController();
  final _targetController = TextEditingController();
  bool _loading = false;
  Map<String, dynamic>? _result;
  String? _error;

  Future<void> _calculate() async {
    final current = double.tryParse(_currentController.text);
    final target = double.tryParse(_targetController.text);
    if (current == null || target == null) return;
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
    final result = await CalculatorService(
      context.read<ApiClient>(),
    ).fatLossRate(current, target);
    setState(() {
      _result = result;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Ritmo de pérdida de grasa')),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          TextField(
            controller: _currentController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Peso actual (kg)'),
          ),
          const SizedBox(height: 12),
          TextField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Peso objetivo (kg)'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          FilledButton(
            onPressed: _loading ? null : _calculate,
            child: _loading
                ? const CircularProgressIndicator()
                : const Text('Calcular'),
          ),
          if (_result != null) ...[
            const SizedBox(height: 24),
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  children: [
                    Text(
                      '${_result!['estimated_weeks']} semanas',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    const Text('estimadas para llegar a tu objetivo'),
                    const SizedBox(height: 12),
                    Text(
                      'Ritmo seguro: ${_result!['min_weekly_loss_kg']}-${_result!['max_weekly_loss_kg']} kg/semana',
                    ),
                  ],
                ),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
