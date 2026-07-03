import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../services/exercise_service.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final int exerciseId;

  const ExerciseDetailScreen({super.key, required this.exerciseId});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen> {
  Exercise? _exercise;
  String? _error;

  @override
  void initState() {
    super.initState();
    ExerciseService(context.read<ApiClient>())
        .get(widget.exerciseId)
        .then((e) => setState(() => _exercise = e))
        .catchError((e) => setState(() => _error = e.toString()));
  }

  @override
  Widget build(BuildContext context) {
    if (_error != null) {
      return Scaffold(
        appBar: AppBar(),
        body: Center(child: Text(_error!)),
      );
    }
    if (_exercise == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final exercise = _exercise!;
    final color = muscleGroupColors[exercise.muscleGroup] ?? Colors.grey;

    return Scaffold(
      appBar: AppBar(title: Text(exercise.name)),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Wrap(
            spacing: 8,
            children: [
              Chip(
                label: Text(exercise.muscleGroup),
                backgroundColor: color.withValues(alpha: 0.2),
              ),
              Chip(
                label: Text(
                  difficultyLabels[exercise.difficulty] ?? exercise.difficulty,
                ),
              ),
              Chip(
                label: Text(
                  exercise.movementType == 'compound'
                      ? 'Compuesto'
                      : 'Aislamiento',
                ),
              ),
            ],
          ),
          const SizedBox(height: 16),
          Text(
            exercise.description,
            style: Theme.of(context).textTheme.bodyLarge,
          ),
          const SizedBox(height: 20),
          _Section(
            title: 'Músculos trabajados',
            child: Wrap(
              spacing: 8,
              runSpacing: 4,
              children: [
                ...exercise.primaryMuscles.map(
                  (m) => Chip(
                    label: Text(m),
                    backgroundColor: color.withValues(alpha: 0.3),
                  ),
                ),
                ...exercise.secondaryMuscles.map((m) => Chip(label: Text(m))),
              ],
            ),
          ),
          _Section(
            title: 'Equipo necesario',
            child: Wrap(
              spacing: 8,
              children: exercise.equipment
                  .map((e) => Chip(label: Text(e)))
                  .toList(),
            ),
          ),
          _Section(
            title: 'Instrucciones',
            child: _NumberedList(items: exercise.instructions),
          ),
          if (exercise.tips.isNotEmpty)
            _Section(
              title: 'Consejos',
              child: _BulletList(
                items: exercise.tips,
                icon: Icons.lightbulb_outline,
              ),
            ),
          if (exercise.commonMistakes.isNotEmpty)
            _Section(
              title: 'Errores comunes',
              child: _BulletList(
                items: exercise.commonMistakes,
                icon: Icons.warning_amber_outlined,
              ),
            ),
          if (exercise.variants.isNotEmpty)
            _Section(
              title: 'Variantes',
              child: _BulletList(
                items: exercise.variants,
                icon: Icons.swap_horiz,
              ),
            ),
          if (exercise.benefits.isNotEmpty)
            _Section(
              title: 'Beneficios',
              child: _BulletList(
                items: exercise.benefits,
                icon: Icons.check_circle_outline,
              ),
            ),
        ],
      ),
    );
  }
}

class _Section extends StatelessWidget {
  final String title;
  final Widget child;

  const _Section({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: 20),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            title,
            style: Theme.of(
              context,
            ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
          ),
          const SizedBox(height: 8),
          child,
        ],
      ),
    );
  }
}

class _NumberedList extends StatelessWidget {
  final List<String> items;

  const _NumberedList({required this.items});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .asMap()
          .entries
          .map(
            (e) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Text('${e.key + 1}. ${e.value}'),
            ),
          )
          .toList(),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  final IconData icon;

  const _BulletList({required this.items, required this.icon});

  @override
  Widget build(BuildContext context) {
    return Column(
      crossAxisAlignment: CrossAxisAlignment.start,
      children: items
          .map(
            (item) => Padding(
              padding: const EdgeInsets.only(bottom: 6),
              child: Row(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Icon(icon, size: 18),
                  const SizedBox(width: 8),
                  Expanded(child: Text(item)),
                ],
              ),
            ),
          )
          .toList(),
    );
  }
}
