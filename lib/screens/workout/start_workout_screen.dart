import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/routine.dart';
import '../../services/routine_service.dart';
import '../../services/workout_service.dart';
import 'active_workout_screen.dart';

class StartWorkoutScreen extends StatefulWidget {
  const StartWorkoutScreen({super.key});

  @override
  State<StartWorkoutScreen> createState() => _StartWorkoutScreenState();
}

class _StartWorkoutScreenState extends State<StartWorkoutScreen> {
  List<RoutineSummary> _routines = [];
  bool _loading = true;
  bool _starting = false;

  @override
  void initState() {
    super.initState();
    RoutineService(context.read<ApiClient>()).list().then((routines) {
      setState(() {
        _routines = routines;
        _loading = false;
      });
    });
  }

  Future<void> _start({int? routineId}) async {
    setState(() => _starting = true);
    final session = await WorkoutService(
      context.read<ApiClient>(),
    ).startSession(routineId: routineId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(sessionId: session.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Iniciar entrenamiento')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.all(16),
              children: [
                Card(
                  child: ListTile(
                    leading: const Icon(Icons.bolt),
                    title: const Text('Entrenamiento libre'),
                    subtitle: const Text(
                      'Sin rutina, elegís los ejercicios sobre la marcha',
                    ),
                    trailing: _starting
                        ? const CircularProgressIndicator()
                        : const Icon(Icons.chevron_right),
                    onTap: _starting ? null : () => _start(),
                  ),
                ),
                const SizedBox(height: 12),
                if (_routines.isNotEmpty)
                  Text(
                    'O elegí una rutina',
                    style: Theme.of(context).textTheme.titleMedium,
                  ),
                const SizedBox(height: 8),
                ..._routines.map(
                  (routine) => Card(
                    child: ListTile(
                      leading: const Icon(Icons.list_alt),
                      title: Text(routine.name),
                      subtitle: Text('${routine.daysPerWeek} días por semana'),
                      onTap: _starting
                          ? null
                          : () => _start(routineId: routine.id),
                    ),
                  ),
                ),
              ],
            ),
    );
  }
}
