import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/routine.dart';
import '../../models/user.dart';
import '../../repositories/routine_repository.dart';
import '../../repositories/workout_repository.dart';
import '../workout/active_workout_screen.dart';

class RoutineDetailScreen extends StatefulWidget {
  final int routineId;

  const RoutineDetailScreen({super.key, required this.routineId});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  late final RoutineRepository _repository;
  Routine? _routine;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<RoutineRepository>();
    _load();
  }

  Future<void> _load() async {
    try {
      final routine = await _repository.get(widget.routineId);
      setState(() => _routine = routine);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _delete() async {
    await _repository.delete(widget.routineId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        backgroundColor: AppColors.background,
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    if (_routine == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final routine = _routine!;

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(routine.name),
        actions: [
          IconButton(
            icon: const Icon(Icons.delete_outline),
            onPressed: () async {
              final confirm = await showDialog<bool>(
                context: context,
                builder: (context) => AlertDialog(
                  title: const Text('Eliminar rutina'),
                  content: const Text(
                    '¿Seguro que querés eliminar esta rutina?',
                  ),
                  actions: [
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(false),
                      child: const Text('Cancelar'),
                    ),
                    TextButton(
                      onPressed: () => Navigator.of(context).pop(true),
                      child: const Text('Eliminar'),
                    ),
                  ],
                ),
              );
              if (confirm == true) _delete();
            },
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final session = await context.read<WorkoutRepository>().startSession(
            routineId: routine.id,
          );
          if (!context.mounted) return;
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ActiveWorkoutScreen(sessionId: session.id),
            ),
          );
        },
        icon: const Icon(Icons.play_arrow),
        label: const Text('Iniciar con esta rutina'),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          96,
        ),
        children: [
          if (routine.goal != null)
            Padding(
              padding: const EdgeInsets.only(bottom: AppSpacing.md),
              child: Text(
                (goalOptions[routine.goal!] ?? routine.goal!).toUpperCase(),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.secondary,
                  letterSpacing: 1,
                ),
              ),
            ),
          for (final day in routine.days) _DayCard(day: day),
        ],
      ),
    );
  }
}

class _DayCard extends StatelessWidget {
  final RoutineDay day;

  const _DayCard({required this.day});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(day.name, style: Theme.of(context).textTheme.titleLarge),
              if (day.muscleFocus != null) ...[
                const SizedBox(height: 2),
                Text(
                  day.muscleFocus!,
                  style: Theme.of(context).textTheme.bodySmall?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
              ],
              const SizedBox(height: AppSpacing.sm),
              Container(
                decoration: const BoxDecoration(
                  border: Border(
                    top: BorderSide(color: AppColors.outlineVariant),
                  ),
                ),
                padding: const EdgeInsets.only(top: AppSpacing.sm),
                child: Column(
                  children: [
                    for (final ex in day.exercises) _ExerciseRow(exercise: ex),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final RoutineExercise exercise;

  const _ExerciseRow({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final color =
        muscleGroupColors[exercise.exercise.muscleGroup] ?? Colors.grey;
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: AppSpacing.xs),
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
          const SizedBox(width: AppSpacing.sm),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  exercise.exercise.name,
                  style: Theme.of(
                    context,
                  ).textTheme.bodyLarge?.copyWith(fontWeight: FontWeight.w600),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                Text(
                  '${exercise.targetSets}x${exercise.targetRepsMin}-${exercise.targetRepsMax} '
                  '· descanso ${exercise.targetRestSeconds}s',
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
