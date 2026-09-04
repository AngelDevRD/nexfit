import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/routine.dart';
import '../../repositories/active_workout_repository.dart';
import '../../repositories/routine_repository.dart';
import '../../repositories/workout_repository.dart';
import 'active_workout_screen.dart';

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

    // Si ya hay un entrenamiento activo (la app se cerró a mitad de una
    // sesión), se resume directo en vez de ofrecer iniciar uno nuevo: solo
    // puede existir un entrenamiento en curso a la vez.
    final activeId = await activeWorkoutRepository.currentSessionId();
    if (!mounted) return;
    if (activeId != null) {
      Navigator.of(context).pushReplacement(
        MaterialPageRoute(
          builder: (_) => ActiveWorkoutScreen(sessionId: activeId),
        ),
      );
      return;
    }

    final routines = await routineRepository.list();
    if (!mounted) return;
    setState(() {
      _routines = routines;
      _loading = false;
    });
  }

  /// C4: si hay rutina, resuelve qué día entrenar (el único que tenga, o
  /// preguntando si hay varios) y precarga sus ejercicios con los objetivos
  /// de la rutina -- series, reps sugeridas y, crucial, el descanso
  /// configurado para cada ejercicio (antes se ignoraba y siempre arrancaba
  /// en 90s sin importar lo que el usuario haya puesto en el constructor).
  Future<void> _start({int? routineId, String? title}) async {
    setState(() => _starting = true);

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
  }

  Future<RoutineDay?> _pickDay(List<RoutineDay> days) {
    return showModalBottomSheet<RoutineDay>(
      context: context,
      backgroundColor: AppColors.surfaceContainer,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(
          top: Radius.circular(AppRadius.lg),
        ),
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
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
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
    );
  }
}
