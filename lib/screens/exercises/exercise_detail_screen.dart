import 'package:fl_chart/fl_chart.dart';
import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/exercise_animation/animation_repository.dart';
import '../../core/exercise_animation/exercise_animation.dart';
import '../../core/exercise_animation/widgets/exercise_animation_viewer.dart';
import '../../core/feature_flags.dart';
import '../../core/theme.dart';
import '../../core/units.dart';
import '../../features/exercise_3d/exercise_3d_view.dart';
import '../../features/pose/pose_analysis_screen.dart';
import '../../models/exercise.dart';
import '../../models/stats.dart';
import '../../models/workout.dart';
import '../../providers/weight_unit_provider.dart';
import '../../repositories/active_workout_repository.dart';
import '../../repositories/exercise_repository.dart';
import '../../repositories/stats_repository.dart';
import '../../repositories/workout_repository.dart';
import '../../widgets/empty_state.dart';
import '../../widgets/pill_tab_bar.dart';
import '../workout/active_workout_screen.dart';
import 'exercise_form_screen.dart';

class ExerciseDetailScreen extends StatefulWidget {
  final int exerciseId;

  const ExerciseDetailScreen({super.key, required this.exerciseId});

  @override
  State<ExerciseDetailScreen> createState() => _ExerciseDetailScreenState();
}

class _ExerciseDetailScreenState extends State<ExerciseDetailScreen>
    with SingleTickerProviderStateMixin {
  Exercise? _exercise;
  ExerciseAnimation? _animation;
  String? _error;
  late final TabController _tabController;

  // U2/A1: el detalle deja de ser pura enciclopedia -- PR vigente, última vez
  // entrenado, evolución de peso máximo e historial completo por sesión, con
  // lo que ya guarda la base (WorkoutRepository/StatsRepository), sin
  // duplicar el cálculo. A1 separa esto de la enciclopedia en pestañas
  // propias ("Resumen"/"Historial") en vez de un solo ListView mezclado.
  ExercisePersonalRecords? _records;
  ExerciseLastSession? _lastSession;
  List<ExerciseProgressEntry> _progress = [];
  List<ExerciseSessionEntry> _sessionHistory = [];
  bool _loadingHistory = true;
  bool _startingWorkout = false;
  bool _has3DModel = false;

  @override
  void initState() {
    super.initState();
    _tabController = TabController(length: 3, vsync: this);
    final animationRepository = context.read<AnimationRepository>();
    context
        .read<ExerciseRepository>()
        .get(widget.exerciseId)
        .then((e) {
          setState(() => _exercise = e);
          exercise3DModelExists(
            e.slug,
          ).then((exists) => mounted ? setState(() => _has3DModel = exists) : null);
          return animationRepository.getAnimation(e.slug);
        })
        .then((a) => setState(() => _animation = a))
        .catchError((e) => setState(() => _error = e.toString()));
    _loadHistory();
  }

  @override
  void dispose() {
    _tabController.dispose();
    super.dispose();
  }

  Future<void> _loadHistory() async {
    final statsRepository = context.read<StatsRepository>();
    final workoutRepository = context.read<WorkoutRepository>();
    final results = await Future.wait([
      statsRepository.currentRecordsFor(widget.exerciseId),
      workoutRepository.lastSessionFor(widget.exerciseId),
      statsRepository.exerciseProgress(widget.exerciseId),
      workoutRepository.exerciseHistory(widget.exerciseId),
    ]);
    if (!mounted) return;
    setState(() {
      _records = results[0] as ExercisePersonalRecords;
      _lastSession = results[1] as ExerciseLastSession?;
      _progress = results[2] as List<ExerciseProgressEntry>;
      _sessionHistory = results[3] as List<ExerciseSessionEntry>;
      _loadingHistory = false;
    });
  }

  /// Agrega este ejercicio al entrenamiento en curso, o arranca uno libre si
  /// no hay ninguno activo (solo puede existir uno a la vez -- mismo criterio
  /// que [StartWorkoutScreen]), y navega directo a cargarlo.
  Future<void> _startWorkout() async {
    if (_startingWorkout || _exercise == null) return;
    setState(() => _startingWorkout = true);
    final activeRepo = context.read<ActiveWorkoutRepository>();
    final workoutRepo = context.read<WorkoutRepository>();
    final exercise = _exercise!;

    var sessionId = await activeRepo.currentSessionId();
    if (sessionId == null) {
      final session = await activeRepo.begin();
      sessionId = session.id;
    }
    final last = await workoutRepo.lastSetFor(
      exercise.id,
      excludeSessionId: sessionId,
    );
    await workoutRepo.addSet(sessionId, {
      'exercise_id': exercise.id,
      'set_number': 1,
      'weight_kg': last?.weightKg ?? 0,
      'reps': last?.reps ?? 0,
      'rest_seconds': 90,
      'techniques': const [],
      'is_warmup': false,
      'completed': false,
    });
    if (!mounted) return;
    await Navigator.of(context).push(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(sessionId: sessionId!),
      ),
    );
    if (mounted) setState(() => _startingWorkout = false);
  }

  /// E1: solo para ejercicios propios (`ExerciseRepository.isCustomExercise`)
  /// -- el catálogo semilla no se edita desde la app.
  Future<void> _edit() async {
    final updated = await Navigator.of(context).push<Exercise>(
      MaterialPageRoute(
        builder: (_) => ExerciseFormScreen(existing: _exercise),
      ),
    );
    if (updated != null && mounted) setState(() => _exercise = updated);
  }

  /// E1: si el ejercicio tiene series registradas, avisa y no borra --
  /// eliminarlo rompería el historial de entrenamientos ya guardado.
  Future<void> _delete() async {
    final repository = context.read<ExerciseRepository>();
    final hasLoggedSets = await repository.hasLoggedSets(widget.exerciseId);
    if (!mounted) return;
    if (hasLoggedSets) {
      await showDialog<void>(
        context: context,
        builder: (context) => AlertDialog(
          title: const Text('No se puede eliminar'),
          content: const Text(
            'Este ejercicio tiene series registradas en tu historial. '
            'Eliminarlo lo rompería, así que se mantiene en el catálogo.',
          ),
          actions: [
            TextButton(
              onPressed: () => Navigator.of(context).pop(),
              child: const Text('Entendido'),
            ),
          ],
        ),
      );
      return;
    }
    final confirm = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Eliminar ejercicio'),
        content: const Text('¿Seguro que querés eliminar este ejercicio?'),
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
    if (confirm != true || !mounted) return;
    await repository.deleteExercise(widget.exerciseId);
    if (mounted) Navigator.of(context).pop();
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

    // A1: la pantalla deja de ser un único ListView que mezcla datos del
    // usuario (consultados en cada entrenamiento) con la enciclopedia
    // (leída una vez) -- tres pestañas con el mismo `PillTabBar` que ya usan
    // los hubs (N1 no aplica: esta pantalla se pushea, no vive dentro de
    // otro hub con su propio nivel de pestañas).
    //
    // El encabezado (animación + nombre + pills + botón "Empezar
    // entrenamiento...") va en un `NestedScrollView` en vez de quedar FIJO
    // en un `Column`: fijo, competía por alto con el contenido de la pestaña
    // activa y a 320dp+200% de escala de texto (D4) no entraba ni el
    // encabezado solo. Con `NestedScrollView` el encabezado scrollea junto
    // con el contenido de la pestaña -- solo el `PillTabBar` queda fijo
    // (`SliverPersistentHeader(pinned: true)`), así deja de competir por
    // alto sin importar cuánto crezca el texto.
    final isCustom = ExerciseRepository.isCustomExercise(exercise.id);
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(
        title: Text(exercise.name),
        actions: isCustom
            ? [
                IconButton(
                  icon: const Icon(Icons.edit_outlined),
                  onPressed: _edit,
                ),
                IconButton(
                  icon: const Icon(Icons.delete_outline),
                  onPressed: _delete,
                ),
              ]
            : null,
      ),
      body: NestedScrollView(
        headerSliverBuilder: (context, innerBoxIsScrolled) => [
          SliverToBoxAdapter(
            child: Padding(
              key: const Key('exercise-detail-header'),
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                0,
              ),
              child: Column(
                children: [
                  // A5/retoque: mismo criterio que la grilla de métricas del
                  // resumen -- el GIF tiene tamaño fijo, así que a lo ancho
                  // el bloque se acota y centra en vez de estirarse (si no,
                  // en pantalla ancha queda una caja enorme casi vacía con
                  // las píldoras flotando en las esquinas).
                  Center(
                    child: ConstrainedBox(
                      key: const Key('exercise-detail-media-block'),
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: ClipRRect(
                        borderRadius: BorderRadius.circular(AppRadius.lg),
                        child: SizedBox(
                          height: 180,
                          child: Stack(
                            children: [
                              Positioned.fill(
                                child: Container(
                                  color: AppColors.surfaceContainer,
                                  child: _animation == null
                                      ? const Center(
                                          child: CircularProgressIndicator(),
                                        )
                                      : ExerciseAnimationViewer(
                                          animation: _animation!,
                                          showAttribution: false,
                                        ),
                                ),
                              ),
                              Positioned(
                                left: AppSpacing.sm,
                                bottom: AppSpacing.sm,
                                child: _MediaPill(
                                  icon: Icons.play_circle_outline,
                                  label: 'Animación',
                                ),
                              ),
                              if (_has3DModel)
                                Positioned(
                                  right: AppSpacing.sm,
                                  bottom: AppSpacing.sm,
                                  child: _MediaPill(
                                    icon: Icons.view_in_ar_outlined,
                                    label: 'Ver en 3D',
                                    filled: true,
                                    onTap: () => Navigator.of(context).push(
                                      MaterialPageRoute(
                                        builder: (_) => Exercise3DView(
                                          slug: exercise.slug,
                                          exerciseName: exercise.name,
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
                  ),
                  const SizedBox(height: AppSpacing.sm),
                  // Retoque: el nombre ya está en el AppBar -- repetirlo acá
                  // era ruido, no jerarquía.
                  Wrap(
                    spacing: AppSpacing.sm,
                    runSpacing: 4,
                    alignment: WrapAlignment.center,
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
                  const SizedBox(height: AppSpacing.sm),
                  // Retoque: mismo acotado que el bloque de medios -- en
                  // pantalla ancha el botón full-bleed quedaba como una
                  // barra gigante.
                  Center(
                    child: ConstrainedBox(
                      key: const Key('exercise-detail-start-button-block'),
                      constraints: const BoxConstraints(maxWidth: 560),
                      child: SizedBox(
                        width: double.infinity,
                        child: FilledButton.icon(
                          onPressed: _startingWorkout ? null : _startWorkout,
                          icon: _startingWorkout
                              ? const SizedBox(
                                  height: 16,
                                  width: 16,
                                  child: CircularProgressIndicator(
                                    strokeWidth: 2,
                                  ),
                                )
                              : const Icon(Icons.play_arrow),
                          label: const Text(
                            'Empezar entrenamiento con este ejercicio',
                          ),
                        ),
                      ),
                    ),
                  ),
                  const SizedBox(height: AppSpacing.sm),
                ],
              ),
            ),
          ),
          SliverPersistentHeader(
            pinned: true,
            delegate: _PinnedTabBarDelegate(
              key: const Key('exercise-detail-pilltabbar'),
              controller: _tabController,
            ),
          ),
        ],
        body: TabBarView(
          controller: _tabController,
          children: [
            _ResumenTab(
              loading: _loadingHistory,
              records: _records,
              lastSession: _lastSession,
              progress: _progress,
            ),
            _HistorialTab(loading: _loadingHistory, entries: _sessionHistory),
            _GuiaTab(exercise: exercise, color: color, animation: _animation),
          ],
        ),
      ),
    );
  }
}

/// A1/D4: `PillTabBar` como único elemento fijo del encabezado -- el resto
/// (animación, nombre, pills, botón "Empezar entrenamiento") scrollea con el
/// `NestedScrollView` de arriba. `min`/`maxExtent` iguales (altura fija, sin
/// colapso) => no hace falta `SliverOverlapAbsorber`/`SliverOverlapInjector`
/// (esos resuelven el caso de un header que se colapsa parcialmente).
class _PinnedTabBarDelegate extends SliverPersistentHeaderDelegate {
  final Key key;
  final TabController controller;

  _PinnedTabBarDelegate({required this.key, required this.controller});

  @override
  double get minExtent => const PillTabBar(tabs: []).preferredSize.height;

  @override
  double get maxExtent => minExtent;

  @override
  Widget build(
    BuildContext context,
    double shrinkOffset,
    bool overlapsContent,
  ) {
    return ColoredBox(
      color: AppColors.background,
      child: PillTabBar(
        key: key,
        controller: controller,
        tabs: const [
          Tab(text: 'Resumen'),
          Tab(text: 'Historial'),
          Tab(text: 'Guía'),
        ],
      ),
    );
  }

  @override
  bool shouldRebuild(covariant _PinnedTabBarDelegate oldDelegate) =>
      controller != oldDelegate.controller;
}

class _MediaPill extends StatelessWidget {
  final IconData icon;
  final String label;
  final bool filled;
  final VoidCallback? onTap;

  const _MediaPill({
    required this.icon,
    required this.label,
    this.filled = false,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: filled
          ? AppColors.primaryContainer
          : Colors.black.withValues(alpha: 0.45),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
          child: Row(
            mainAxisSize: MainAxisSize.min,
            children: [
              Icon(
                icon,
                size: 16,
                color: filled ? AppColors.onPrimaryContainer : Colors.white,
              ),
              const SizedBox(width: 6),
              Text(
                label,
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: filled ? AppColors.onPrimaryContainer : Colors.white,
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

/// A1, pestaña "Resumen" -- lo que se consulta en cada entrenamiento: PR
/// vigente, última vez entrenado (peso × reps por serie) y evolución de peso
/// máximo. Antes (U2) esto vivía sepultado en un ListView único entre la
/// descripción y seis secciones de enciclopedia; ahora tiene pestaña propia.
class _ResumenTab extends StatelessWidget {
  final bool loading;
  final ExercisePersonalRecords? records;
  final ExerciseLastSession? lastSession;
  final List<ExerciseProgressEntry> progress;

  const _ResumenTab({
    required this.loading,
    required this.records,
    required this.lastSession,
    required this.progress,
  });

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }

    final hasRecords = records != null && !records!.isEmpty;
    if (!hasRecords && lastSession == null) {
      return const Center(
        child: EmptyState(
          icon: Icons.query_stats,
          message: 'Todavía no entrenaste este ejercicio.',
        ),
      );
    }

    final weightUnit = context.watch<WeightUnitProvider>().unit;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
        if (hasRecords)
          Row(
            children: [
              if (records!.maxWeightKg != null)
                Expanded(
                  child: _RecordTile(
                    label: 'Récord de peso',
                    value: formatWeight(records!.maxWeightKg!, weightUnit),
                    date: records!.maxWeightAt != null
                        ? dateFormat.format(records!.maxWeightAt!)
                        : null,
                  ),
                ),
              if (records!.maxWeightKg != null && records!.maxReps != null)
                const SizedBox(width: AppSpacing.sm),
              if (records!.maxReps != null)
                Expanded(
                  child: _RecordTile(
                    label: 'Récord de reps',
                    value: '${records!.maxReps} reps',
                    date: records!.maxRepsAt != null
                        ? dateFormat.format(records!.maxRepsAt!)
                        : null,
                  ),
                ),
            ],
          ),
        if (hasRecords && lastSession != null)
          const SizedBox(height: AppSpacing.sm),
        if (lastSession != null)
          Container(
            padding: const EdgeInsets.all(AppSpacing.md),
            decoration: BoxDecoration(
              color: AppColors.surfaceContainer,
              borderRadius: BorderRadius.circular(AppRadius.lg),
            ),
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(
                  'Última vez: ${dateFormat.format(lastSession!.startedAt.toLocal())}',
                  style: Theme.of(context).textTheme.labelMedium?.copyWith(
                    color: AppColors.onSurfaceVariant,
                  ),
                ),
                const SizedBox(height: AppSpacing.sm),
                Wrap(
                  spacing: AppSpacing.xs,
                  runSpacing: AppSpacing.xs,
                  children: [
                    for (final set in lastSession!.sets)
                      Container(
                        padding: const EdgeInsets.symmetric(
                          horizontal: AppSpacing.sm,
                          vertical: 6,
                        ),
                        decoration: BoxDecoration(
                          color: AppColors.surfaceContainerHigh,
                          borderRadius: BorderRadius.circular(AppRadius.full),
                        ),
                        child: Text(
                          '${formatWeight(set.weightKg, weightUnit)} × ${set.reps}',
                          style: Theme.of(context).textTheme.labelMedium,
                        ),
                      ),
                  ],
                ),
              ],
            ),
          ),
        if (progress.length >= 2) ...[
          const SizedBox(height: AppSpacing.md),
          Text(
            'Evolución del peso máximo',
            style: Theme.of(context).textTheme.labelMedium?.copyWith(
              color: AppColors.onSurfaceVariant,
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          SizedBox(
            height: 140,
            child: Container(
              padding: const EdgeInsets.fromLTRB(
                4,
                AppSpacing.sm,
                AppSpacing.sm,
                4,
              ),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: LineChart(
                LineChartData(
                  titlesData: const FlTitlesData(
                    rightTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    topTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    leftTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                    bottomTitles: AxisTitles(
                      sideTitles: SideTitles(showTitles: false),
                    ),
                  ),
                  gridData: const FlGridData(show: false),
                  borderData: FlBorderData(show: false),
                  lineBarsData: [
                    LineChartBarData(
                      spots: progress
                          .asMap()
                          .entries
                          .map(
                            (e) => FlSpot(
                              e.key.toDouble(),
                              kgToDisplay(e.value.maxWeightKg, weightUnit),
                            ),
                          )
                          .toList(),
                      isCurved: true,
                      color: AppColors.secondary,
                      barWidth: 3,
                      dotData: const FlDotData(show: true),
                      belowBarData: BarAreaData(
                        show: true,
                        color: AppColors.secondary.withValues(alpha: 0.1),
                      ),
                    ),
                  ],
                ),
              ),
            ),
          ),
        ],
      ],
    );
  }
}

/// A1, pestaña "Historial" -- todas las sesiones donde se entrenó este
/// ejercicio, serie por serie, más reciente primero. No existía en ningún
/// lado antes (el hub de Historial general no filtra por ejercicio en la
/// UI); usa `WorkoutRepository.exerciseHistory()`, filtrado en SQL.
class _HistorialTab extends StatelessWidget {
  final bool loading;
  final List<ExerciseSessionEntry> entries;

  const _HistorialTab({required this.loading, required this.entries});

  @override
  Widget build(BuildContext context) {
    if (loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (entries.isEmpty) {
      return const Center(
        child: EmptyState(
          icon: Icons.history,
          message: 'Todavía no entrenaste este ejercicio.',
        ),
      );
    }

    final weightUnit = context.watch<WeightUnitProvider>().unit;
    final dateFormat = DateFormat('dd/MM/yyyy');

    return ListView.separated(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      itemCount: entries.length,
      separatorBuilder: (_, _) => const SizedBox(height: AppSpacing.sm),
      itemBuilder: (context, index) {
        final entry = entries[index];
        return Container(
          padding: const EdgeInsets.all(AppSpacing.md),
          decoration: BoxDecoration(
            color: AppColors.surfaceContainer,
            borderRadius: BorderRadius.circular(AppRadius.lg),
          ),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              Text(
                dateFormat.format(entry.startedAt.toLocal()),
                style: Theme.of(context).textTheme.labelMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
              const SizedBox(height: AppSpacing.sm),
              Wrap(
                spacing: AppSpacing.xs,
                runSpacing: AppSpacing.xs,
                children: [
                  for (final set in entry.sets)
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.sm,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        color: AppColors.surfaceContainerHigh,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                      child: Text(
                        '${formatWeight(set.weightKg, weightUnit)} × ${set.reps}',
                        style: Theme.of(context).textTheme.labelMedium,
                      ),
                    ),
                ],
              ),
            ],
          ),
        );
      },
    );
  }
}

/// A1, pestaña "Guía" -- la enciclopedia (descripción, músculos, equipo,
/// instrucciones, consejos, errores comunes, variantes, beneficios), tal
/// cual estaba antes de separar las pestañas -- se lee una vez, no en cada
/// entrenamiento, así que no compite más por espacio con "Resumen".
class _GuiaTab extends StatelessWidget {
  final Exercise exercise;
  final Color color;
  final ExerciseAnimation? animation;

  const _GuiaTab({
    required this.exercise,
    required this.color,
    required this.animation,
  });

  @override
  Widget build(BuildContext context) {
    // E1: un ejercicio propio nunca tiene contenido de guía -- el formulario
    // de alta a propósito no lo pide (ver `ExerciseFormScreen`). Mostrar acá
    // las mismas secciones vacías (Instrucciones sin ítems, etc.) sería una
    // pantalla en blanco con títulos; el EmptyState ya existente deja claro
    // que no hay nada que ver, no que algo falló en cargar.
    if (ExerciseRepository.isCustomExercise(exercise.id)) {
      return const Center(
        child: EmptyState(
          icon: Icons.menu_book_outlined,
          message: 'Este ejercicio no tiene guía -- vos lo creaste.',
        ),
      );
    }
    return ListView(
      padding: const EdgeInsets.fromLTRB(
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.md,
        AppSpacing.xl,
      ),
      children: [
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
        if (kShowPoseAnalysisEntryPoints) ...[
          const SizedBox(height: AppSpacing.sm),
          FilledButton.icon(
            onPressed: () => Navigator.of(context).push(
              MaterialPageRoute(
                builder: (_) =>
                    PoseAnalysisScreen(initialExerciseName: exercise.name),
              ),
            ),
            icon: const Icon(Icons.videocam_outlined),
            label: const Text('Analizar técnica'),
          ),
        ],
        if (animation?.attribution != null) ...[
          const SizedBox(height: AppSpacing.lg),
          Text(
            animation!.attribution!,
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ],
    );
  }
}

class _RecordTile extends StatelessWidget {
  final String label;
  final String value;
  final String? date;

  const _RecordTile({required this.label, required this.value, this.date});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: const Border(
          left: BorderSide(color: AppColors.primary, width: 4),
        ),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            label,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
          ),
          const SizedBox(height: 4),
          Text(
            value,
            style: Theme.of(context).textTheme.titleMedium?.copyWith(
              fontWeight: FontWeight.bold,
              color: AppColors.primary,
            ),
          ),
          if (date != null)
            Text(
              date!,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
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
