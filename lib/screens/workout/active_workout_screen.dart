import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/exercise.dart';
import '../../models/workout.dart';
import '../../services/workout_service.dart';
import '../exercises/exercise_picker_screen.dart';
import 'rest_timer_banner.dart';
import 'set_form_sheet.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final int sessionId;

  const ActiveWorkoutScreen({super.key, required this.sessionId});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen> {
  late final WorkoutService _service;
  WorkoutSession? _session;
  int? _restSeconds;
  bool _finishing = false;

  @override
  void initState() {
    super.initState();
    _service = WorkoutService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    final session = await _service.get(widget.sessionId);
    setState(() => _session = session);
  }

  Map<int, List<WorkoutSet>> _groupedSets() {
    final grouped = <int, List<WorkoutSet>>{};
    for (final set in _session!.sets) {
      grouped.putIfAbsent(set.exercise.id, () => []).add(set);
    }
    return grouped;
  }

  Future<void> _addExercise() async {
    final exercise = await Navigator.of(context).push<ExerciseSummary>(
      MaterialPageRoute(builder: (_) => const ExercisePickerScreen()),
    );
    if (exercise != null) {
      await _logSet(exercise, setNumber: 1);
    }
  }

  Future<void> _addSetFor(
    ExerciseSummary exercise,
    int nextSetNumber, {
    double initialWeight = 0,
    int initialReps = 0,
  }) async {
    await _logSet(
      exercise,
      setNumber: nextSetNumber,
      initialWeight: initialWeight,
      initialReps: initialReps,
    );
  }

  Future<void> _logSet(
    ExerciseSummary exercise, {
    required int setNumber,
    double initialWeight = 0,
    int initialReps = 0,
  }) async {
    final result = await showSetFormSheet(
      context,
      initialWeight: initialWeight,
      initialReps: initialReps,
    );
    if (result == null) return;

    final previousRecordIds = <int>{
      for (final r in await _service.sessionRecords(widget.sessionId)) r.id,
    };

    await _service.addSet(widget.sessionId, {
      'exercise_id': exercise.id,
      'set_number': setNumber,
      'weight_kg': result.weightKg,
      'reps': result.reps,
      if (result.rpe != null) 'rpe': result.rpe,
      if (result.rir != null) 'rir': result.rir,
      'rest_seconds': result.restSeconds,
      'techniques': result.techniques,
      'is_warmup': result.isWarmup,
      if (result.notes != null) 'notes': result.notes,
    });

    await _load();

    if (!result.isWarmup) {
      final newRecords = await _service.sessionRecords(widget.sessionId);
      final freshRecords = newRecords
          .where((r) => !previousRecordIds.contains(r.id))
          .toList();
      if (freshRecords.isNotEmpty && mounted) {
        await _showRecordCelebration(freshRecords);
      }
    }

    if (mounted) {
      setState(() => _restSeconds = result.restSeconds);
    }
  }

  Future<void> _showRecordCelebration(List<PersonalRecord> records) {
    return showDialog(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('🏆 ¡Nuevo récord personal!'),
        content: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: records
              .map(
                (r) => Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Text(
                    '${recordTypeLabels[r.recordType] ?? r.recordType}: ${r.value}'
                    '${r.previousValue != null ? ' (antes: ${r.previousValue})' : ''}',
                  ),
                ),
              )
              .toList(),
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(),
            child: const Text('¡Genial!'),
          ),
        ],
      ),
    );
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    await _service.finishSession(widget.sessionId);
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final grouped = _groupedSets();
    final exercisesInSession = <int, ExerciseSummary>{};
    for (final set in _session!.sets) {
      exercisesInSession[set.exercise.id] = set.exercise;
    }

    return Scaffold(
      appBar: AppBar(
        title: const Text('Entrenamiento en curso'),
        actions: [
          TextButton(
            onPressed: _finishing ? null : _finish,
            child: _finishing
                ? const SizedBox(
                    height: 20,
                    width: 20,
                    child: CircularProgressIndicator(strokeWidth: 2),
                  )
                : const Text(
                    'Finalizar',
                    style: TextStyle(color: Colors.white),
                  ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Agregar ejercicio'),
      ),
      body: Column(
        children: [
          if (_restSeconds != null)
            RestTimerBanner(
              key: ValueKey(DateTime.now().millisecondsSinceEpoch),
              seconds: _restSeconds!,
              onDismiss: () => setState(() => _restSeconds = null),
            ),
          Expanded(
            child: exercisesInSession.isEmpty
                ? const Center(
                    child: Text(
                      'Agregá un ejercicio para empezar a registrar series.',
                    ),
                  )
                : ListView(
                    padding: const EdgeInsets.all(16),
                    children: exercisesInSession.entries.map((entry) {
                      final exercise = entry.value;
                      final sets = grouped[entry.key]!;
                      return Card(
                        margin: const EdgeInsets.only(bottom: 12),
                        child: Padding(
                          padding: const EdgeInsets.all(12),
                          child: Column(
                            crossAxisAlignment: CrossAxisAlignment.start,
                            children: [
                              Text(
                                exercise.name,
                                style: Theme.of(context).textTheme.titleMedium,
                              ),
                              const Divider(),
                              for (final set in sets)
                                ListTile(
                                  dense: true,
                                  contentPadding: EdgeInsets.zero,
                                  leading: CircleAvatar(
                                    radius: 14,
                                    child: Text('${set.setNumber}'),
                                  ),
                                  title: Text(
                                    '${set.weightKg} kg × ${set.reps} reps${set.isWarmup ? ' (calentamiento)' : ''}',
                                  ),
                                  subtitle: Text(
                                    [
                                      if (set.rpe != null) 'RPE ${set.rpe}',
                                      if (set.rir != null) 'RIR ${set.rir}',
                                      if (set.techniques.isNotEmpty)
                                        set.techniques
                                            .map(
                                              (t) =>
                                                  availableTechniques[t] ?? t,
                                            )
                                            .join(', '),
                                    ].join(' · '),
                                  ),
                                  trailing: IconButton(
                                    icon: const Icon(
                                      Icons.delete_outline,
                                      size: 20,
                                    ),
                                    onPressed: () async {
                                      await _service.deleteSet(set.id);
                                      _load();
                                    },
                                  ),
                                ),
                              Align(
                                alignment: Alignment.centerLeft,
                                child: TextButton.icon(
                                  onPressed: () => _addSetFor(
                                    exercise,
                                    sets.length + 1,
                                    initialWeight: sets.last.weightKg,
                                    initialReps: sets.last.reps,
                                  ),
                                  icon: const Icon(Icons.add),
                                  label: const Text('Agregar serie'),
                                ),
                              ),
                            ],
                          ),
                        ),
                      );
                    }).toList(),
                  ),
          ),
        ],
      ),
    );
  }
}
