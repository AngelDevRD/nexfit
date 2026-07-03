import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../services/exercise_service.dart';

class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  List<ExerciseSummary> _exercises = [];
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    ExerciseService(context.read<ApiClient>()).list().then((e) {
      setState(() {
        _exercises = e;
        _loading = false;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Elegir ejercicio')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView.builder(
              itemCount: _exercises.length,
              itemBuilder: (context, index) {
                final exercise = _exercises[index];
                final color =
                    muscleGroupColors[exercise.muscleGroup] ?? Colors.grey;
                return ListTile(
                  leading: CircleAvatar(
                    backgroundColor: color.withValues(alpha: 0.2),
                    child: Icon(Icons.fitness_center, color: color),
                  ),
                  title: Text(exercise.name),
                  subtitle: Text(exercise.muscleGroup),
                  onTap: () => Navigator.of(context).pop(exercise),
                );
              },
            ),
    );
  }
}
