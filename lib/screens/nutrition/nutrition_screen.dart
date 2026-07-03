import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/nutrition.dart';
import '../../services/nutrition_service.dart';

class NutritionScreen extends StatefulWidget {
  const NutritionScreen({super.key});

  @override
  State<NutritionScreen> createState() => _NutritionScreenState();
}

class _NutritionScreenState extends State<NutritionScreen> {
  late final NutritionService _service;
  List<NutritionLog> _logs = [];
  bool _loading = true;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  final _caloriesController = TextEditingController();
  final _proteinController = TextEditingController();
  final _carbsController = TextEditingController();
  final _fatController = TextEditingController();
  final _waterController = TextEditingController();
  bool _saving = false;

  @override
  void initState() {
    super.initState();
    _service = NutritionService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final logs = await _service.list();
    setState(() {
      _logs = logs;
      _loading = false;
    });
  }

  Future<void> _save() async {
    setState(() => _saving = true);
    await _service.upsert({
      'log_date': DateTime.now().toIso8601String().split('T').first,
      'calories': double.tryParse(_caloriesController.text) ?? 0,
      'protein_g': double.tryParse(_proteinController.text) ?? 0,
      'carbs_g': double.tryParse(_carbsController.text) ?? 0,
      'fat_g': double.tryParse(_fatController.text) ?? 0,
      'water_ml': double.tryParse(_waterController.text) ?? 0,
    });
    _caloriesController.clear();
    _proteinController.clear();
    _carbsController.clear();
    _fatController.clear();
    _waterController.clear();
    setState(() => _saving = false);
    _load();
  }

  @override
  void dispose() {
    _caloriesController.dispose();
    _proteinController.dispose();
    _carbsController.dispose();
    _fatController.dispose();
    _waterController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Nutrición diaria')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Text(
              'Registrar hoy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _caloriesController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Calorías'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: TextField(
                    controller: _waterController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Agua (ml)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: _proteinController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(
                      labelText: 'Proteína (g)',
                    ),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _carbsController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Carbos (g)'),
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: TextField(
                    controller: _fatController,
                    keyboardType: TextInputType.number,
                    decoration: const InputDecoration(labelText: 'Grasas (g)'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _save,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Guardar registro de hoy'),
            ),
            const SizedBox(height: 24),
            Text('Historial', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!_loading && _logs.isEmpty)
              const Text('Sin registros todavía.'),
            for (final log in _logs)
              Card(
                child: ListTile(
                  title: Text(_dateFormat.format(log.logDate)),
                  subtitle: Text(
                    '${log.proteinG}g prot · ${log.carbsG}g carb · ${log.fatG}g grasa · ${log.waterMl}ml agua',
                  ),
                  trailing: Text('${log.calories.toStringAsFixed(0)} kcal'),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
