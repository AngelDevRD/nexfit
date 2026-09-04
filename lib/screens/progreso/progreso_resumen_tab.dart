import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../models/calendar.dart';
import '../../models/gamification.dart';
import '../../models/stats.dart';
import '../../providers/weight_unit_provider.dart';
import '../../repositories/gamification_repository.dart';
import '../../repositories/goal_repository.dart';
import '../../repositories/stats_repository.dart';

/// Tab "Resumen" del hub Progreso: junta en una sola vista lo que antes
/// vivía separado en `CalendarScreen` (deload + objetivos próximos +
/// predicción de récord) y el resumen de nivel/XP/racha de
/// `GamificationScreen` -- misma lógica y mismos repositorios, sin
/// duplicar queries (ver plan de reorganización de navegación).
class ProgresoResumenTab extends StatefulWidget {
  const ProgresoResumenTab({super.key});

  @override
  State<ProgresoResumenTab> createState() => _ProgresoResumenTabState();
}

class _ProgresoResumenTabState extends State<ProgresoResumenTab> {
  CalendarOverview? _overview;
  GamificationProfile? _gamification;
  bool _loading = true;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final goalRepository = context.read<GoalRepository>();
    final statsRepository = context.read<StatsRepository>();
    final gamificationRepository = context.read<GamificationRepository>();

    final goals = await goalRepository.list();
    final upcomingGoals = goals.where((g) => g.achievedAt == null).toList()
      ..sort((a, b) {
        if (a.targetDate == null && b.targetDate == null) return 0;
        if (a.targetDate == null) return 1;
        if (b.targetDate == null) return -1;
        return a.targetDate!.compareTo(b.targetDate!);
      });

    final results = await Future.wait([
      statsRepository.deloadRecommendation(),
      statsRepository.upcomingRecordPredictions(),
      gamificationRepository.profile(),
    ]);

    if (!mounted) return;
    setState(() {
      _overview = CalendarOverview(
        upcomingGoals: upcomingGoals,
        deload: results[0] as DeloadRecommendation,
        upcomingRecordPredictions: results[1] as List<RecordPrediction>,
      );
      _gamification = results[2] as GamificationProfile;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading || _overview == null || _gamification == null) {
      return const Center(child: CircularProgressIndicator());
    }
    final overview = _overview!;
    final gamification = _gamification!;
    final weightUnit = context.watch<WeightUnitProvider>().unit;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          _LevelStreakCard(profile: gamification),
          const SizedBox(height: AppSpacing.lg),
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
              border: Border(
                left: BorderSide(
                  color: overview.deload.recommended
                      ? AppColors.warning
                      : AppColors.secondary,
                  width: 4,
                ),
              ),
            ),
            child: Row(
              children: [
                Icon(
                  overview.deload.recommended
                      ? Icons.warning_amber
                      : Icons.check_circle_outline,
                  color: overview.deload.recommended
                      ? AppColors.warning
                      : AppColors.secondary,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: Text(
                    overview.deload.reason,
                    style: Theme.of(context).textTheme.bodyMedium,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Objetivos próximos',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => DefaultTabController.of(context).animateTo(2),
                child: const Text('Ver todos'),
              ),
            ],
          ),
          if (overview.upcomingGoals.isEmpty)
            Text(
              'Sin objetivos pendientes.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            ),
          for (final goal in overview.upcomingGoals.take(3))
            _InfoCard(
              icon: Icons.flag,
              iconColor: AppColors.primary,
              title: goal.title,
              subtitle: goal.targetDate != null
                  ? 'Fecha objetivo: ${_dateFormat.format(goal.targetDate!)}'
                  : 'Sin fecha límite',
              trailing: '${goal.progressPct.toStringAsFixed(0)}%',
            ),
          const SizedBox(height: AppSpacing.lg),
          Row(
            children: [
              Expanded(
                child: Text(
                  'Predicción de próximo récord',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              TextButton(
                onPressed: () => DefaultTabController.of(context).animateTo(1),
                child: const Text('Ver estándares'),
              ),
            ],
          ),
          if (overview.upcomingRecordPredictions.isEmpty)
            Text(
              'Sin suficiente histórico todavía.',
              style: Theme.of(
                context,
              ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
            )
          else
            _InfoCard(
              icon: Icons.emoji_events,
              iconColor: AppColors.secondary,
              title: overview.upcomingRecordPredictions.first.exerciseName,
              subtitle: 'Actual: ${formatWeight(
                overview.upcomingRecordPredictions.first.currentBestKg,
                weightUnit,
              )}',
              trailing:
                  '${formatWeight(overview.upcomingRecordPredictions.first.predictedKg, weightUnit)} '
                  'en ${overview.upcomingRecordPredictions.first.weeksAhead} sem.',
            ),
        ],
      ),
    );
  }
}

class _LevelStreakCard extends StatelessWidget {
  const _LevelStreakCard({required this.profile});

  final GamificationProfile profile;

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(color: AppColors.primaryContainer.withValues(alpha: 0.4)),
        boxShadow: AppGlow.primary,
      ),
      child: Row(
        children: [
          Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                'NIVEL ${profile.level}',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              Text(
                '${profile.totalXp.toStringAsFixed(0)} XP',
                style: Theme.of(context).textTheme.headlineSmall?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: AppColors.primary,
                ),
              ),
            ],
          ),
          const Spacer(),
          Icon(Icons.local_fire_department, color: AppColors.secondary, size: 32),
          const SizedBox(width: AppSpacing.xs),
          Column(
            crossAxisAlignment: CrossAxisAlignment.end,
            children: [
              Text(
                '${profile.longestStreakDays} días',
                style: Theme.of(context).textTheme.titleMedium,
              ),
              Text(
                'mejor racha',
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

class _InfoCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final String trailing;

  const _InfoCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.trailing,
  });

  @override
  Widget build(BuildContext context) {
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
            width: 44,
            height: 44,
            decoration: BoxDecoration(
              color: iconColor.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.md),
            ),
            child: Icon(icon, color: iconColor),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  title,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: 2),
                Text(
                  subtitle,
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
            ),
          ),
          const SizedBox(width: AppSpacing.sm),
          Text(
            trailing,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
        ],
      ),
    );
  }
}
