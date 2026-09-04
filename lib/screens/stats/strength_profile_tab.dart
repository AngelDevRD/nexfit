import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../models/stats.dart';
import '../../providers/weight_unit_provider.dart';
import '../../repositories/stats_repository.dart';
import '../../widgets/empty_state.dart';

class StrengthProfileTab extends StatefulWidget {
  const StrengthProfileTab({super.key});

  @override
  State<StrengthProfileTab> createState() => _StrengthProfileTabState();
}

class _StrengthProfileTabState extends State<StrengthProfileTab> {
  StrengthProfile? _profile;
  TrainingStreak? _streak;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    final repo = context.read<StatsRepository>();
    try {
      final results = await Future.wait([
        repo.strengthProfile(),
        repo.streak(),
      ]);
      setState(() {
        _profile = results[0] as StrengthProfile;
        _streak = results[1] as TrainingStreak;
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
    if (_loading) return const Center(child: CircularProgressIndicator());
    if (_error != null) {
      return Center(child: EmptyState.error(message: _error!, onRetry: _load));
    }
    final profile = _profile!;
    final streak = _streak!;
    final weightUnit = context.watch<WeightUnitProvider>().unit;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.local_fire_department,
                  iconColor: AppColors.secondary,
                  label: 'Racha actual',
                  value: '${streak.currentStreakDays} días',
                ),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: _MiniStat(
                  icon: Icons.emoji_events_outlined,
                  iconColor: AppColors.primary,
                  label: 'Mejor racha',
                  value: '${streak.longestStreakDays} días',
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          _MiniStat(
            icon: Icons.trending_up,
            iconColor: AppColors.tertiary,
            label: 'Volumen semanal',
            value: formatWeight(profile.weeklyVolumeKg, weightUnit, decimals: 0),
            fullWidth: true,
          ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Fuerza máxima por ejercicio',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (profile.maxStrengthByExercise.isEmpty)
            const EmptyState(
              icon: Icons.fitness_center,
              message: 'Todavía no registraste series no-calentamiento.',
            ),
          for (final entry in profile.maxStrengthByExercise)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.sm),
              child: Material(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.lg),
                child: Padding(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  child: Row(
                    children: [
                      Expanded(
                        child: Text(
                          entry.exerciseName,
                          style: Theme.of(context).textTheme.bodyLarge,
                        ),
                      ),
                      Text(
                        formatWeight(entry.maxWeightKg, weightUnit),
                        style: Theme.of(context).textTheme.titleMedium
                            ?.copyWith(color: AppColors.primary),
                      ),
                    ],
                  ),
                ),
              ),
            ),
          const SizedBox(height: AppSpacing.lg),
          Text(
            'Frecuencia semanal por músculo',
            style: Theme.of(context).textTheme.titleLarge,
          ),
          const SizedBox(height: AppSpacing.sm),
          if (profile.weeklyFrequencyByMuscle.isEmpty)
            const EmptyState(
              icon: Icons.calendar_today_outlined,
              message: 'Sin entrenamientos esta semana.',
            ),
          for (final entry in profile.weeklyFrequencyByMuscle)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.xs),
              child: Row(
                children: [
                  Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                      color:
                          muscleGroupColors[entry.muscleGroup] ?? Colors.grey,
                      shape: BoxShape.circle,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: Text(
                      entry.muscleGroup,
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  Text(
                    '${entry.sessions} sesiones',
                    style: Theme.of(context).textTheme.labelMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
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

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String label;
  final String value;
  final bool fullWidth;

  const _MiniStat({
    required this.icon,
    required this.iconColor,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      child: Row(
        children: [
          Container(
            width: 40,
            height: 40,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: iconColor, size: 20),
          ),
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleMedium),
                Text(
                  label,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}
