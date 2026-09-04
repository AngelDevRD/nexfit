import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../core/units.dart';
import '../../models/workout.dart';
import '../../providers/weight_unit_provider.dart';
import '../../repositories/active_workout_repository.dart';
import '../../repositories/workout_repository.dart';
import '../workout/active_workout_screen.dart';
import 'session_detail_screen.dart';

const _pageSize = 20;

/// N5: siempre vive dentro de [EntrenarHubScreen] -- el hub provee
/// Scaffold/SafeArea, esta pantalla solo devuelve contenido.
class HistoryListScreen extends StatefulWidget {
  const HistoryListScreen({super.key});

  @override
  State<HistoryListScreen> createState() => _HistoryListScreenState();
}

class _HistoryListScreenState extends State<HistoryListScreen> {
  late final WorkoutRepository _repository;
  List<WorkoutSessionSummary> _sessions = [];
  bool _loading = true;
  bool _loadingMore = false;
  // U3: WorkoutRepository.history() filtra músculo/ejercicio en SQL (no en
  // Dart después de paginar), así que una página de exactamente _pageSize
  // sesiones filtradas siempre significa que puede haber más -- el offset
  // que se manda en _loadMore() (longitud de _sessions) cuenta lo mismo que
  // cuenta el offset de la consulta.
  bool _hasMore = true;
  String? _muscleGroup;
  DateTime? _dateFrom;
  DateTime? _dateTo;
  // Solo fecha, sin hora: la tarjeta muestra el día del entrenamiento
  // (10/07/2026), no "10/07/2026 00:00".
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _repository = context.read<WorkoutRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sessions = await _repository.history(
      muscleGroup: _muscleGroup,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      limit: _pageSize,
      offset: 0,
    );
    setState(() {
      _sessions = sessions;
      _hasMore = sessions.length == _pageSize;
      _loading = false;
    });
  }

  Future<void> _loadMore() async {
    if (_loadingMore || !_hasMore) return;
    setState(() => _loadingMore = true);
    final more = await _repository.history(
      muscleGroup: _muscleGroup,
      dateFrom: _dateFrom,
      dateTo: _dateTo,
      limit: _pageSize,
      offset: _sessions.length,
    );
    setState(() {
      _sessions = [..._sessions, ...more];
      _hasMore = more.length == _pageSize;
      _loadingMore = false;
    });
  }

  Future<void> _pickDateFrom() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateFrom ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    setState(() => _dateFrom = picked);
    _load();
  }

  Future<void> _pickDateTo() async {
    final picked = await showDatePicker(
      context: context,
      initialDate: _dateTo ?? DateTime.now(),
      firstDate: DateTime(2000),
      lastDate: DateTime.now(),
    );
    if (picked == null) return;
    // El fin del día elegido, para que incluya entrenamientos de esa fecha
    // (dateTo se compara contra startedAt, que trae hora).
    setState(
      () => _dateTo = DateTime(picked.year, picked.month, picked.day, 23, 59, 59),
    );
    _load();
  }

  void _clearDateFilter() {
    setState(() {
      _dateFrom = null;
      _dateTo = null;
    });
    _load();
  }

  /// U3: crea una sesión nueva con los mismos ejercicios/series de una ya
  /// hecha (mismo peso/reps como punto de partida, sin marcar completadas) y
  /// navega a cargarla. Solo puede haber un entrenamiento activo a la vez
  /// (mismo criterio que [StartWorkoutScreen]) -- si ya hay uno en curso, se
  /// avisa en vez de pisarlo.
  Future<void> _repeatWorkout(WorkoutSessionSummary session) async {
    final activeRepo = context.read<ActiveWorkoutRepository>();
    final activeId = await activeRepo.currentSessionId();
    if (!mounted) return;
    if (activeId != null) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(
          content: Text(
            'Ya tenés un entrenamiento en curso. Terminalo antes de repetir otro.',
          ),
        ),
      );
      return;
    }

    final original = await _repository.get(session.id);
    final newSession = await activeRepo.begin(title: session.title);
    final setNumberByExercise = <int, int>{};
    for (final set in original.sets) {
      final setNumber = (setNumberByExercise[set.exercise.id] ?? 0) + 1;
      setNumberByExercise[set.exercise.id] = setNumber;
      await _repository.addSet(newSession.id, {
        'exercise_id': set.exercise.id,
        'set_number': setNumber,
        'weight_kg': set.weightKg,
        'reps': set.reps,
        'rest_seconds': set.restSeconds,
        'techniques': set.techniques,
        'is_warmup': set.isWarmup,
        'completed': false,
      });
    }
    if (!mounted) return;
    Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(sessionId: newSession.id),
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final content = Column(
      children: [
        SizedBox(
              height: 44,
              child: ListView(
                scrollDirection: Axis.horizontal,
                padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
                children: [
                  _MuscleChip(
                    label: 'Todos',
                    color: AppColors.onSurfaceVariant,
                    selected: _muscleGroup == null,
                    onTap: () {
                      setState(() => _muscleGroup = null);
                      _load();
                    },
                  ),
                  ...muscleGroupColors.entries.map(
                    (entry) => _MuscleChip(
                      label: entry.key,
                      color: entry.value,
                      selected: _muscleGroup == entry.key,
                      onTap: () {
                        setState(() => _muscleGroup = entry.key);
                        _load();
                      },
                    ),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Padding(
              padding: const EdgeInsets.symmetric(horizontal: AppSpacing.md),
              child: Row(
                children: [
                  Expanded(
                    child: _DateFilterChip(
                      label: _dateFrom == null
                          ? 'Desde'
                          : _dateFormat.format(_dateFrom!),
                      active: _dateFrom != null,
                      onTap: _pickDateFrom,
                    ),
                  ),
                  const SizedBox(width: AppSpacing.sm),
                  Expanded(
                    child: _DateFilterChip(
                      label: _dateTo == null
                          ? 'Hasta'
                          : _dateFormat.format(_dateTo!),
                      active: _dateTo != null,
                      onTap: _pickDateTo,
                    ),
                  ),
                  if (_dateFrom != null || _dateTo != null)
                    IconButton(
                      icon: const Icon(Icons.close, size: 18),
                      tooltip: 'Quitar filtro de fecha',
                      onPressed: _clearDateFilter,
                    ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.sm),
            Expanded(
              child: _loading
                  ? const Center(child: CircularProgressIndicator())
                  : _sessions.isEmpty
                  ? RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        // Scrollable siempre para que el pull-to-refresh
                        // funcione tambien con el historial vacio.
                        physics: const AlwaysScrollableScrollPhysics(),
                        children: const [
                          SizedBox(height: 240),
                          Center(
                            child: Text(
                              'Sin entrenamientos registrados todavía.',
                            ),
                          ),
                        ],
                      ),
                    )
                  : RefreshIndicator(
                      onRefresh: _load,
                      child: ListView(
                        key: const Key('history-session-list'),
                        padding: const EdgeInsets.fromLTRB(
                          AppSpacing.md,
                          0,
                          AppSpacing.md,
                          AppSpacing.lg,
                        ),
                        children: [
                          for (final session in _sessions)
                            _SessionCard(
                              session: session,
                              dateFormat: _dateFormat,
                              onRepeat: () => _repeatWorkout(session),
                            ),
                          if (_hasMore)
                            Padding(
                              padding: const EdgeInsets.symmetric(
                                vertical: AppSpacing.md,
                              ),
                              child: Center(
                                child: _loadingMore
                                    ? const CircularProgressIndicator()
                                    : OutlinedButton(
                                        onPressed: _loadMore,
                                        child: const Text('Cargar más'),
                                      ),
                              ),
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

class _DateFilterChip extends StatelessWidget {
  final String label;
  final bool active;
  final VoidCallback onTap;

  const _DateFilterChip({
    required this.label,
    required this.active,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: active
          ? AppColors.primaryContainer.withValues(alpha: 0.3)
          : AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: 8,
          ),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(
                Icons.calendar_today,
                size: 14,
                color: active ? AppColors.primary : AppColors.onSurfaceVariant,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: active ? AppColors.primary : AppColors.onSurfaceVariant,
                  fontWeight: FontWeight.w600,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _Metric extends StatelessWidget {
  final String icon;
  final String label;

  const _Metric({required this.icon, required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: AppSpacing.sm, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainerHigh,
        borderRadius: BorderRadius.circular(AppRadius.full),
      ),
      child: Text(
        '$icon $label',
        style: Theme.of(
          context,
        ).textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant),
      ),
    );
  }
}

class _MuscleChip extends StatelessWidget {
  final String label;
  final Color color;
  final bool selected;
  final VoidCallback onTap;

  const _MuscleChip({
    required this.label,
    required this.color,
    required this.selected,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(horizontal: 4, vertical: 6),
      child: Material(
        color: selected
            ? color.withValues(alpha: 0.15)
            : AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.full),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.full),
          onTap: onTap,
          child: Container(
            padding: const EdgeInsets.symmetric(
              horizontal: AppSpacing.md,
              vertical: 8,
            ),
            decoration: BoxDecoration(
              borderRadius: BorderRadius.circular(AppRadius.full),
              border: Border.all(
                color: selected
                    ? color.withValues(alpha: 0.4)
                    : AppColors.outlineVariant,
              ),
            ),
            child: Text(
              label,
              style: Theme.of(context).textTheme.labelMedium?.copyWith(
                color: selected ? color : AppColors.onSurfaceVariant,
                fontWeight: FontWeight.w600,
              ),
            ),
          ),
        ),
      ),
    );
  }
}

class _SessionCard extends StatelessWidget {
  final WorkoutSessionSummary session;
  final DateFormat dateFormat;
  final VoidCallback onRepeat;

  const _SessionCard({
    required this.session,
    required this.dateFormat,
    required this.onRepeat,
  });

  @override
  Widget build(BuildContext context) {
    final finished = session.endedAt != null;
    final weightUnit = context.watch<WeightUnitProvider>().unit;
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: InkWell(
          borderRadius: BorderRadius.circular(AppRadius.lg),
          onTap: () => Navigator.of(context).push(
            MaterialPageRoute(
              builder: (_) => SessionDetailScreen(sessionId: session.id),
            ),
          ),
          child: Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Row(
                  children: [
                    Icon(Icons.calendar_today, size: 14, color: AppColors.onSurfaceVariant),
                    const SizedBox(width: 6),
                    Expanded(
                      child: Text(
                        dateFormat.format(session.startedAt.toLocal()),
                        style: Theme.of(context).textTheme.labelSmall
                            ?.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                    ),
                    if (!finished)
                      Container(
                        padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
                        decoration: BoxDecoration(
                          color: AppColors.primaryContainer,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          'En curso',
                          style: Theme.of(context).textTheme.labelSmall?.copyWith(
                            color: AppColors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      )
                    else
                      const Icon(Icons.check_circle, color: AppColors.secondary, size: 20),
                  ],
                ),
                const SizedBox(height: 4),
                Text(
                  session.title?.isNotEmpty == true
                      ? session.title!
                      : 'Entrenamiento',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(fontWeight: FontWeight.bold),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
                const SizedBox(height: AppSpacing.sm),
                if (finished)
                  Wrap(
                    spacing: AppSpacing.xs,
                    runSpacing: 4,
                    children: [
                      _Metric(
                        icon: '⏱',
                        label: formatWorkoutDuration(session.duration),
                      ),
                      _Metric(
                        icon: '🏋',
                        label: formatWeight(
                          session.totalVolumeKg,
                          weightUnit,
                          decimals: 0,
                        ),
                      ),
                      _Metric(icon: '💪', label: '${session.exerciseCount} ej.'),
                      _Metric(icon: '📊', label: '${session.setCount} series'),
                    ],
                  ),
                const SizedBox(height: AppSpacing.sm),
                if (!finished)
                  SizedBox(
                    width: double.infinity,
                    child: FilledButton(
                      onPressed: () => Navigator.of(context).push(
                        MaterialPageRoute(
                          builder: (_) => SessionDetailScreen(sessionId: session.id),
                        ),
                      ),
                      child: const Text('Continuar sesión'),
                    ),
                  )
                else
                  Row(
                    children: [
                      TextButton.icon(
                        onPressed: onRepeat,
                        icon: const Icon(Icons.repeat, size: 16),
                        label: const Text('Repetir'),
                        style: TextButton.styleFrom(
                          padding: EdgeInsets.zero,
                          minimumSize: const Size(0, 0),
                          tapTargetSize: MaterialTapTargetSize.shrinkWrap,
                        ),
                      ),
                      const Spacer(),
                      Text(
                        'Ver detalles',
                        style: Theme.of(context).textTheme.labelMedium
                            ?.copyWith(color: AppColors.onSurfaceVariant),
                      ),
                      const SizedBox(width: 4),
                      const Icon(
                        Icons.arrow_forward,
                        size: 16,
                        color: AppColors.onSurfaceVariant,
                      ),
                    ],
                  ),
              ],
            ),
          ),
        ),
      ),
    );
  }
}
