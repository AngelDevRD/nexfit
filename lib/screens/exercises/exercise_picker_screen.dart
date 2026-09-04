import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/local/database.dart' hide Exercise;
import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../widgets/exercise_thumb.dart';
import '../../widgets/muscle_group_filter.dart';
import 'exercise_form_screen.dart';

class ExercisePickerScreen extends StatefulWidget {
  const ExercisePickerScreen({super.key});

  @override
  State<ExercisePickerScreen> createState() => _ExercisePickerScreenState();
}

class _ExercisePickerScreenState extends State<ExercisePickerScreen> {
  List<ExerciseSummary> _exercises = [];
  bool _loading = true;
  String _search = '';
  String? _selectedMuscleGroup;

  @override
  void initState() {
    super.initState();
    // Catalogo local (sembrado offline desde assets/data/exercises.json) --
    // no depende de la API, funciona sin conexion.
    context
        .read<AppDatabase>()
        .select(context.read<AppDatabase>().exercises)
        .get()
        .then((rows) {
          setState(() {
            _exercises = rows
                .map(
                  (r) => ExerciseSummary(
                    id: r.id,
                    slug: r.slug,
                    name: r.name,
                    muscleGroup: r.muscleGroup,
                    difficulty: r.difficulty,
                    imageUrl: r.imageUrl,
                  ),
                )
                .toList();
            _loading = false;
          });
        });
  }

  List<ExerciseSummary> get _filtered {
    var result = _exercises;
    if (_selectedMuscleGroup != null) {
      result = result
          .where((e) => e.muscleGroup == _selectedMuscleGroup)
          .toList();
    }
    if (_search.trim().isNotEmpty) {
      final query = _search.trim().toLowerCase();
      result = result.where((e) => e.name.toLowerCase().contains(query)).toList();
    }
    return result;
  }

  Future<void> _openMuscleGroupSheet() async {
    final selected = await showMuscleGroupFilterSheet(
      context,
      current: _selectedMuscleGroup,
    );
    if (!mounted) return;
    setState(() => _selectedMuscleGroup = selected);
  }

  /// E1: la búsqueda sin resultados es el momento exacto en que el usuario
  /// descubre que el ejercicio no está en el catálogo -- ofrecerle crearlo
  /// ahí mismo, con el nombre que ya escribió, en vez de mandarlo a buscar
  /// otra pantalla.
  Future<void> _createFromSearch() async {
    final created = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => ExerciseFormScreen(initialName: _search.trim()),
      ),
    );
    if (created == null || !mounted) return;
    Navigator.of(context).pop(
      ExerciseSummary(
        id: created.id,
        slug: created.slug,
        name: created.name,
        muscleGroup: created.muscleGroup,
        difficulty: created.difficulty,
        imageUrl: created.imageUrl,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Elegir ejercicio')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : Column(
              children: [
                Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    AppSpacing.sm,
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: InputDecoration(
                      hintText: 'Buscar ejercicios...',
                      prefixIcon: const Icon(Icons.search),
                      suffixIcon: IconButton(
                        icon: Icon(
                          Icons.tune,
                          color: _selectedMuscleGroup != null
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                        ),
                        onPressed: _openMuscleGroupSheet,
                      ),
                      border: OutlineInputBorder(
                        borderRadius: BorderRadius.circular(AppRadius.md),
                        borderSide: BorderSide.none,
                      ),
                    ),
                  ),
                ),
                if (_selectedMuscleGroup != null)
                  Padding(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      AppSpacing.sm,
                    ),
                    child: Align(
                      alignment: Alignment.centerLeft,
                      child: MuscleChip(
                        label: _selectedMuscleGroup!,
                        color:
                            muscleGroupColors[_selectedMuscleGroup] ??
                            AppColors.onSurfaceVariant,
                        selected: true,
                        onTap: () =>
                            setState(() => _selectedMuscleGroup = null),
                        trailingIcon: Icons.close,
                      ),
                    ),
                  ),
                Expanded(
                  child: _filtered.isEmpty
                      ? Center(
                          child: Column(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              const Text('No se encontraron ejercicios.'),
                              if (_search.trim().isNotEmpty) ...[
                                const SizedBox(height: AppSpacing.md),
                                FilledButton.tonalIcon(
                                  onPressed: _createFromSearch,
                                  icon: const Icon(Icons.add),
                                  label: Text('Crear "${_search.trim()}"'),
                                ),
                              ],
                            ],
                          ),
                        )
                      : ListView(
                          padding: const EdgeInsets.fromLTRB(
                            AppSpacing.md,
                            0,
                            AppSpacing.md,
                            AppSpacing.lg,
                          ),
                          children: [
                            for (final exercise in _filtered)
                              _PickerCard(exercise: exercise),
                          ],
                        ),
                ),
              ],
            ),
    );
  }
}

class _PickerCard extends StatelessWidget {
  final ExerciseSummary exercise;

  const _PickerCard({required this.exercise});

  @override
  Widget build(BuildContext context) {
    final color = muscleGroupColors[exercise.muscleGroup] ?? Colors.grey;
    final difficultyColor = switch (exercise.difficulty) {
      'beginner' => AppColors.primary,
      'advanced' => AppColors.danger,
      _ => AppColors.secondary,
    };
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Navigator.of(context).pop(exercise),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                ExerciseThumb(
                  slug: exercise.slug,
                  color: color,
                  muscleGroup: exercise.muscleGroup,
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      const SizedBox(height: 4),
                      Row(
                        children: [
                          Text(
                            difficultyLabels[exercise.difficulty] ??
                                exercise.difficulty,
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(color: difficultyColor),
                          ),
                          const SizedBox(width: 8),
                          Container(
                            width: 3,
                            height: 3,
                            decoration: const BoxDecoration(
                              shape: BoxShape.circle,
                              color: AppColors.outlineVariant,
                            ),
                          ),
                          const SizedBox(width: 8),
                          Expanded(
                            child: Text(
                              exercise.muscleGroup,
                              style: Theme.of(context).textTheme.labelMedium
                                  ?.copyWith(color: AppColors.onSurfaceVariant),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ),
                        ],
                      ),
                    ],
                  ),
                ),
                const Icon(
                  Icons.chevron_right,
                  color: AppColors.onSurfaceVariant,
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
