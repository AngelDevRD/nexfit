import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../models/goal.dart';
import '../../repositories/goal_repository.dart';
import '../../widgets/empty_state.dart';
import '../exercises/exercise_picker_screen.dart';

/// N5: siempre vive dentro de [ProgresoHubScreen]. El hub provee
/// Scaffold/AppBar/fondo; acá solo queda un `Scaffold` transparente para
/// poder posicionar el FAB "+" -- el único patrón que sigue necesitando un
/// `Scaffold` propio (ver N5 en la auditoría), nunca con AppBar.
class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late final GoalRepository _repository;
  List<Goal> _goals = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _repository = context.read<GoalRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final goals = await _repository.list();
      setState(() {
        _goals = goals;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openCreateDialog() async {
    final created = await showDialog<bool>(
      context: context,
      builder: (_) => const _CreateGoalDialog(),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final fab = FloatingActionButton(
      backgroundColor: AppColors.primaryContainer,
      foregroundColor: AppColors.onPrimaryContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      onPressed: _openCreateDialog,
      child: const Icon(Icons.add),
    );
    final body = _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(
              child: EmptyState.error(message: _error!, onRetry: _load),
            )
          : RefreshIndicator(
              onRefresh: _load,
              child: _goals.isEmpty
                  ? ListView(
                      children: [
                        const SizedBox(height: 80),
                        EmptyState(
                          icon: Icons.flag_outlined,
                          message: 'Sin objetivos todavía.',
                          actionLabel: 'Crear objetivo',
                          onAction: _openCreateDialog,
                        ),
                      ],
                    )
                  : ListView(
                      padding: const EdgeInsets.fromLTRB(
                        AppSpacing.md,
                        AppSpacing.md,
                        AppSpacing.md,
                        96,
                      ),
                      children: [
                        _OverallProgressCard(goals: _goals),
                        const SizedBox(height: AppSpacing.lg),
                        Text(
                          'Tus objetivos',
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                        const SizedBox(height: AppSpacing.sm),
                        for (final goal in _goals)
                          _GoalCard(
                            goal: goal,
                            onDelete: () async {
                              await _repository.delete(goal.id);
                              _load();
                            },
                          ),
                      ],
                    ),
            );

    return Scaffold(
      backgroundColor: Colors.transparent,
      floatingActionButton: fab,
      body: body,
    );
  }
}

class _OverallProgressCard extends StatelessWidget {
  final List<Goal> goals;

  const _OverallProgressCard({required this.goals});

  @override
  Widget build(BuildContext context) {
    final overall = goals.isEmpty
        ? 0.0
        : goals.map((g) => g.progressPct).reduce((a, b) => a + b) / goals.length;
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
              Expanded(
                child: Text(
                  'Progreso general',
                  style: Theme.of(context).textTheme.titleLarge,
                ),
              ),
              Text(
                '${overall.toStringAsFixed(0)}% Completado',
                style: Theme.of(context).textTheme.labelLarge?.copyWith(
                  color: AppColors.secondary,
                  fontWeight: FontWeight.bold,
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.full),
            child: LinearProgressIndicator(
              value: overall / 100,
              minHeight: 10,
              backgroundColor: AppColors.surfaceContainerHighest,
              color: AppColors.secondary,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            goals.isEmpty
                ? 'Creá tu primer objetivo para empezar a medir tu progreso.'
                : 'Estás en camino de alcanzar tus metas. ¡Seguí así!',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

IconData _goalIcon(String metric) => switch (metric) {
  'exercise_max_weight' => Icons.fitness_center,
  'exercise_max_reps' => Icons.repeat,
  'body_weight_kg' => Icons.monitor_weight_outlined,
  'body_fat_pct' => Icons.water_drop_outlined,
  _ => Icons.flag,
};

class _GoalCard extends StatelessWidget {
  final Goal goal;
  final VoidCallback onDelete;

  const _GoalCard({required this.goal, required this.onDelete});

  @override
  Widget build(BuildContext context) {
    final accent = goal.achieved ? AppColors.secondary : AppColors.primary;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Container(
                width: 40,
                height: 40,
                alignment: Alignment.center,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(_goalIcon(goal.metric), color: AppColors.onSurfaceVariant),
              ),
              const SizedBox(width: AppSpacing.sm),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      goal.title,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Meta: ${goal.targetValue} (Actual: ${goal.currentValue})',
                      style: Theme.of(context).textTheme.bodySmall?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(
                  Icons.delete_outline,
                  color: AppColors.onSurfaceVariant,
                ),
                onPressed: onDelete,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.sm),
          Row(
            children: [
              if (goal.achieved) ...[
                const Icon(Icons.check_circle, size: 16, color: AppColors.secondary),
                const SizedBox(width: 4),
              ],
              Text(
                goal.achieved ? 'Completado' : 'En curso',
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: accent,
                  fontWeight: FontWeight.w600,
                ),
              ),
              const Spacer(),
              Text(
                '${goal.progressPct.toStringAsFixed(0)}%',
                style: Theme.of(context).textTheme.labelMedium,
              ),
            ],
          ),
          const SizedBox(height: 4),
          ClipRRect(
            borderRadius: BorderRadius.circular(AppRadius.sm),
            child: LinearProgressIndicator(
              value: goal.progressPct / 100,
              minHeight: 8,
              backgroundColor: AppColors.surfaceContainerHighest,
              color: accent,
            ),
          ),
        ],
      ),
    );
  }
}

class _CreateGoalDialog extends StatefulWidget {
  const _CreateGoalDialog();

  @override
  State<_CreateGoalDialog> createState() => _CreateGoalDialogState();
}

class _CreateGoalDialogState extends State<_CreateGoalDialog> {
  final _titleController = TextEditingController();
  final _targetController = TextEditingController();
  String _metric = 'body_weight_kg';
  ExerciseSummary? _exercise;
  bool _saving = false;
  String? _error;

  bool get _needsExercise =>
      _metric == 'exercise_max_weight' || _metric == 'exercise_max_reps';

  Future<void> _pickExercise() async {
    final exercise = await Navigator.of(context).push<ExerciseSummary>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise != null) setState(() => _exercise = exercise);
  }

  Future<void> _submit() async {
    final target = double.tryParse(_targetController.text);
    if (_titleController.text.trim().isEmpty || target == null) {
      setState(() => _error = 'Completá el título y el valor objetivo');
      return;
    }
    if (_needsExercise && _exercise == null) {
      setState(() => _error = 'Elegí un ejercicio');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    try {
      await context.read<GoalRepository>().create({
        'title': _titleController.text.trim(),
        'metric': _metric,
        if (_exercise != null) 'exercise_id': _exercise!.id,
        'target_value': target,
      });
      if (!mounted) return;
      Navigator.of(context).pop(true);
    } catch (e) {
      setState(() {
        _error = e.toString();
        _saving = false;
      });
    }
  }

  @override
  void dispose() {
    _titleController.dispose();
    _targetController.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      backgroundColor: AppColors.surfaceContainer,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      title: const Text('Nuevo objetivo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextFormField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: AppSpacing.sm),
          DropdownButtonFormField<String>(
            initialValue: _metric,
            decoration: const InputDecoration(labelText: 'Tipo de objetivo'),
            items: goalMetricLabels.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _metric = v ?? 'body_weight_kg'),
          ),
          if (_needsExercise) ...[
            const SizedBox(height: AppSpacing.sm),
            OutlinedButton(
              onPressed: _pickExercise,
              child: Text(_exercise?.name ?? 'Elegir ejercicio'),
            ),
          ],
          const SizedBox(height: AppSpacing.sm),
          TextFormField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor objetivo'),
          ),
          if (_error != null) ...[
            const SizedBox(height: AppSpacing.sm),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(false),
          child: const Text('Cancelar'),
        ),
        FilledButton(
          onPressed: _saving ? null : _submit,
          child: _saving
              ? const SizedBox(
                  height: 18,
                  width: 18,
                  child: CircularProgressIndicator(strokeWidth: 2),
                )
              : const Text('Crear'),
        ),
      ],
    );
  }
}
