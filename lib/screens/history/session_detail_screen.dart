import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/workout.dart';
import '../../services/workout_service.dart';

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  WorkoutSession? _session;
  List<PersonalRecord> _records = [];
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    final service = WorkoutService(context.read<ApiClient>());
    Future.wait([
      service.get(widget.sessionId),
      service.sessionRecords(widget.sessionId),
    ]).then((results) {
      setState(() {
        _session = results[0] as WorkoutSession;
        _records = results[1] as List<PersonalRecord>;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final session = _session!;
    final grouped = <int, List<WorkoutSet>>{};
    final exerciseNames = <int, String>{};
    final exerciseGroups = <int, String>{};
    for (final set in session.sets) {
      grouped.putIfAbsent(set.exercise.id, () => []).add(set);
      exerciseNames[set.exercise.id] = set.exercise.name;
      exerciseGroups[set.exercise.id] = set.exercise.muscleGroup;
    }

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_dateFormat.format(session.startedAt.toLocal())),
      ),
      body: ListView(
        padding: const EdgeInsets.all(AppSpacing.md),
        children: [
          if (_records.isNotEmpty) ...[
            _RecordsCard(records: _records),
            const SizedBox(height: AppSpacing.md),
          ],
          if (session.notes != null && session.notes!.isNotEmpty) ...[
            Text('Notas', style: Theme.of(context).textTheme.titleLarge),
            const SizedBox(height: AppSpacing.sm),
            Text(
              session.notes!,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.lg),
          ],
          for (final entry in grouped.entries)
            _ExerciseSetsCard(
              exerciseName: exerciseNames[entry.key]!,
              muscleGroup: exerciseGroups[entry.key]!,
              sets: entry.value,
            ),
        ],
      ),
    );
  }
}

class _RecordsCard extends StatelessWidget {
  final List<PersonalRecord> records;

  const _RecordsCard({required this.records});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.secondaryContainer.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              size: 20,
              color: AppColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Récords logrados',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.secondary),
                ),
                const SizedBox(height: 4),
                for (final r in records)
                  Text(
                    '${recordTypeLabels[r.recordType] ?? r.recordType}: ${r.value}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
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

class _ExerciseSetsCard extends StatelessWidget {
  final String exerciseName;
  final String muscleGroup;
  final List<WorkoutSet> sets;

  const _ExerciseSetsCard({
    required this.exerciseName,
    required this.muscleGroup,
    required this.sets,
  });

  @override
  Widget build(BuildContext context) {
    final color = muscleGroupColors[muscleGroup] ?? Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 40,
                  height: 40,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.fitness_center, color: color, size: 20),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exerciseName,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        muscleGroup,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          for (final set in sets)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: Row(
                children: [
                  Container(
                    width: 26,
                    height: 26,
                    alignment: Alignment.center,
                    decoration: BoxDecoration(
                      color: set.isWarmup
                          ? Colors.transparent
                          : AppColors.secondaryContainer,
                      shape: BoxShape.circle,
                      border: set.isWarmup
                          ? Border.all(color: AppColors.outline)
                          : null,
                    ),
                    child: Text(
                      '${set.setNumber}',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: set.isWarmup
                            ? AppColors.outline
                            : AppColors.onSecondaryContainer,
                      ),
                    ),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Text(
                      '${set.weightKg} kg × ${set.reps} reps${set.isWarmup ? ' (calentamiento)' : ''}',
                      style: Theme.of(context).textTheme.bodyMedium,
                    ),
                  ),
                  if (set.rpe != null || set.rir != null)
                    Text(
                      [
                        if (set.rpe != null) 'RPE ${set.rpe}',
                        if (set.rir != null) 'RIR ${set.rir}',
                      ].join(' · '),
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                ],
              ),
            ),
          const SizedBox(height: AppSpacing.sm),
        ],
      ),
    );
  }
}
