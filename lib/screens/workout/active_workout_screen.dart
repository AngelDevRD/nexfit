import 'dart:async';

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/exercise.dart';
import '../../models/workout.dart';
import '../../repositories/active_workout_repository.dart';
import '../../repositories/personal_records_service.dart';
import '../../repositories/workout_repository.dart';
import '../exercises/exercise_picker_screen.dart';
import 'rest_timer_banner.dart';
import 'set_form_sheet.dart';

class ActiveWorkoutScreen extends StatefulWidget {
  final int sessionId;

  const ActiveWorkoutScreen({super.key, required this.sessionId});

  @override
  State<ActiveWorkoutScreen> createState() => _ActiveWorkoutScreenState();
}

class _ActiveWorkoutScreenState extends State<ActiveWorkoutScreen>
    with WidgetsBindingObserver {
  late final WorkoutRepository _repository;
  late final ActiveWorkoutRepository _activeRepository;
  WorkoutSession? _session;
  DateTime? _restEndsAt;
  bool _finishing = false;
  List<ResolvedRecord>? _newRecords;
  Timer? _elapsedTimer;
  Duration _elapsed = Duration.zero;

  @override
  void initState() {
    super.initState();
    WidgetsBinding.instance.addObserver(this);
    _repository = context.read<WorkoutRepository>();
    _activeRepository = context.read<ActiveWorkoutRepository>();
    _load();
  }

  Future<void> _load() async {
    final session = await _repository.get(widget.sessionId);
    // El descanso persiste como instante absoluto en el draft -> si la app se
    // cerró a mitad de un descanso, al reabrir se restaura el mismo estado
    // (RestTimerBanner recalcula el restante contra `DateTime.now()`).
    final restEndsAt = await _activeRepository.restEndsAt();
    if (!mounted) return;
    setState(() {
      _session = session;
      _restEndsAt = restEndsAt;
    });
    _elapsedTimer ??= Timer.periodic(const Duration(seconds: 1), (_) {
      if (!mounted) return;
      setState(() => _elapsed = DateTime.now().difference(session.startedAt));
    });
  }

  @override
  void didChangeAppLifecycleState(AppLifecycleState state) {
    // Al volver del background, el `Timer` puede haber quedado pausado por el
    // SO -- se recalcula el elapsed/descanso de inmediato en vez de esperar
    // hasta el próximo tick, para que la UI no se vea "congelada" un segundo.
    if (state == AppLifecycleState.resumed && _session != null) {
      setState(() => _elapsed = DateTime.now().difference(_session!.startedAt));
    }
  }

  @override
  void dispose() {
    WidgetsBinding.instance.removeObserver(this);
    _elapsedTimer?.cancel();
    super.dispose();
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

    final outcome = await _repository.addSet(widget.sessionId, {
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

    // Los récords nuevos los reporta `addSet` directamente (detección por
    // upsert). Ya no se difumina por id contra un snapshot previo, que fallaba
    // cuando el récord actualizaba una fila existente en vez de crear una.
    if (outcome.newRecords.isNotEmpty && mounted) {
      setState(() => _newRecords = outcome.newRecords);
    }

    final restEndsAt = DateTime.now().add(
      Duration(seconds: result.restSeconds),
    );
    await _activeRepository.updateProgress(
      currentExerciseId: exercise.id,
      currentSetNumber: setNumber,
      restEndsAt: restEndsAt,
    );
    if (mounted) {
      setState(() => _restEndsAt = restEndsAt);
    }
  }

  Future<void> _extendRest(int seconds) async {
    final current = _restEndsAt ?? DateTime.now();
    final extended = current.add(Duration(seconds: seconds));
    await _activeRepository.updateProgress(restEndsAt: extended);
    if (mounted) {
      setState(() => _restEndsAt = extended);
    }
  }

  Future<void> _dismissRest() async {
    await _activeRepository.updateProgress(clearRest: true);
    if (mounted) {
      setState(() => _restEndsAt = null);
    }
  }

  Future<void> _finish() async {
    setState(() => _finishing = true);
    await _activeRepository.finish(widget.sessionId);
    if (mounted) {
      Navigator.of(context).popUntil((route) => route.isFirst);
    }
  }

  String _formatElapsed(Duration d) {
    final minutes = d.inMinutes.remainder(60).toString().padLeft(2, '0');
    final seconds = d.inSeconds.remainder(60).toString().padLeft(2, '0');
    if (d.inHours > 0) {
      return '${d.inHours}:$minutes:$seconds';
    }
    return '$minutes:$seconds';
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
      backgroundColor: AppColors.background,
      appBar: AppBar(
        titleSpacing: 0,
        title: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          mainAxisSize: MainAxisSize.min,
          children: [
            Text(
              'Entrenamiento en curso',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: AppColors.primary),
            ),
            Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                const Icon(Icons.timer, size: 14, color: AppColors.secondary),
                const SizedBox(width: 4),
                Text(
                  _formatElapsed(_elapsed),
                  style: Theme.of(
                    context,
                  ).textTheme.labelMedium?.copyWith(color: AppColors.secondary),
                ),
              ],
            ),
          ],
        ),
        actions: [
          Padding(
            padding: const EdgeInsets.only(right: AppSpacing.md),
            child: Material(
              color: AppColors.primary,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: _finishing ? null : _finish,
                child: Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: AppSpacing.md,
                    vertical: AppSpacing.sm,
                  ),
                  child: _finishing
                      ? const SizedBox(
                          height: 16,
                          width: 16,
                          child: CircularProgressIndicator(
                            strokeWidth: 2,
                            color: AppColors.onPrimary,
                          ),
                        )
                      : Text(
                          'Finalizar',
                          style: Theme.of(context).textTheme.labelLarge
                              ?.copyWith(color: AppColors.onPrimary),
                        ),
                ),
              ),
            ),
          ),
        ],
      ),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: _addExercise,
        icon: const Icon(Icons.add),
        label: const Text('Agregar ejercicio'),
      ),
      body: Stack(
        children: [
          Column(
            children: [
              if (_newRecords != null && _newRecords!.isNotEmpty)
                _RecordBanner(
                  records: _newRecords!,
                  onDismiss: () => setState(() => _newRecords = null),
                ),
              Expanded(
                child: exercisesInSession.isEmpty
                    ? const Center(
                        child: Text(
                          'Agregá un ejercicio para empezar a registrar series.',
                        ),
                      )
                    : ListView(
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          AppSpacing.md,
                          AppSpacing.md,
                          120,
                        ),
                        children: exercisesInSession.entries.map((entry) {
                          final exercise = entry.value;
                          final sets = grouped[entry.key]!;
                          return _ExerciseFocusCard(
                            exercise: exercise,
                            sets: sets,
                            onAddSet: () => _addSetFor(
                              exercise,
                              sets.length + 1,
                              initialWeight: sets.last.weightKg,
                              initialReps: sets.last.reps,
                            ),
                            onDeleteSet: (set) async {
                              await _repository.deleteSet(set.id);
                              _load();
                            },
                          );
                        }).toList(),
                      ),
              ),
            ],
          ),
          if (_restEndsAt != null)
            Positioned(
              bottom: 88,
              right: AppSpacing.md,
              child: RestTimerBanner(
                endsAt: _restEndsAt!,
                onDismiss: _dismissRest,
                onAddSeconds: _extendRest,
              ),
            ),
        ],
      ),
    );
  }
}

class _RecordBanner extends StatelessWidget {
  final List<ResolvedRecord> records;
  final VoidCallback onDismiss;

  const _RecordBanner({required this.records, required this.onDismiss});

  @override
  Widget build(BuildContext context) {
    return Container(
      margin: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.sm,
        AppSpacing.md,
        0,
      ),
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.secondaryContainer.withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(AppRadius.md),
        border: Border.all(
          color: AppColors.secondaryContainer.withValues(alpha: 0.3),
        ),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Container(
            padding: const EdgeInsets.all(8),
            decoration: const BoxDecoration(
              color: AppColors.secondaryContainer,
              shape: BoxShape.circle,
            ),
            child: const Icon(
              Icons.emoji_events,
              size: 20,
              color: AppColors.onSecondaryContainer,
            ),
          ),
          const SizedBox(width: AppSpacing.md),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  '¡Récord Personal!',
                  style: Theme.of(
                    context,
                  ).textTheme.labelLarge?.copyWith(color: AppColors.secondary),
                ),
                for (final r in records)
                  Text(
                    '${recordTypeLabels[r.recordType] ?? r.recordType}: ${r.value}'
                    '${r.previousValue != null ? ' (antes: ${r.previousValue})' : ''}',
                    style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
              ],
            ),
          ),
          IconButton(
            icon: const Icon(Icons.close, size: 18),
            color: AppColors.onSurfaceVariant,
            onPressed: onDismiss,
          ),
        ],
      ),
    );
  }
}

class _ExerciseFocusCard extends StatelessWidget {
  final ExerciseSummary exercise;
  final List<WorkoutSet> sets;
  final VoidCallback onAddSet;
  final ValueChanged<WorkoutSet> onDeleteSet;

  const _ExerciseFocusCard({
    required this.exercise,
    required this.sets,
    required this.onAddSet,
    required this.onDeleteSet,
  });

  @override
  Widget build(BuildContext context) {
    final color = muscleGroupColors[exercise.muscleGroup] ?? Colors.grey;
    return Container(
      margin: const EdgeInsets.only(bottom: AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.xl),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Row(
              children: [
                Container(
                  width: 44,
                  height: 44,
                  decoration: BoxDecoration(
                    color: color.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: Icon(Icons.fitness_center, color: color),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        exercise.name,
                        style: Theme.of(context).textTheme.titleMedium,
                      ),
                      Text(
                        exercise.muscleGroup,
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ],
                  ),
                ),
              ],
            ),
          ),
          Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: AppSpacing.sm,
            ),
            decoration: const BoxDecoration(
              border: Border(
                top: BorderSide(color: AppColors.outlineVariant),
                bottom: BorderSide(color: AppColors.outlineVariant),
              ),
            ),
            child: Row(
              children: [
                _headerCell(context, 'SET'),
                _headerCell(context, 'KG'),
                _headerCell(context, 'REPS'),
                _headerCell(context, 'RPE'),
                const SizedBox(width: 32),
              ],
            ),
          ),
          for (final set in sets)
            Padding(
              padding: const EdgeInsets.symmetric(
                horizontal: AppSpacing.md,
                vertical: AppSpacing.sm,
              ),
              child: Row(
                children: [
                  _cell(
                    context,
                    Container(
                      width: 26,
                      height: 26,
                      alignment: Alignment.center,
                      decoration: BoxDecoration(
                        color: set.isWarmup
                            ? Colors.transparent
                            : AppColors.secondaryContainer,
                        shape: BoxShape.circle,
                        border: set.isWarmup
                            ? Border.all(color: AppColors.outline)
                            : null,
                      ),
                      child: Text(
                        '${set.setNumber}',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(
                              color: set.isWarmup
                                  ? AppColors.outline
                                  : AppColors.onSecondaryContainer,
                            ),
                      ),
                    ),
                  ),
                  _cell(context, Text('${set.weightKg}')),
                  _cell(context, Text('${set.reps}')),
                  _cell(context, Text(set.rpe != null ? '${set.rpe}' : '—')),
                  SizedBox(
                    width: 32,
                    child: IconButton(
                      icon: const Icon(Icons.close, size: 16),
                      color: AppColors.onSurfaceVariant,
                      padding: EdgeInsets.zero,
                      onPressed: () => onDeleteSet(set),
                    ),
                  ),
                ],
              ),
            ),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Material(
              color: AppColors.surfaceContainerLow,
              borderRadius: BorderRadius.circular(AppRadius.md),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.md),
                onTap: onAddSet,
                child: Padding(
                  padding: const EdgeInsets.symmetric(vertical: AppSpacing.sm),
                  child: Row(
                    mainAxisAlignment: MainAxisAlignment.center,
                    children: [
                      const Icon(Icons.add, size: 18),
                      const SizedBox(width: AppSpacing.xs),
                      Text(
                        'Añadir serie',
                        style: Theme.of(context).textTheme.labelLarge,
                      ),
                    ],
                  ),
                ),
              ),
            ),
          ),
        ],
      ),
    );
  }

  Widget _headerCell(BuildContext context, String label) {
    return Expanded(
      child: Text(
        label,
        textAlign: TextAlign.center,
        style: Theme.of(
          context,
        ).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }

  Widget _cell(BuildContext context, Widget child) {
    return Expanded(child: Center(child: child));
  }
}
