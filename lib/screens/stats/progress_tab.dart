import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/exercise.dart';
import '../../models/stats.dart';
import '../../services/stats_service.dart';
import '../exercises/exercise_picker_screen.dart';

class ProgressTab extends StatefulWidget {
  const ProgressTab({super.key});

  @override
  State<ProgressTab> createState() => _ProgressTabState();
}

class _ProgressTabState extends State<ProgressTab> {
  ExerciseSummary? _selected;
  List<ExerciseProgressEntry> _entries = [];
  bool _loading = false;

  Future<void> _pickExercise() async {
    final exercise = await Navigator.of(context).push<ExerciseSummary>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise == null || !mounted) return;
    setState(() {
      _selected = exercise;
      _loading = true;
    });
    final entries = await StatsService(
      context.read<ApiClient>(),
    ).exerciseProgress(exercise.id);
    if (!mounted) return;
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.all(16),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          OutlinedButton.icon(
            onPressed: _pickExercise,
            icon: const Icon(Icons.search),
            label: Text(_selected?.name ?? 'Elegir ejercicio'),
          ),
          const SizedBox(height: 20),
          if (_loading) const Center(child: CircularProgressIndicator()),
          if (!_loading && _selected != null && _entries.isEmpty)
            const Text(
              'Sin entrenamientos registrados para este ejercicio todavía.',
            ),
          if (!_loading && _entries.isNotEmpty)
            Expanded(
              child: LineChart(
                LineChartData(
                  titlesData: FlTitlesData(
                    rightTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: const AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(
                        showTitles: true,
                        getTitlesWidget: (value, meta) {
                          final index = value.toInt();
                          if (index < 0 || index >= _entries.length) {
                            return const SizedBox.shrink();
                          }
                          final date = _entries[index].date;
                          return Padding(
                            padding: const EdgeInsets.only(top: 8),
                            child: Text(
                              '${date.day}/${date.month}',
                              style: const TextStyle(fontSize: 10),
                            ),
                          );
                        },
                      ),
                    ),
                  ),
                  gridData: const FlGridData(show: true),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: _entries
                          .asMap()
                          .entries
                          .map(
                            (e) =>
                                FlSpot(e.key.toDouble(), e.value.maxWeightKg),
                          )
                          .toList(),
                      isCurved: true,
                      color: Theme.of(context).colorScheme.primary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                    ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
