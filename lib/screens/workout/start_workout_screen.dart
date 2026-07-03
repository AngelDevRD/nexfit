import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/routine.dart';
import '../../services/routine_service.dart';
import '../../services/workout_service.dart';
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
    RoutineService(context.read<ApiClient>()).list().then((routines) {
      setState(() {
        _routines = routines;
        _loading = false;
      });
    });
  }

  Future<void> _start({int? routineId}) async {
    setState(() => _starting = true);
    final session = await WorkoutService(
      context.read<ApiClient>(),
    ).startSession(routineId: routineId);
    if (!mounted) return;
    Navigator.of(context).pushReplacement(
      MaterialPageRoute(
        builder: (_) => ActiveWorkoutScreen(sessionId: session.id),
      ),
    );
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
