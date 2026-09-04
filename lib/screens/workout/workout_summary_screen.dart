import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../models/workout.dart';
import '../../providers/weight_unit_provider.dart';
import '../../repositories/personal_records_service.dart';
import '../../repositories/workout_repository.dart';
import '../../widgets/muscle_silhouette.dart';
import '../../widgets/stat_tile.dart';

class _MuscleComparison {
  final double currentKg;
  final double previousKg;

  _MuscleComparison({required this.currentKg, required this.previousKg});

  double get deltaKg => currentKg - previousKg;
  double? get deltaPct => previousKg > 0 ? (deltaKg / previousKg) * 100 : null;
}

/// Resumen mostrado al finalizar un entrenamiento (ver `ActiveWorkoutScreen`
/// `_finish()`). Todo lo que es "esta sesión" se calcula en memoria sobre
/// `session.sets`, que ya viene completo -- solo la comparación con la sesión
/// anterior de cada músculo pide datos extra, vía `WorkoutRepository`
/// (métodos ya existentes, sin queries nuevas).
class WorkoutSummaryScreen extends StatefulWidget {
  final WorkoutSession session;
  final List<ResolvedRecord> records;

  const WorkoutSummaryScreen({
    super.key,
    required this.session,
    required this.records,
  });

  @override
  State<WorkoutSummaryScreen> createState() => _WorkoutSummaryScreenState();
}

class _WorkoutSummaryScreenState extends State<WorkoutSummaryScreen> {
  Map<String, _MuscleComparison>? _comparisons;

  Map<String, double> _volumeByMuscle(List<WorkoutSet> sets) {
    final result = <String, double>{};
    for (final s in sets) {
      if (s.isWarmup) continue;
      result[s.exercise.muscleGroup] =
          (result[s.exercise.muscleGroup] ?? 0) + s.weightKg * s.reps;
    }
    return result;
  }

  @override
  void initState() {
    super.initState();
    _loadComparisons();
  }

  Future<void> _loadComparisons() async {
    final repository = context.read<WorkoutRepository>();
    final currentByMuscle = _volumeByMuscle(widget.session.sets);
    // T3: antes, una llamada a `history(muscleGroup:)` (sesiones+sets+
    // catálogo completos) MÁS un `get()` por cada músculo entrenado. Ahora
    // una sola query de comparación para todos los músculos a la vez.
    final previousByMuscle = await repository.previousVolumeByMuscle(
      muscleGroups: currentByMuscle.keys.toSet(),
      excludeSessionId: widget.session.id,
    );
    final result = <String, _MuscleComparison>{
      for (final entry in currentByMuscle.entries)
        if (previousByMuscle.containsKey(entry.key))
          entry.key: _MuscleComparison(
            currentKg: entry.value,
            previousKg: previousByMuscle[entry.key]!,
          ),
    };
    if (mounted) setState(() => _comparisons = result);
  }

  @override
  Widget build(BuildContext context) {
    final weightUnit = context.watch<WeightUnitProvider>().unit;
    final session = widget.session;
    final sets = session.sets;
    final duration = session.endedAt != null
        ? session.endedAt!.difference(session.startedAt)
        : null;
    final exerciseCount = sets.map((s) => s.exercise.id).toSet().length;
    final setCount = sets.length;
    final totalReps = sets.fold<int>(0, (sum, s) => sum + s.reps);
    final totalVolumeKg = sets
        .where((s) => !s.isWarmup)
        .fold(0.0, (sum, s) => sum + s.weightKg * s.reps);
    final maxWeightKg = sets.fold(
      0.0,
      (max, s) => s.weightKg > max ? s.weightKg : max,
    );
    final volumeByMuscle = _volumeByMuscle(sets);
    final timeFormat = DateFormat('HH:mm');

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Resumen del entrenamiento')),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Container(
            padding: const EdgeInsets.all(AppSpacing.lg),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              boxShadow: AppGlow.secondary,
            ),
            child: Column(
              children: [
                const Icon(
                  Icons.check_circle,
                  color: AppColors.secondary,
                  size: 40,
                ),
                const SizedBox(height: AppSpacing.sm),
                Text(
                  'Entrenamiento completado',
                  style: Theme.of(
                    context,
                  ).textTheme.titleLarge?.copyWith(fontWeight: FontWeight.bold),
                ),
                const SizedBox(height: 4),
                Text(
                  formatWorkoutDuration(duration),
                  style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.w800,
                  ),
                ),
                Text(
                  '${timeFormat.format(session.startedAt.toLocal())} - '
                  '${session.endedAt != null ? timeFormat.format(session.endedAt!.toLocal()) : '—'}',
                  style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          // A5: `childAspectRatio` hacía depender el ALTO de la tarjeta del
          // ancho disponible -- en pantalla ancha (tablet, horizontal, el
          // harness) cada tile terminaba con un tercio de la pantalla de
          // alto para mostrar un ícono y dos líneas de texto. `mainAxisExtent`
          // fija el alto al que el contenido realmente necesita, sin importar
          // el ancho. Y como "nunca que las tarjetas se estiren" también
          // corta el ANCHO: se centra con un máximo en vez de ocupar todo el
          // ancho sobrante.
          Center(
            child: ConstrainedBox(
              constraints: const BoxConstraints(maxWidth: 560),
              child: GridView(
                shrinkWrap: true,
                physics: const NeverScrollableScrollPhysics(),
                gridDelegate: const SliverGridDelegateWithFixedCrossAxisCount(
                  crossAxisCount: 2,
                  mainAxisSpacing: AppSpacing.sm,
                  crossAxisSpacing: AppSpacing.sm,
                  mainAxisExtent: 72,
                ),
                children: [
                  StatTile(
                    icon: Icons.fitness_center,
                    color: AppColors.primary,
                    label: 'Ejercicios',
                    value: '$exerciseCount',
                  ),
                  StatTile(
                    icon: Icons.format_list_numbered,
                    color: AppColors.tertiary,
                    label: 'Series',
                    value: '$setCount',
                  ),
                  StatTile(
                    icon: Icons.repeat,
                    color: AppColors.warning,
                    label: 'Repeticiones',
                    value: '$totalReps',
                  ),
                  StatTile(
                    icon: Icons.bar_chart,
                    color: AppColors.secondary,
                    label: 'Volumen total',
                    value: formatWeight(totalVolumeKg, weightUnit, decimals: 0),
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          StatTile(
            icon: Icons.emoji_events_outlined,
            color: AppColors.primary,
            label: 'Peso máximo utilizado',
            value: formatWeight(maxWeightKg, weightUnit),
            fullWidth: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Músculos entrenados',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.md),
          MuscleSilhouette(volumeByMuscle: volumeByMuscle),
          const SizedBox(height: AppSpacing.lg),
          Text('Tu progreso', style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          if (_comparisons == null)
            const Padding(
              padding: EdgeInsets.symmetric(vertical: AppSpacing.md),
              child: Center(child: CircularProgressIndicator()),
            )
          else if (_comparisons!.isEmpty)
            Text(
              'Sin sesiones anteriores de estos músculos todavía para comparar.',
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            )
          else
            for (final entry in _comparisons!.entries)
              _ComparisonTile(
                muscleGroup: entry.key,
                comparison: entry.value,
                weightUnit: weightUnit,
              ),
          if (widget.records.isNotEmpty) ...[
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Mejores marcas',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.sm),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.secondaryContainer.withValues(alpha: 0.1),
                borderRadius: BorderRadius.circular(AppRadius.lg),
                border: Border.all(
                  color: AppColors.secondaryContainer.withValues(alpha: 0.3),
                ),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  for (final r in widget.records)
                    Padding(
                      padding: const EdgeInsets.only(bottom: 4),
                      child: Row(
                        children: [
                          const Icon(
                            Icons.emoji_events,
                            size: 18,
                            color: AppColors.secondary,
                          ),
                          const SizedBox(width: AppSpacing.sm),
                          Expanded(
                            child: Text(
                              '${recordTypeLabels[r.recordType] ?? r.recordType}: '
                              '${r.value}'
                              '${r.previousValue != null ? ' (antes: ${r.previousValue})' : ''}',
                              style: Theme.of(context).textTheme.bodyMedium,
                            ),
                          ),
                        ],
                      ),
                    ),
                ],
              ),
            ),
          ],
          const SizedBox(height: AppSpacing.xl),
          FilledButton(
            onPressed: () => Navigator.of(context).popUntil((r) => r.isFirst),
            child: const Text('Listo'),
          ),
        ],
      ),
    );
  }
}

class _ComparisonTile extends StatelessWidget {
  final String muscleGroup;
  final _MuscleComparison comparison;
  final WeightUnit weightUnit;

  const _ComparisonTile({
    required this.muscleGroup,
    required this.comparison,
    required this.weightUnit,
  });

  @override
  Widget build(BuildContext context) {
    final improved = comparison.deltaKg >= 0;
    final color = improved ? AppColors.secondary : AppColors.danger;
    final pct = comparison.deltaPct;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.sm),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Row(
        children: [
          Container(
            width: 10,
            height: 10,
            decoration: BoxDecoration(
              shape: BoxShape.circle,
              color: muscleGroupColors[muscleGroup] ?? Colors.grey,
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(muscleGroup, style: Theme.of(context).textTheme.bodyLarge),
                Text(
                  'Esta sesión: ${formatWeight(comparison.currentKg, weightUnit, decimals: 0)} · '
                  'Anterior: ${formatWeight(comparison.previousKg, weightUnit, decimals: 0)}',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Row(
                children: [
                  Icon(
                    improved ? Icons.arrow_upward : Icons.arrow_downward,
                    size: 14,
                    color: color,
                  ),
                  Text(
                    formatWeight(
                      comparison.deltaKg.abs(),
                      weightUnit,
                      decimals: 0,
                    ),
                    style: Theme.of(context).textTheme.labelLarge?.copyWith(
                      color: color,
                      fontWeight: FontWeight.bold,
                    ),
                  ),
                ],
              ),
              if (pct != null)
                Text(
                  '${pct >= 0 ? '+' : ''}${pct.toStringAsFixed(0)}%',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
            ],
          ),
        ],
      ),
    );
  }
}
