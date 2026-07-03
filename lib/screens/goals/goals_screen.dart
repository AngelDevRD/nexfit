import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/exercise.dart';
import '../../models/goal.dart';
import '../../services/goal_service.dart';
import '../exercises/exercise_picker_screen.dart';

class GoalsScreen extends StatefulWidget {
  const GoalsScreen({super.key});

  @override
  State<GoalsScreen> createState() => _GoalsScreenState();
}

class _GoalsScreenState extends State<GoalsScreen> {
  late final GoalService _service;
  List<Goal> _goals = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _service = GoalService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final goals = await _service.list();
    setState(() {
      _goals = goals;
      _loading = false;
    });
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
    return Scaffold(
      appBar: AppBar(title: const Text('Objetivos')),
      floatingActionButton: FloatingActionButton(
        onPressed: _openCreateDialog,
        child: const Icon(Icons.add),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : RefreshIndicator(
              onRefresh: _load,
              child: _goals.isEmpty
                  ? ListView(
                      children: const [
                        Padding(
                          padding: EdgeInsets.all(24),
                          child: Text('Sin objetivos todavía.'),
                        ),
                      ],
                    )
                  : ListView.builder(
                      padding: const EdgeInsets.all(16),
                      itemCount: _goals.length,
                      itemBuilder: (context, index) {
                        final goal = _goals[index];
                        return Card(
                          margin: const EdgeInsets.only(bottom: 12),
                          child: Padding(
                            padding: const EdgeInsets.all(12),
                            child: Column(
                              crossAxisAlignment: CrossAxisAlignment.start,
                              children: [
                                Row(
                                  children: [
                                    Expanded(
                                      child: Text(
                                        goal.title,
                                        style: Theme.of(
                                          context,
                                        ).textTheme.titleMedium,
                                      ),
                                    ),
                                    if (goal.achieved)
                                      const Icon(
                                        Icons.check_circle,
                                        color: Colors.green,
                                      ),
                                    IconButton(
                                      icon: const Icon(Icons.delete_outline),
                                      onPressed: () async {
                                        await _service.delete(goal.id);
                                        _load();
                                      },
                                    ),
                                  ],
                                ),
                                Text(
                                  '${goal.currentValue} / ${goal.targetValue}',
                                ),
                                const SizedBox(height: 8),
                                ClipRRect(
                                  borderRadius: BorderRadius.circular(8),
                                  child: LinearProgressIndicator(
                                    value: goal.progressPct / 100,
                                    minHeight: 8,
                                  ),
                                ),
                                const SizedBox(height: 4),
                                Text('${goal.progressPct.toStringAsFixed(0)}%'),
                              ],
                            ),
                          ),
                        );
                      },
                    ),
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
      await GoalService(context.read<ApiClient>()).create({
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
      title: const Text('Nuevo objetivo'),
      content: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          TextField(
            controller: _titleController,
            decoration: const InputDecoration(labelText: 'Título'),
          ),
          const SizedBox(height: 12),
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
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _pickExercise,
              child: Text(_exercise?.name ?? 'Elegir ejercicio'),
            ),
          ],
          const SizedBox(height: 12),
          TextField(
            controller: _targetController,
            keyboardType: const TextInputType.numberWithOptions(decimal: true),
            decoration: const InputDecoration(labelText: 'Valor objetivo'),
          ),
          if (_error != null) ...[
            const SizedBox(height: 8),
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
              ? const CircularProgressIndicator()
              : const Text('Crear'),
        ),
      ],
    );
  }
}
