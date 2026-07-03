import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/exercise.dart';
import '../../models/user.dart';
import '../../services/routine_service.dart';
import '../exercises/exercise_picker_screen.dart';

class _ExerciseDraft {
  final ExerciseSummary exercise;
  int targetSets;
  int targetRepsMin;
  int targetRepsMax;
  int targetRestSeconds;

  _ExerciseDraft(
    this.exercise, {
    this.targetSets = 3,
    this.targetRepsMin = 8,
    this.targetRepsMax = 12,
    this.targetRestSeconds = 90,
  });
}

class _DayDraft {
  final TextEditingController nameController;
  String? muscleFocus;
  final List<_ExerciseDraft> exercises = [];

  _DayDraft(String name) : nameController = TextEditingController(text: name);
}

class RoutineBuilderScreen extends StatefulWidget {
  const RoutineBuilderScreen({super.key});

  @override
  State<RoutineBuilderScreen> createState() => _RoutineBuilderScreenState();
}

class _RoutineBuilderScreenState extends State<RoutineBuilderScreen> {
  final _nameController = TextEditingController();
  String? _goal;
  final List<_DayDraft> _days = [_DayDraft('Día 1')];
  bool _saving = false;
  String? _error;

  void _addDay() {
    setState(() => _days.add(_DayDraft('Día ${_days.length + 1}')));
  }

  void _removeDay(int index) {
    setState(() => _days.removeAt(index));
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
      await RoutineService(context.read<ApiClient>()).create(payload);
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
      appBar: AppBar(title: const Text('Nueva rutina')),
      floatingActionButton: FloatingActionButton(
        onPressed: _saving ? null : _save,
        child: _saving
            ? const CircularProgressIndicator()
            : const Icon(Icons.check),
      ),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 96),
        children: [
          TextField(
            controller: _nameController,
            decoration: const InputDecoration(labelText: 'Nombre de la rutina'),
          ),
          const SizedBox(height: 12),
          DropdownButtonFormField<String>(
            initialValue: _goal,
            decoration: const InputDecoration(labelText: 'Objetivo (opcional)'),
            items: goalOptions.entries
                .map(
                  (e) => DropdownMenuItem(value: e.key, child: Text(e.value)),
                )
                .toList(),
            onChanged: (v) => setState(() => _goal = v),
          ),
          if (_error != null) ...[
            const SizedBox(height: 12),
            Text(
              _error!,
              style: TextStyle(color: Theme.of(context).colorScheme.error),
            ),
          ],
          const SizedBox(height: 20),
          for (int i = 0; i < _days.length; i++)
            _DayCard(
              day: _days[i],
              onAddExercise: () => _addExerciseToDay(i),
              onRemoveDay: () => _removeDay(i),
            ),
          const SizedBox(height: 8),
          OutlinedButton.icon(
            onPressed: _addDay,
            icon: const Icon(Icons.add),
            label: const Text('Agregar día'),
          ),
        ],
      ),
    );
  }
}

class _DayCard extends StatefulWidget {
  final _DayDraft day;
  final VoidCallback onAddExercise;
  final VoidCallback onRemoveDay;

  const _DayCard({
    required this.day,
    required this.onAddExercise,
    required this.onRemoveDay,
  });

  @override
  State<_DayCard> createState() => _DayCardState();
}

class _DayCardState extends State<_DayCard> {
  @override
  Widget build(BuildContext context) {
    return Card(
      margin: const EdgeInsets.only(bottom: 12),
      child: Padding(
        padding: const EdgeInsets.all(12),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.stretch,
          children: [
            Row(
              children: [
                Expanded(
                  child: TextField(
                    controller: widget.day.nameController,
                    decoration: const InputDecoration(
                      labelText: 'Nombre del día',
                    ),
                  ),
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: widget.onRemoveDay,
                ),
              ],
            ),
            ...widget.day.exercises.map(
              (draft) => ListTile(
                dense: true,
                title: Text(draft.exercise.name),
                subtitle: Text(
                  '${draft.targetSets}x${draft.targetRepsMin}-${draft.targetRepsMax} · descanso ${draft.targetRestSeconds}s',
                ),
                trailing: IconButton(
                  icon: const Icon(Icons.tune),
                  onPressed: () async {
                    await _editTargets(context, draft);
                    setState(() {});
                  },
                ),
              ),
            ),
            Align(
              alignment: Alignment.centerLeft,
              child: TextButton.icon(
                onPressed: widget.onAddExercise,
                icon: const Icon(Icons.add),
                label: const Text('Agregar ejercicio'),
              ),
            ),
          ],
        ),
      ),
    );
  }

  Future<void> _editTargets(BuildContext context, _ExerciseDraft draft) {
    final setsController = TextEditingController(
      text: draft.targetSets.toString(),
    );
    final repsMinController = TextEditingController(
      text: draft.targetRepsMin.toString(),
    );
    final repsMaxController = TextEditingController(
      text: draft.targetRepsMax.toString(),
    );
    final restController = TextEditingController(
      text: draft.targetRestSeconds.toString(),
    );

    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: Text(draft.exercise.name),
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
              decoration: const InputDecoration(
                labelText: 'Descanso (segundos)',
              ),
            ),
          ],
        ),
        actions: [
          TextButton(
            onPressed: () {
              draft.targetSets =
                  int.tryParse(setsController.text) ?? draft.targetSets;
              draft.targetRepsMin =
                  int.tryParse(repsMinController.text) ?? draft.targetRepsMin;
              draft.targetRepsMax =
                  int.tryParse(repsMaxController.text) ?? draft.targetRepsMax;
              draft.targetRestSeconds =
                  int.tryParse(restController.text) ?? draft.targetRestSeconds;
              Navigator.of(context).pop();
            },
            child: const Text('Guardar'),
          ),
        ],
      ),
    );
  }
}
