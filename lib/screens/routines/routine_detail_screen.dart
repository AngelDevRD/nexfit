import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/routine.dart';
import '../../services/routine_service.dart';
import '../../services/workout_service.dart';
import '../workout/active_workout_screen.dart';

class RoutineDetailScreen extends StatefulWidget {
  final int routineId;

  const RoutineDetailScreen({super.key, required this.routineId});

  @override
  State<RoutineDetailScreen> createState() => _RoutineDetailScreenState();
}

class _RoutineDetailScreenState extends State<RoutineDetailScreen> {
  late final RoutineService _service;
  Routine? _routine;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = RoutineService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    try {
      final routine = await _service.get(widget.routineId);
      setState(() => _routine = routine);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  Future<void> _delete() async {
    await _service.delete(widget.routineId);
    if (mounted) Navigator.of(context).pop();
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    if (_routine == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final routine = _routine!;

    return Scaffold(
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
          final session = await WorkoutService(
            context.read<ApiClient>(),
          ).startSession(routineId: routine.id);
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
        padding: const EdgeInsets.all(16),
        children: [
          for (final day in routine.days)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      day.name,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    if (day.muscleFocus != null)
                      Text(
                        day.muscleFocus!,
                        style: Theme.of(context).textTheme.bodySmall,
                      ),
                    const Divider(),
                    for (final ex in day.exercises)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        title: Text(ex.exercise.name),
                        subtitle: Text(
                          '${ex.targetSets}x${ex.targetRepsMin}-${ex.targetRepsMax} · descanso ${ex.targetRestSeconds}s',
                        ),
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
