import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/exercise_animation/widgets/exercise_animation_screen.dart';
import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../repositories/exercise_repository.dart';
import '../../widgets/exercise_thumb.dart';

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
    context
        .read<ExerciseRepository>()
        .get(widget.exerciseId)
        .then((e) => setState(() => _exercise = e))
        .catchError((e) => setState(() => _error = e.toString()));
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
    if (_exercise == null) {
      return const Scaffold(
        backgroundColor: AppColors.background,
        body: Center(child: CircularProgressIndicator()),
      );
    }
    final exercise = _exercise!;
    final color = muscleGroupColors[exercise.muscleGroup] ?? Colors.grey;
    final difficultyColor = switch (exercise.difficulty) {
      'beginner' => AppColors.primary,
      'advanced' => AppColors.danger,
      _ => AppColors.secondary,
    };

    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(exercise.name)),
      body: ListView(
        padding: const EdgeInsets.fromLTRB(
          AppSpacing.md,
          AppSpacing.sm,
          AppSpacing.md,
          AppSpacing.xl,
        ),
        children: [
          Row(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              ExerciseThumb(slug: exercise.slug, color: color),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exercise.name,
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                    const SizedBox(height: 4),
                    Wrap(
                      spacing: AppSpacing.sm,
                      runSpacing: 4,
                      children: [
                        _Pill(label: exercise.muscleGroup, color: color),
                        _Pill(
                          label:
                              difficultyLabels[exercise.difficulty] ??
                              exercise.difficulty,
                          color: difficultyColor,
                        ),
                        _Pill(
                          label: exercise.movementType == 'compound'
                              ? 'Compuesto'
                              : 'Aislamiento',
                          color: AppColors.onSurfaceVariant,
                        ),
                      ],
                    ),
                  ],
                ),
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          FilledButton.tonalIcon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) => ExerciseAnimationScreen(
                  exerciseSlug: exercise.slug,
                  exerciseName: exercise.name,
                ),
              ),
            ),
            icon: const Icon(Icons.play_circle_outline),
            label: const Text('Ver animación'),
          ),
          const SizedBox(height: AppSpacing.lg),
          Material(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                exercise.description,
                style: Theme.of(context).textTheme.bodyLarge,
              ),
            ),
          ),
          const SizedBox(height: AppSpacing.lg),
          _Section(
            title: 'Músculos trabajados',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: [
                ...exercise.primaryMuscles.map(
                  (m) => _Pill(label: m, color: color, filled: true),
                ),
                ...exercise.secondaryMuscles.map(
                  (m) => _Pill(label: m, color: AppColors.onSurfaceVariant),
                ),
              ],
            ),
          ),
          _Section(
            title: 'Equipo necesario',
            child: Wrap(
              spacing: AppSpacing.sm,
              runSpacing: AppSpacing.xs,
              children: exercise.equipment
                  .map((e) => _Pill(label: e, color: AppColors.secondary))
                  .toList(),
            ),
          ),
          _Section(
            title: 'Instrucciones',
            child: _NumberedList(items: exercise.instructions, color: color),
          ),
          if (exercise.tips.isNotEmpty)
            _Section(
              title: 'Consejos',
              child: _BulletList(
                items: exercise.tips,
                icon: Icons.lightbulb_outline,
                color: AppColors.secondary,
              ),
            ),
          if (exercise.commonMistakes.isNotEmpty)
            _Section(
              title: 'Errores comunes',
              child: _BulletList(
                items: exercise.commonMistakes,
                icon: Icons.warning_amber_outlined,
                color: AppColors.danger,
              ),
            ),
          if (exercise.variants.isNotEmpty)
            _Section(
              title: 'Variantes',
              child: _BulletList(
                items: exercise.variants,
                icon: Icons.swap_horiz,
                color: AppColors.tertiary,
              ),
            ),
          if (exercise.benefits.isNotEmpty)
            _Section(
              title: 'Beneficios',
              child: _BulletList(
                items: exercise.benefits,
                icon: Icons.check_circle_outline,
                color: AppColors.primary,
              ),
            ),
        ],
      ),
    );
  }
}

class _Pill extends StatelessWidget {
  final String label;
  final Color color;
  final bool filled;

  const _Pill({required this.label, required this.color, this.filled = false});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(
        horizontal: AppSpacing.sm,
        vertical: 6,
      ),
      decoration: BoxDecoration(
        color: color.withValues(alpha: filled ? 0.3 : 0.15),
        borderRadius: BorderRadius.circular(AppRadius.full),
        border: Border.all(color: color.withValues(alpha: 0.4)),
      ),
      child: Text(
        label,
        style: Theme.of(context).textTheme.labelMedium?.copyWith(
          color: color,
          fontWeight: FontWeight.w600,
        ),
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
      padding: const EdgeInsets.only(bottom: AppSpacing.lg),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: Theme.of(context).textTheme.titleLarge),
          const SizedBox(height: AppSpacing.sm),
          child,
        ],
      ),
    );
  }
}

class _NumberedList extends StatelessWidget {
  final List<String> items;
  final Color color;

  const _NumberedList({required this.items, required this.color});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .asMap()
              .entries
              .map(
                (e) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Container(
                        width: 22,
                        height: 22,
                        alignment: Alignment.center,
                        decoration: BoxDecoration(
                          color: color.withValues(alpha: 0.15),
                          shape: BoxShape.circle,
                        ),
                        child: Text(
                          '${e.key + 1}',
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: color,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          e.value,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}

class _BulletList extends StatelessWidget {
  final List<String> items;
  final IconData icon;
  final Color color;

  const _BulletList({
    required this.items,
    required this.icon,
    required this.color,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.md),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: items
              .map(
                (item) => Padding(
                  padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                  child: Row(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Icon(icon, size: 18, color: color),
                      const SizedBox(width: AppSpacing.sm),
                      Expanded(
                        child: Text(
                          item,
                          style: Theme.of(context).textTheme.bodyMedium,
                        ),
                      ),
                    ],
                  ),
                ),
              )
              .toList(),
        ),
      ),
    );
  }
}
