import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../models/exercise.dart';
import '../../models/stats.dart';
import '../../providers/weight_unit_provider.dart';
import '../../repositories/stats_repository.dart';
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
    final repo = context.read<StatsRepository>();
    try {
      final results = await Future.wait([
        repo.strengthStandards(exercise.id),
        repo.recordPrediction(exercise.id),
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
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          Material(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.md),
            child: InkWell(
              borderRadius: BorderRadius.circular(AppRadius.md),
              onTap: _pickExercise,
              child: Padding(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.md,
                  vertical: AppSpacing.sm,
                ),
                child: Row(
                  children: [
                    const Icon(Icons.search, color: AppColors.primary),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Text(
                        _selected?.name ??
                            'Elegir ejercicio (press banca, sentadilla o peso muerto)',
                        style: Theme.of(context).textTheme.bodyLarge,
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
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
            Text(
              'Sin datos suficientes: completá tu perfil (peso, sexo) y registrá un récord en este ejercicio.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          if (_standard != null) ...[
            _StandardCard(standard: _standard!),
            const SizedBox(height: AppSpacing.md),
          ],
          if (_prediction != null)
            _PredictionCard(prediction: _prediction!)
          else if (!_loading && _selected != null && _error == null)
            Text(
              'Sin suficiente histórico de récords para predecir (se necesitan al menos 3).',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
        ],
      ),
    );
  }
}

class _StandardCard extends StatelessWidget {
  final StrengthStandard standard;

  const _StandardCard({required this.standard});

  @override
  Widget build(BuildContext context) {
    final levelColor = colorForLevel(standard.level);
    final weightUnit = context.watch<WeightUnitProvider>().unit;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border(left: BorderSide(color: levelColor, width: 4)),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            standard.exerciseName,
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            '${formatWeight(standard.liftKg, weightUnit)} '
            '(${standard.ratio}x tu peso corporal)',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              Container(
                padding: const EdgeInsets.symmetric(
                  horizontal: AppSpacing.sm,
                  vertical: 4,
                ),
                decoration: BoxDecoration(
                  color: levelColor.withValues(alpha: 0.15),
                  borderRadius: BorderRadius.circular(AppRadius.full),
                ),
                child: Text(
                  strengthLevelLabels[standard.level] ?? standard.level,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: levelColor,
                    fontWeight: FontWeight.w600,
                  ),
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Percentil ${standard.percentile.toStringAsFixed(0)}',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Referencia aproximada, no basada en un dataset poblacional verificado.',
            style: Theme.of(
              context,
            ).textTheme.bodySmall?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _PredictionCard extends StatelessWidget {
  final RecordPrediction prediction;

  const _PredictionCard({required this.prediction});

  @override
  Widget build(BuildContext context) {
    final weightUnit = context.watch<WeightUnitProvider>().unit;
    return Container(
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
              const Icon(Icons.trending_up, color: AppColors.secondary),
              const SizedBox(width: AppSpacing.sm),
              Text(
                'Predicción de récord',
                style: Theme.of(context).textTheme.titleLarge,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            'Si mantenés este ritmo, probablemente levantarás '
            '${formatWeight(prediction.predictedKg, weightUnit)} '
            'dentro de ${prediction.weeksAhead} semanas '
            '(actual: ${formatWeight(prediction.currentBestKg, weightUnit)}).',
            style: Theme.of(context).textTheme.bodyMedium,
          ),
        ],
      ),
    );
  }
}
