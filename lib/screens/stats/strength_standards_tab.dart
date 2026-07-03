import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/exercise.dart';
import '../../models/stats.dart';
import '../../services/stats_service.dart';
import '../exercises/exercise_picker_screen.dart';

class StrengthStandardsTab extends StatefulWidget {
  const StrengthStandardsTab({super.key});

  @override
  State<StrengthStandardsTab> createState() => _StrengthStandardsTabState();
}

class _StrengthStandardsTabState extends State<StrengthStandardsTab> {
  ExerciseSummary? _selected;
  StrengthStandard? _standard;
  RecordPrediction? _prediction;
  bool _loading = false;
  String? _error;

  Future<void> _pickExercise() async {
    final exercise = await Navigator.of(context).push<ExerciseSummary>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise == null || !mounted) return;
    setState(() {
      _selected = exercise;
      _loading = true;
      _error = null;
      _standard = null;
      _prediction = null;
    });
    final service = StatsService(context.read<ApiClient>());
    try {
      final results = await Future.wait([
        service.strengthStandards(exercise.id),
        service.recordPrediction(exercise.id),
      ]);
      setState(() {
        _standard = results[0] as StrengthStandard?;
        _prediction = results[1] as RecordPrediction?;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    return SingleChildScrollView(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _pickExercise,
            icon: const Icon(Icons.search),
            label: Text(
              _selected?.name ??
                  'Elegir ejercicio (press banca, sentadilla o peso muerto)',
            ),
          ),
          const SizedBox(height: 20),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (_error != null)
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          if (!_loading &&
              _selected != null &&
              _standard == null &&
              _error == null)
            const Text(
              'Sin datos suficientes: completá tu perfil (peso, sexo) y registrá un récord en este ejercicio.',
            ),
          if (_standard != null) ...[
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      _standard!.exerciseName,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${_standard!.liftKg} kg (${_standard!.ratio}x tu peso corporal)',
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Percentil ${_standard!.percentile.toStringAsFixed(0)} · Nivel: ${strengthLevelLabels[_standard!.level] ?? _standard!.level}',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Referencia aproximada, no basada en un dataset poblacional verificado.',
                      style: Theme.of(context).textTheme.bodySmall,
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
          ],
          if (_prediction != null)
            Card(
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Predicción de récord',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const SizedBox(height: 8),
                    Text(
                      'Si mantenés este ritmo, probablemente levantarás ${_prediction!.predictedKg} kg '
                      'dentro de ${_prediction!.weeksAhead} semanas (actual: ${_prediction!.currentBestKg} kg).',
                    ),
                  ],
                ),
              ),
            )
          else if (!_loading && _selected != null && _error == null)
            const Text(
              'Sin suficiente histórico de récords para predecir (se necesitan al menos 3).',
            ),
        ],
      ),
    );
  }
}
