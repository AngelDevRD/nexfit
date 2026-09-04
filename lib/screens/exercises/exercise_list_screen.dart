import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../repositories/exercise_repository.dart';
import '../../widgets/exercise_thumb.dart';
import '../../widgets/muscle_group_filter.dart';
import 'exercise_detail_screen.dart';
import 'exercise_form_screen.dart';

/// N5: siempre vive dentro de [EntrenarHubScreen] (nunca standalone) -- el
/// hub provee Scaffold/AppBar/fondo, esta pantalla solo devuelve contenido.
class ExerciseListScreen extends StatefulWidget {
  const ExerciseListScreen({super.key});

  @override
  State<ExerciseListScreen> createState() => _ExerciseListScreenState();
}

class _ExerciseListScreenState extends State<ExerciseListScreen> {
  late final ExerciseRepository _repository;
  List<ExerciseSummary> _exercises = [];
  bool _loading = true;
  String? _error;
  String? _selectedMuscleGroup;
  String _search = '';

  @override
  void initState() {
    super.initState();
    _repository = context.read<ExerciseRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final exercises = await _repository.list(
        muscleGroup: _selectedMuscleGroup,
      );
      setState(() {
        _exercises = exercises;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _openMuscleGroupSheet() async {
    final selected = await showMuscleGroupFilterSheet(
      context,
      current: _selectedMuscleGroup,
    );
    if (!mounted) return;
    setState(() => _selectedMuscleGroup = selected);
    _load();
  }

  List<ExerciseSummary> get _filtered {
    if (_search.trim().isEmpty) return _exercises;
    final query = _search.trim().toLowerCase();
    return _exercises
        .where((e) => e.name.toLowerCase().contains(query))
        .toList();
  }

  /// E1: alta desde el catálogo (segundo punto de entrada, junto al de
  /// `ExercisePickerScreen` cuando la búsqueda no da resultados).
  Future<void> _createExercise() async {
    final created = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(builder: (_) => const ExerciseFormScreen()),
    );
    if (created != null) _load();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.md,
                AppSpacing.sm,
              ),
              child: TextField(
                onChanged: (v) => setState(() => _search = v),
                decoration: InputDecoration(
                  hintText: 'Buscar ejercicios...',
                  prefixIcon: const Icon(Icons.search),
                  suffixIcon: Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      IconButton(
                        icon: Icon(
                          Icons.tune,
                          color: _selectedMuscleGroup != null
                              ? AppColors.primary
                              : AppColors.onSurfaceVariant,
                        ),
                        onPressed: _openMuscleGroupSheet,
                      ),
                      IconButton(
                        icon: const Icon(
                          Icons.add,
                          color: AppColors.onSurfaceVariant,
                        ),
                        tooltip: 'Crear ejercicio',
                        onPressed: _createExercise,
                      ),
                    ],
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
                    onTap: () {
                      setState(() => _selectedMuscleGroup = null);
                      _load();
                    },
                    trailingIcon: Icons.close,
                  ),
                ),
              ),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _error != null
                  ? Center(child: Text(_error!))
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.lg,
                        ),
                        children: [
                          for (final exercise in _filtered)
                            _ExerciseCard(exercise: exercise, onReturn: _load),
                        ],
                      ),
                    ),
            ),
          ],
        );

    return content;
  }
}

class _ExerciseCard extends StatelessWidget {
  final ExerciseSummary exercise;
  final VoidCallback onReturn;

  const _ExerciseCard({required this.exercise, required this.onReturn});

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
          onTap: () => Navigator.of(context)
              .push(
                MaterialPageRoute(
                  builder: (_) =>
                      ExerciseDetailScreen(exerciseId: exercise.id),
                ),
              )
              // Un ejercicio propio pudo editarse (nombre/grupo cambiado) o
              // eliminarse desde el detalle -- refresca para que la lista
              // no muestre datos viejos ni una tarjeta fantasma.
              .then((_) => onReturn()),
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
