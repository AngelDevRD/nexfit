import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/stats.dart';
import '../../services/stats_service.dart';

class MuscleAnalysisTab extends StatefulWidget {
  const MuscleAnalysisTab({super.key});

  @override
  State<MuscleAnalysisTab> createState() => _MuscleAnalysisTabState();
}

class _MuscleAnalysisTabState extends State<MuscleAnalysisTab> {
  List<MuscleVolumeEntry> _entries = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final entries = await StatsService(
      context.read<ApiClient>(),
    ).muscleAnalysis();
    setState(() {
      _entries = entries;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final maxVolume = _entries.fold<double>(
      0,
      (max, e) => e.totalVolume > max ? e.totalVolume : max,
    );

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Text(
            'Volumen de los últimos 30 días, comparado con tu propio historial.',
            style: Theme.of(context).textTheme.bodySmall,
          ),
          const SizedBox(height: 16),
          for (final entry in _entries)
            Padding(
              padding: const EdgeInsets.only(bottom: 14),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Container(
                        width: 12,
                        height: 12,
                        decoration: BoxDecoration(
                          color: colorForLevel(entry.level),
                          shape: BoxShape.circle,
                        ),
                      ),
                      const SizedBox(width: 8),
                      Text(
                        entry.muscleGroup,
                        style: Theme.of(context).textTheme.titleSmall,
                      ),
                      const Spacer(),
                      Text(
                        '${entry.totalSets} series · ${entry.totalVolume.toStringAsFixed(0)} kg',
                      ),
                    ],
                  ),
                  const SizedBox(height: 6),
                  ClipRRect(
                    borderRadius: BorderRadius.circular(8),
                    child: LinearProgressIndicator(
                      value: maxVolume > 0 ? entry.totalVolume / maxVolume : 0,
                      minHeight: 8,
                      backgroundColor: Theme.of(
                        context,
                      ).colorScheme.surfaceContainerHighest,
                      color: colorForLevel(entry.level),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}
