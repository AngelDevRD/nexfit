import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../models/routine.dart';
import '../../models/user.dart';
import '../../repositories/routine_repository.dart';
import '../exercises/exercise_picker_screen.dart';

class _ExerciseDraft {
  final ExerciseSummary exercise;
  int targetSets = 3;
  int targetRepsMin = 8;
  int targetRepsMax = 12;
  int targetRestSeconds = 90;

  _ExerciseDraft(this.exercise);

  _ExerciseDraft.fromRoutineExercise(RoutineExercise re)
    : exercise = re.exercise {
    targetSets = re.targetSets;
    targetRepsMin = re.targetRepsMin;
    targetRepsMax = re.targetRepsMax;
    targetRestSeconds = re.targetRestSeconds;
  }
}

class _DayDraft {
  final TextEditingController nameController;
  String? muscleFocus;
  bool expanded;
  final List<_ExerciseDraft> exercises = [];

  _DayDraft(String name, {this.expanded = true})
    : nameController = TextEditingController(text: name);
}

/// A6: reusa este mismo constructor para crear Y editar -- pasando
/// [existing] precarga días/ejercicios/objetivo y `_save()` actualiza esa
/// rutina en vez de crear una nueva.
class RoutineBuilderScreen extends StatefulWidget {
  final Routine? existing;

  const RoutineBuilderScreen({super.key, this.existing});

  @override
  State<RoutineBuilderScreen> createState() => _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends State<RoutineBuilderScreen> {
  final _nameController = TextEditingController();
  String? _goal;
  late final List<_DayDraft> _days;
  bool _saving = false;
  String? _error;

  bool get _isEditing => widget.existing != null;

  @override
  void initState() {
    super.initState();
    final existing = widget.existing;
    if (existing == null) {
      _days = [_DayDraft('Día 1')];
      return;
    }
    _nameController.text = existing.name;
    _goal = existing.goal;
    _days = existing.days.map((day) {
      final draft = _DayDraft(day.name, expanded: false);
      draft.muscleFocus = day.muscleFocus;
      final sortedExercises = [...day.exercises]
        ..sort((a, b) => a.order.compareTo(b.order));
      draft.exercises.addAll(
        sortedExercises.map(_ExerciseDraft.fromRoutineExercise),
      );
      return draft;
    }).toList();
    if (_days.isNotEmpty) _days.first.expanded = true;
  }

  void _addDay() {
    setState(
      () => _days.add(
        _DayDraft('Día ${_days.length + 1}', expanded: _days.isEmpty),
      ),
    );
  }

  void _removeDay(int index) {
    setState(() => _days.removeAt(index));
  }

  void _toggleDay(int index) {
    setState(() => _days[index].expanded = !_days[index].expanded);
  }

  Future<void> _addExerciseToDay(int dayIndex) async {
    final exercise = await Navigator.of(context).push<ExerciseSummary>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise != null) {
      setState(() => _days[dayIndex].exercises.add(_ExerciseDraft(exercise)));
    }
  }

  Future<void> _save() async {
    if (_nameController.text.trim().isEmpty) {
      setState(() => _error = 'Poné un nombre para la rutina');
      return;
    }
    if (_days.every((d) => d.exercises.isEmpty)) {
      setState(() => _error = 'Agregá al menos un ejercicio a algún día');
      return;
    }
    setState(() {
      _saving = true;
      _error = null;
    });
    final payload = {
      'name': _nameController.text.trim(),
      if (_goal != null) 'goal': _goal,
      'days_per_week': _days.length,
      'days': _days
          .asMap()
          .entries
          .map(
            (entry) => {
              'day_index': entry.key + 1,
              'name': entry.value.nameController.text.trim(),
              if (entry.value.muscleFocus != null)
                'muscle_focus': entry.value.muscleFocus,
              'exercises': entry.value.exercises
                  .asMap()
                  .entries
                  .map(
                    (e) => {
                      'exercise_id': e.value.exercise.id,
                      'order': e.key,
                      'target_sets': e.value.targetSets,
                      'target_reps_min': e.value.targetRepsMin,
                      'target_reps_max': e.value.targetRepsMax,
                      'target_rest_seconds': e.value.targetRestSeconds,
                    },
                  )
                  .toList(),
            },
          )
          .toList(),
    };

    try {
      final repository = context.read<RoutineRepository>();
      if (_isEditing) {
        await repository.update(widget.existing!.id, payload);
      } else {
        await repository.create(payload);
      }
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
    _nameController.dispose();
    for (final d in _days) {
      d.nameController.dispose();
    }
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(_isEditing ? 'Editar rutina' : 'Constructor de rutinas'),
      ),
      floatingActionButton: FloatingActionButton(
        backgroundColor: AppColors.secondary,
        foregroundColor: AppColors.onSecondary,
        onPressed: _saving ? null : _save,
        child: _saving
            ? const SizedBox(
                width: 20,
                height: 20,
                child: CircularProgressIndicator(strokeWidth: 2),
              )
            : const Icon(Icons.check),
      ),
      body: SafeArea(
        child: ListView(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.md,
            AppSpacing.md,
            96,
          ),
          children: [
            Text(
              'Nombre de la rutina',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.xs),
            TextField(
              controller: _nameController,
              decoration: const InputDecoration(
                hintText: 'Ej: Mi rutina de volumen',
              ),
            ),
            if (_error != null) ...[
              const SizedBox(height: AppSpacing.xs),
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            ],
            const SizedBox(height: AppSpacing.md),
            Text(
              'Objetivo',
              style: Theme.of(context).textTheme.labelLarge?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.sm,
              children: goalOptions.entries.map((entry) {
                final selected = _goal == entry.key;
                return ChoiceChip(
                  label: Text(entry.value),
                  selected: selected,
                  onSelected: (_) =>
                      setState(() => _goal = selected ? null : entry.key),
                );
              }).toList(),
            ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Estructura semanal',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            for (int i = 0; i < _days.length; i++)
              _DayCard(
                day: _days[i],
                onAddExercise: () => _addExerciseToDay(i),
                onRemoveDay: () => _removeDay(i),
                onToggle: () => _toggleDay(i),
                onExercisesChanged: () => setState(() {}),
              ),
            const SizedBox(height: AppSpacing.sm),
            Material(
              color: AppColors.surfaceContainerHighest,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: _addDay,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.md),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.edit_calendar, size: 20),
                      const SizedBox(width: AppSpacing.sm),
                      Text(
                        'Agregar día',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _DayCard extends StatefulWidget {
  final _DayDraft day;
  final VoidCallback onAddExercise;
  final VoidCallback onRemoveDay;
  final VoidCallback onToggle;
  final VoidCallback onExercisesChanged;

  const _DayCard({
    required this.day,
    required this.onAddExercise,
    required this.onRemoveDay,
    required this.onToggle,
    required this.onExercisesChanged,
  });

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  @override
  Widget build(BuildContext context) {
    final expanded = widget.day.expanded;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: expanded
            ? AppColors.surfaceContainer
            : AppColors.surfaceContainerLow,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: Border.all(
          color: AppColors.outlineVariant.withValues(alpha: 0.3),
        ),
      ),
      child: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Icon(
                  Icons.calendar_today,
                  size: 18,
                  color: expanded ? AppColors.secondary : AppColors.outline,
                ),
                const SizedBox(width: AppSpacing.sm),
                Expanded(
                  child: expanded
                      ? TextField(
                          controller: widget.day.nameController,
                          style: Theme.of(context).textTheme.titleMedium,
                          decoration: const InputDecoration(
                            isDense: true,
                            border: InputBorder.none,
                          ),
                        )
                      : Row(
                          children: [
                            Flexible(
                              child: Text(
                                widget.day.nameController.text,
                                style: Theme.of(context).textTheme.labelLarge,
                                overflow: TextOverflow.ellipsis,
                              ),
                            ),
                            const SizedBox(width: AppSpacing.xs),
                            Text(
                              '(${widget.day.exercises.length} ejercicios)',
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  color: AppColors.outline,
                  onPressed: widget.onRemoveDay,
                ),
                IconButton(
                  icon: Icon(expanded ? Icons.expand_less : Icons.expand_more),
                  color: expanded ? AppColors.primary : AppColors.outline,
                  onPressed: widget.onToggle,
                ),
              ],
            ),
          ),
          if (expanded)
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                0,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Column(
                children: [
                  for (final draft in widget.day.exercises)
                    _ExerciseRow(
                      draft: draft,
                      onEdit: () async {
                        await _editTargets(context, draft);
                        widget.onExercisesChanged();
                      },
                    ),
                  Material(
                    color: Colors.transparent,
                    child: InkWell(
                      borderRadius: BorderRadius.circular(AppRadius.md),
                      onTap: widget.onAddExercise,
                      child: Container(
                        margin: const EdgeInsets.only(top: AppSpacing.sm),
                        padding: const EdgeInsets.symmetric(
                          vertical: AppSpacing.sm,
                        ),
                        decoration: BoxDecoration(
                          borderRadius: BorderRadius.circular(AppRadius.md),
                          border: Border.all(
                            color: AppColors.outlineVariant,
                            style: BorderStyle.solid,
                          ),
                        ),
                        child: Row(
                          mainAxisAlignment: MainAxisAlignment.center,
                          children: [
                            const Icon(
                              Icons.add_circle_outline,
                              color: AppColors.primary,
                              size: 18,
                            ),
                            const SizedBox(width: AppSpacing.sm),
                            Text(
                              'Agregar ejercicio',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: AppColors.primary),
                            ),
                          ],
                        ),
                      ),
                    ),
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }

  Future<void> _editTargets(BuildContext context, _ExerciseDraft draft) {
    return showDialog(
      context: context,
      builder: (context) => _TargetsDialog(draft: draft),
    );
  }
}

/// Diálogo de "Editar objetivos" como `StatefulWidget` propio (mismo fix que
/// `set_form_sheet.dart`, AG-CORE-009): los 4 `TextEditingController` vivían
/// en una función y nunca se liberaban.
class _TargetsDialog extends StatefulWidget {
  final _ExerciseDraft draft;

  const _TargetsDialog({required this.draft});

  @override
  State<_TargetsDialog> createState() => _TargetsDialogState();
}

class _TargetsDialogState extends State<_TargetsDialog> {
  late final TextEditingController setsController;
  late final TextEditingController repsMinController;
  late final TextEditingController repsMaxController;
  late final TextEditingController restController;

  @override
  void initState() {
    super.initState();
    setsController = TextEditingController(
      text: widget.draft.targetSets.toString(),
    );
    repsMinController = TextEditingController(
      text: widget.draft.targetRepsMin.toString(),
    );
    repsMaxController = TextEditingController(
      text: widget.draft.targetRepsMax.toString(),
    );
    restController = TextEditingController(
      text: widget.draft.targetRestSeconds.toString(),
    );
  }

  @override
  void dispose() {
    setsController.dispose();
    repsMinController.dispose();
    repsMaxController.dispose();
    restController.dispose();
    super.dispose();
  }

  void _save() {
    final draft = widget.draft;
    draft.targetSets = int.tryParse(setsController.text) ?? draft.targetSets;
    draft.targetRepsMin =
        int.tryParse(repsMinController.text) ?? draft.targetRepsMin;
    draft.targetRepsMax =
        int.tryParse(repsMaxController.text) ?? draft.targetRepsMax;
    draft.targetRestSeconds =
        int.tryParse(restController.text) ?? draft.targetRestSeconds;
    Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    return AlertDialog(
      title: Text(widget.draft.exercise.name),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: setsController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Series'),
          ),
          TextField(
            controller: repsMinController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reps mínimo'),
          ),
          TextField(
            controller: repsMaxController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Reps máximo'),
          ),
          TextField(
            controller: restController,
            keyboardType: TextInputType.number,
            decoration: const InputDecoration(labelText: 'Descanso (segundos)'),
            onSubmitted: (_) => _save(),
          ),
        ],
      ),
      actions: [
        TextButton(
          onPressed: () => Navigator.of(context).pop(),
          child: const Text('Cancelar'),
        ),
        FilledButton(onPressed: _save, child: const Text('Guardar')),
      ],
    );
  }
}

class _ExerciseRow extends StatelessWidget {
  final _ExerciseDraft draft;
  final VoidCallback onEdit;

  const _ExerciseRow({required this.draft, required this.onEdit});

  @override
  Widget build(BuildContext context) {
    // Toda la fila es la acción de editar objetivos -- antes solo el ícono
    // `tune` (que en el entrenamiento activo ya significa "más opciones",
    // otro sentido) lo era, y sin etiqueta no se entendía qué hacía.
    return Material(
      color: Colors.transparent,
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.md),
        onTap: onEdit,
        child: Padding(
          padding: const EdgeInsets.symmetric(vertical: 4),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainerHighest,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: AppColors.primary,
                  size: 20,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      draft.exercise.name,
                      style: Theme.of(context).textTheme.labelLarge,
                      maxLines: 1,
                      overflow: TextOverflow.ellipsis,
                    ),
                    Text(
                      '${draft.targetSets} x ${draft.targetRepsMin}-${draft.targetRepsMax} · ${draft.targetRestSeconds}s',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.primary,
                        decoration: TextDecoration.underline,
                        decorationColor: AppColors.primary.withValues(
                          alpha: 0.4,
                        ),
                      ),
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.edit_outlined,
                color: AppColors.outline,
                size: 18,
              ),
            ],
          ),
        ),
      ),
    );
  }
}
