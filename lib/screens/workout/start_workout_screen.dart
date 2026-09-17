import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/routine.dart';
import '../../repositories/active_workout_repository.dart';
import '../../repositories/routine_repository.dart';
import '../../repositories/workout_repository.dart';
import 'active_workout_screen.dart';

enum _ActiveWorkoutAction { resume, discard, finish, cancel }

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
    _init();
  }

  Future<void> _init() async {
    final activeWorkoutRepository = context.read<ActiveWorkoutRepository>();
    final routineRepository = context.read<RoutineRepository>();
    final workoutRepository = context.read<WorkoutRepository>();

    // Si ya hay un entrenamiento activo (la app se cerró a mitad de una
    // sesión), hay que decidir qué hacer con él en vez de resumirlo en
    // silencio (A1): puede ser uno recién minimizado (seguirlo tiene
    // sentido) o uno abandonado hace días (bloquearía para siempre empezar
    // uno nuevo si no se ofrece descartarlo).
    final activeId = await activeWorkoutRepository.currentSessionId();
    if (!mounted) return;
    if (activeId != null) {
      final activeSession = await workoutRepository.get(activeId);
      if (!mounted) return;
      final staleId = await activeWorkoutRepository.staleSessionId();
      final openFor = staleId != null
          ? DateTime.now().difference(activeSession.startedAt)
          : null;
      if (!mounted) return;
      final action = await _showActiveWorkoutDialog(
        openFor,
        activeSession.sets.length,
      );
      if (!mounted) return;
      switch (action) {
        case _ActiveWorkoutAction.resume:
          Navigator.of(context).pushReplacement(
            MaterialPageRoute(
              builder: (_) => ActiveWorkoutScreen(sessionId: activeId),
            ),
          );
          return;
        case _ActiveWorkoutAction.discard:
          if (!await _runOrWarn(
            () => activeWorkoutRepository.discard(activeId),
            'No se pudo descartar el entrenamiento. Probá de nuevo.',
          )) {
            return;
          }
          break;
        case _ActiveWorkoutAction.finish:
          if (!await _runOrWarn(
            () => activeWorkoutRepository.finishAbandoned(activeId),
            'No se pudo finalizar el entrenamiento. Probá de nuevo.',
          )) {
            return;
          }
          break;
        case _ActiveWorkoutAction.cancel:
        case null:
          Navigator.of(context).pop();
          return;
      }
    }

    final routines = await routineRepository.list();
    if (!mounted) return;
    setState(() {
      _routines = routines;
      _loading = false;
    });
  }

  /// T-H7: "Descartar" es destructivo -- si el usuario lo elige en el
  /// diálogo de opciones, pide una segunda confirmación con la cantidad de
  /// series que se van a perder antes de borrar nada. "Volver" no borra y
  /// vuelve a mostrar el diálogo de opciones.
  Future<_ActiveWorkoutAction?> _showActiveWorkoutDialog(
    Duration? openFor,
    int setsCount,
  ) async {
    while (true) {
      final action = await _showActiveWorkoutOptionsDialog(openFor);
      if (!mounted || action != _ActiveWorkoutAction.discard) return action;

      final confirmed = await _confirmDiscard(setsCount);
      if (!mounted) return null;
      if (confirmed) return _ActiveWorkoutAction.discard;
      // "Volver": el while vuelve a mostrar las opciones.
    }
  }

  Future<_ActiveWorkoutAction?> _showActiveWorkoutOptionsDialog(
    Duration? openFor,
  ) {
    final hours = openFor?.inHours;
    return showDialog<_ActiveWorkoutAction>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('Entrenamiento en curso'),
        content: Text(
          hours != null
              ? 'Tenés un entrenamiento abierto hace $hours horas. '
                    '¿Qué querés hacer?'
              : 'Ya tenés un entrenamiento en curso. ¿Qué querés hacer?',
        ),
        actionsOverflowDirection: VerticalDirection.down,
        actionsOverflowButtonSpacing: AppSpacing.xs,
        actions: [
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_ActiveWorkoutAction.cancel),
            child: const Text('Cancelar'),
          ),
          TextButton(
            onPressed: () =>
                Navigator.of(context).pop(_ActiveWorkoutAction.discard),
            child: const Text('Descartar y empezar uno nuevo'),
          ),
          FilledButton.tonal(
            onPressed: () =>
                Navigator.of(context).pop(_ActiveWorkoutAction.finish),
            child: const Text('Finalizar y guardar'),
          ),
          FilledButton(
            onPressed: () =>
                Navigator.of(context).pop(_ActiveWorkoutAction.resume),
            child: const Text('Continuar entrenamiento'),
          ),
        ],
      ),
    );
  }

  static String _seriesLabel(int count) {
    if (count == 0) return '0 series';
    if (count == 1) return '1 serie';
    return '$count series';
  }

  Future<bool> _confirmDiscard(int setsCount) async {
    final confirmed = await showDialog<bool>(
      context: context,
      barrierDismissible: false,
      builder: (context) => AlertDialog(
        backgroundColor: AppColors.surfaceContainer,
        title: const Text('¿Descartar entrenamiento?'),
        content: Text(
          'Se van a borrar ${_seriesLabel(setsCount)} y no vas a poder '
          'recuperarlas.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.of(context).pop(false),
            child: const Text('Volver'),
          ),
          FilledButton(
            onPressed: () => Navigator.of(context).pop(true),
            child: const Text('Descartar'),
          ),
        ],
      ),
    );
    return confirmed ?? false;
  }

  /// T-H7: si [action] lanza, avisa con un mensaje amigable (nunca
  /// `e.toString()` crudo) en vez de dejar la pantalla colgada, y cierra
  /// esta pantalla -- no hay un estado intermedio seguro para seguir
  /// ofreciendo opciones sobre un entrenamiento cuyo descarte/cierre falló a
  /// mitad de camino. Devuelve `true` si [action] terminó bien.
  Future<bool> _runOrWarn(
    Future<void> Function() action,
    String friendlyMessage,
  ) async {
    try {
      await action();
      return true;
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(
          context,
        ).showSnackBar(SnackBar(content: Text(friendlyMessage)));
        Navigator.of(context).pop();
      }
      return false;
    }
  }

  /// C4: si hay rutina, resuelve qué día entrenar (el único que tenga, o
  /// preguntando si hay varios) y precarga sus ejercicios con los objetivos
  /// de la rutina -- series, reps sugeridas y, crucial, el descanso
  /// configurado para cada ejercicio (antes se ignoraba y siempre arrancaba
  /// en 90s sin importar lo que el usuario haya puesto en el constructor).
  Future<void> _start({int? routineId, String? title}) async {
    setState(() => _starting = true);

    try {
      RoutineDay? day;
      if (routineId != null) {
        final routine = await context.read<RoutineRepository>().get(routineId);
        if (!mounted) return;
        if (routine.days.isNotEmpty) {
          day = routine.days.length == 1
              ? routine.days.first
              : await _pickDay(routine.days);
          if (day == null) {
            setState(() => _starting = false);
            return;
          }
        }
      }
      if (!mounted) return;

      final session = await context.read<ActiveWorkoutRepository>().begin(
        routineId: routineId,
        routineDayId: day?.id,
        title: title ?? day?.name,
      );

      if (day != null) {
        await _preloadRoutineDay(session.id, day);
      }

      if (!mounted) return;
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActiveWorkoutScreen(sessionId: session.id),
        ),
      );
    } on StateError catch (e) {
      // A1: `begin()` lanza si ya hay una sesión activa -- puede pasar si
      // otro entrenamiento se creó entre que esta pantalla cargó y el toque
      // en "Entrenamiento libre"/una rutina (p. ej. dos pestañas). Antes la
      // excepción escapaba sin capturar y el botón quedaba cargando para
      // siempre.
      if (!mounted) return;
      setState(() => _starting = false);
      ScaffoldMessenger.of(
        context,
      ).showSnackBar(SnackBar(content: Text(e.message.toString())));
    }
  }

  Future<RoutineDay?> _pickDay(List<RoutineDay> days) {
    return showModalBottomSheet<RoutineDay>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(AppRadius.lg)),
      ),
      builder: (context) => SafeArea(
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Text(
                '¿Qué día entrenás?',
                style: Theme.of(context).textTheme.titleMedium,
              ),
            ),
            for (final day in days)
              ListTile(
                leading: const Icon(Icons.calendar_today, size: 18),
                title: Text(day.name),
                subtitle: Text(
                  '${day.exercises.length} ejercicios'
                  '${day.muscleFocus != null ? ' · ${day.muscleFocus}' : ''}',
                ),
                onTap: () => Navigator.of(context).pop(day),
              ),
            const SizedBox(height: AppSpacing.sm),
          ],
        ),
      ),
    );
  }

  /// Crea las series objetivo de cada ejercicio del día: peso sugerido =
  /// última vez que se hizo ese ejercicio, o el objetivo de la rutina si
  /// nunca se entrenó; reps sugeridas = punto medio del rango objetivo;
  /// descanso = `targetRestSeconds` de la rutina (no el default de 90s).
  Future<void> _preloadRoutineDay(int sessionId, RoutineDay day) async {
    final workoutRepository = context.read<WorkoutRepository>();
    for (final target in day.exercises) {
      final last = await workoutRepository.lastSetFor(target.exercise.id);
      final weightKg = last?.weightKg ?? target.targetWeightKg ?? 0.0;
      final reps = ((target.targetRepsMin + target.targetRepsMax) / 2).round();
      for (var i = 1; i <= target.targetSets; i++) {
        await workoutRepository.addSet(sessionId, {
          'exercise_id': target.exercise.id,
          'set_number': i,
          'weight_kg': weightKg,
          'reps': reps,
          'rest_seconds': target.targetRestSeconds,
          'techniques': const [],
          'is_warmup': false,
          'completed': false,
        });
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Iniciar entrenamiento')),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : ListView(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.lg,
              ),
              children: [
                _StartCard(
                  icon: Icons.bolt,
                  iconColor: AppColors.secondary,
                  title: 'Entrenamiento libre',
                  subtitle: 'Sin rutina, elegís los ejercicios sobre la marcha',
                  loading: _starting,
                  onTap: _starting ? null : () => _start(),
                ),
                const SizedBox(height: AppSpacing.lg),
                if (_routines.isNotEmpty)
                  Padding(
                    padding: const EdgeInsets.only(bottom: AppSpacing.sm),
                    child: Text(
                      'O elegí una rutina',
                      style: Theme.of(context).textTheme.titleLarge,
                    ),
                  ),
                for (final routine in _routines)
                  _StartCard(
                    icon: Icons.list_alt,
                    iconColor: AppColors.primary,
                    title: routine.name,
                    subtitle: '${routine.daysPerWeek} días por semana',
                    loading: false,
                    onTap: _starting
                        ? null
                        : () => _start(routineId: routine.id),
                  ),
              ],
            ),
    );
  }
}

class _StartCard extends StatelessWidget {
  final IconData icon;
  final Color iconColor;
  final String title;
  final String subtitle;
  final bool loading;
  final VoidCallback? onTap;

  const _StartCard({
    required this.icon,
    required this.iconColor,
    required this.title,
    required this.subtitle,
    required this.loading,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.only(bottom: AppSpacing.sm),
      child: Material(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        child: Semantics(
          // A18: sin esto un lector de pantalla lee ícono + título +
          // subtítulo como nodos sueltos en vez de una sola tarjeta
          // accionable.
          button: true,
          label: '$title. $subtitle',
          excludeSemantics: true,
          child: InkWell(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            onTap: onTap,
            child: Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                children: [
                  Container(
                    width: 56,
                    height: 56,
                    decoration: BoxDecoration(
                      color: iconColor.withValues(alpha: 0.15),
                      borderRadius: BorderRadius.circular(AppRadius.md),
                    ),
                    child: Icon(icon, color: iconColor),
                  ),
                  const SizedBox(width: AppSpacing.md),
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(
                          title,
                          style: Theme.of(context).textTheme.bodyLarge
                              ?.copyWith(fontWeight: FontWeight.w600),
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                        ),
                        const SizedBox(height: 2),
                        Text(
                          subtitle,
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.onSurfaceVariant),
                          maxLines: 2,
                          overflow: TextOverflow.ellipsis,
                        ),
                      ],
                    ),
                  ),
                  if (loading)
                    const SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  else
                    const Icon(
                      Icons.chevron_right,
                      color: AppColors.onSurfaceVariant,
                    ),
                ],
              ),
            ),
          ),
        ),
      ),
    );
  }
}
