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
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Text(
            'Volumen de los últimos 30 días, comparado con tu propio historial.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: AppSpacing.md),
          for (final entry in _entries)
            _MuscleVolumeCard(entry: entry, maxVolume: maxVolume),
        ],
      ),
    );
  }
}

class _MuscleVolumeCard extends StatelessWidget {
  final MuscleVolumeEntry entry;
  final double maxVolume;

  const _MuscleVolumeCard({required this.entry, required this.maxVolume});

  @override
  Widget build(BuildContext context) {
    final groupColor = muscleGroupColors[entry.muscleGroup] ?? Colors.grey;
    final levelColor = colorForLevel(entry.level);
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            children: [
              Container(
                width: 12,
                height: 12,
                decoration: BoxDecoration(
                  color: groupColor,
                  shape: BoxShape.circle,
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Text(
                  entry.muscleGroup,
                  style: Theme.of(context).textTheme.titleSmall,
                ),
              ),
              Text(
                '${entry.totalSets} series · ${entry.totalVolume.toStringAsFixed(0)} kg',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: maxVolume > 0 ? entry.totalVolume / maxVolume : 0,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHighest,
              color: levelColor,
            ),
          ),
        ],
      ),
    );
  }
}
