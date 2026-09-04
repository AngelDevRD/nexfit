import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/routine.dart';
import '../../models/user.dart';
import '../../repositories/routine_repository.dart';
import '../../repositories/workout_repository.dart';
import '../workout/active_workout_screen.dart';
import 'routine_builder_screen.dart';
import 'routine_detail_screen.dart';

/// N5: siempre vive dentro de [EntrenarHubScreen], que ya provee un FAB
/// persistente "Empezar entrenamiento" -- por eso esta pantalla no usa un
/// FAB propio, sino el botón "+" inline junto al título.
class RoutineListScreen extends StatefulWidget {
  const RoutineListScreen({super.key});

  @override
  State<RoutineListScreen> createState() => _RoutineListScreenState();
}

class _RoutineListScreenState extends State<RoutineListScreen> {
  late final RoutineRepository _repository;
  late final WorkoutRepository _workoutRepository;
  List<RoutineSummary> _routines = [];
  bool _loading = true;
  String? _error;
  String _search = '';
  int? _startingRoutineId;

  @override
  void initState() {
    super.initState();
    _repository = context.read<RoutineRepository>();
    _workoutRepository = context.read<WorkoutRepository>();
    _load();
  }

  // A6: `RoutineRepository.list()` ya resuelve `exerciseNames` en una sola
  // tanda de queries -- ya no hace falta un `get()` por rutina solo para
  // contar ejercicios.
  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final routines = await _repository.list();
      setState(() {
        _routines = routines;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  Future<void> _editRoutine(RoutineSummary summary) async {
    final full = await _repository.get(summary.id);
    if (!mounted) return;
    final updated = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => RoutineBuilderScreen(existing: full)),
    );
    if (updated == true) _load();
  }

  Future<void> _deleteRoutine(RoutineSummary summary) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar rutina'),
        content: Text('¿Eliminar "${summary.name}"?'),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Cancelar'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Eliminar'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;
    await _repository.delete(summary.id);
    if (mounted) _load();
  }

  Future<void> _startTraining(RoutineSummary routine) async {
    setState(() => _startingRoutineId = routine.id);
    try {
      final session = await _workoutRepository.startSession(
        routineId: routine.id,
      );
      if (!mounted) return;
      await Navigator.of(context).push(
        MaterialPageRoute(
          builder: (_) => ActiveWorkoutScreen(sessionId: session.id),
        ),
      );
    } finally {
      if (mounted) setState(() => _startingRoutineId = null);
    }
  }

  List<RoutineSummary> get _filtered {
    if (_search.trim().isEmpty) return _routines;
    final query = _search.trim().toLowerCase();
    return _routines
        .where((r) => r.name.toLowerCase().contains(query))
        .toList();
  }

  Future<void> _createRoutine() async {
    final created = await Navigator.of(context).push<bool>(
      MaterialPageRoute(builder: (_) => const RoutineBuilderScreen()),
    );
    if (created == true) _load();
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        Padding(
          padding: const EdgeInsets.fromLTRB(
            AppSpacing.md,
            AppSpacing.sm,
            AppSpacing.md,
            AppSpacing.md,
          ),
          child: Row(
            crossAxisAlignment: CrossAxisAlignment.center,
            children: [
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Tus Rutinas',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                    Text(
                      'Gestión de entrenamiento personalizado',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
              IconButton(
                icon: const Icon(Icons.add_circle_outline),
                color: AppColors.primary,
                onPressed: _createRoutine,
              ),
            ],
          ),
        ),
        Padding(
          padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
          child: Row(
            children: [
              Expanded(
                child: Container(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                  ),
                  decoration: BoxDecoration(
                    color: AppColors.surfaceContainer,
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: TextField(
                    onChanged: (v) => setState(() => _search = v),
                    decoration: const InputDecoration(
                      hintText: 'Buscar rutina...',
                      border: InputBorder.none,
                      prefixIcon: Icon(Icons.search, size: 20),
                      isDense: true,
                    ),
                  ),
                ),
              ),
            ],
          ),
        ),
        const SizedBox(height: AppSpacing.md),
        Expanded(
          child: _loading
              ? const Center(child: CircularProgressIndicator())
              : _error != null
              ? Center(child: Text(_error!))
              : _routines.isEmpty
              ? const Center(child: Text('Todavía no creaste ninguna rutina.'))
              : RefreshIndicator(
                  onRefresh: _load,
                  child: ListView(
                    padding: const EdgeInsets.fromLTRB(
                      AppSpacing.md,
                      0,
                      AppSpacing.md,
                      96,
                    ),
                    children: [
                      for (final routine in _filtered)
                        _RoutineCard(
                          routine: routine,
                          starting: _startingRoutineId == routine.id,
                          onTrain: () => _startTraining(routine),
                          onEdit: () => _editRoutine(routine),
                          onDelete: () => _deleteRoutine(routine),
                          onOpen: () async {
                            await Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    RoutineDetailScreen(routineId: routine.id),
                              ),
                            );
                            _load();
                          },
                        ),
                    ],
                  ),
                ),
        ),
      ],
    );

    return content;
  }
}

class _RoutineCard extends StatelessWidget {
  final RoutineSummary routine;
  final bool starting;
  final VoidCallback onTrain;
  final VoidCallback onEdit;
  final VoidCallback onDelete;
  final VoidCallback onOpen;

  const _RoutineCard({
    required this.routine,
    required this.starting,
    required this.onTrain,
    required this.onEdit,
    required this.onDelete,
    required this.onOpen,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.md),
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.xl),
          onTap: onOpen,
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        children: [
                          Text(
                            (routine.goal != null
                                    ? goalOptions[routine.goal!] ??
                                          routine.goal!
                                    : 'Personalizada')
                                .toUpperCase(),
                            style: Theme.of(context).textTheme.labelMedium
                                ?.copyWith(
                                  color: AppColors.secondary,
                                  letterSpacing: 1,
                                ),
                          ),
                          const SizedBox(height: 2),
                          Text(
                            routine.name,
                            style: Theme.of(context).textTheme.titleLarge,
                          ),
                          if (routine.exerciseNames.isNotEmpty) ...[
                            const SizedBox(height: 4),
                            Text(
                              routine.exerciseNames.join(', '),
                              maxLines: 2,
                              overflow: TextOverflow.ellipsis,
                              style: Theme.of(context).textTheme.bodyMedium
                                  ?.copyWith(color: AppColors.onSurfaceVariant),
                            ),
                          ],
                        ],
                      ),
                    ),
                    PopupMenuButton<String>(
                      icon: const Icon(
                        Icons.more_vert,
                        color: AppColors.onSurfaceVariant,
                      ),
                      onSelected: (value) {
                        if (value == 'edit') onEdit();
                        if (value == 'delete') onDelete();
                      },
                      itemBuilder: (context) => const [
                        PopupMenuItem(value: 'edit', child: Text('Editar')),
                        PopupMenuItem(value: 'delete', child: Text('Eliminar')),
                      ],
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Row(
                  children: [
                    Icon(
                      Icons.fitness_center,
                      size: 18,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${routine.exerciseNames.length} ejercicios',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                    const SizedBox(width: AppSpacing.lg),
                    Icon(
                      Icons.calendar_today,
                      size: 18,
                      color: AppColors.onSurfaceVariant,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    Text(
                      '${routine.daysPerWeek} días/semana',
                      style: Theme.of(context).textTheme.labelMedium,
                    ),
                  ],
                ),
                const SizedBox(height: AppSpacing.sm),
                Container(
                  padding: const EdgeInsets.only(top: AppSpacing.sm),
                  decoration: const BoxDecoration(
                    border: Border(
                      top: BorderSide(color: AppColors.outlineVariant),
                    ),
                  ),
                  child: Align(
                    alignment: Alignment.centerRight,
                    child: Material(
                      color: AppColors.secondaryContainer,
                      borderRadius: BorderRadius.circular(AppRadius.full),
                      child: InkWell(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        onTap: starting ? null : onTrain,
                        child: Padding(
                          padding: const EdgeInsets.symmetric(
                            horizontal: AppSpacing.lg,
                            vertical: AppSpacing.sm,
                          ),
                          child: Row(
                            mainAxisSize: MainAxisSize.min,
                            children: [
                              Text(
                                'Entrenar',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppColors.onSecondaryContainer,
                                    ),
                              ),
                              const SizedBox(width: 6),
                              if (starting)
                                const SizedBox(
                                  width: 16,
                                  height: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              else
                                Icon(
                                  Icons.play_arrow,
                                  size: 18,
                                  color: AppColors.onSecondaryContainer,
                                ),
                            ],
                          ),
                        ),
                      ),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
