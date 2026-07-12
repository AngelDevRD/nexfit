import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/calendar.dart';
import '../../repositories/goal_repository.dart';
import '../../repositories/stats_repository.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarOverview? _overview;
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

    final goals = await goalRepository.list();
    final upcomingGoals = goals.where((g) => g.achievedAt == null).toList()
      ..sort((a, b) {
        if (a.targetDate == null && b.targetDate == null) return 0;
        if (a.targetDate == null) return 1;
        if (b.targetDate == null) return -1;
        return a.targetDate!.compareTo(b.targetDate!);
      });

    final overview = CalendarOverview(
      upcomingGoals: upcomingGoals,
      deload: await statsRepository.deloadRecommendation(),
      upcomingRecordPredictions: await statsRepository
          .upcomingRecordPredictions(),
    );

    setState(() {
      _overview = overview;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(title: const Text('Calendario inteligente')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final overview = _overview!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Calendario inteligente')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
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
            Text(
              'Objetivos próximos',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            if (overview.upcomingGoals.isEmpty)
              Text(
                'Sin objetivos pendientes.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            for (final goal in overview.upcomingGoals)
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
            Text(
              'Predicción de próximos récords',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            if (overview.upcomingRecordPredictions.isEmpty)
              Text(
                'Sin suficiente histórico todavía.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            for (final prediction in overview.upcomingRecordPredictions)
              _InfoCard(
                icon: Icons.emoji_events,
                iconColor: AppColors.secondary,
                title: prediction.exerciseName,
                subtitle: 'Actual: ${prediction.currentBestKg} kg',
                trailing:
                    '${prediction.predictedKg} kg en ${prediction.weeksAhead} sem.',
              ),
          ],
        ),
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
