import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/workout.dart';
import '../../repositories/workout_repository.dart';
import 'session_detail_screen.dart';

class HistoryListScreen extends StatefulWidget {
  const HistoryListScreen({super.key});

  @override
  State<HistoryListScreen> createState() => _HistoryListScreenState();
}

class _HistoryListScreenState extends State<HistoryListScreen> {
  late final WorkoutRepository _repository;
  List<WorkoutSessionSummary> _sessions = [];
  bool _loading = true;
  String? _muscleGroup;
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
    final sessions = await _repository.history(muscleGroup: _muscleGroup);
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        child: Column(
          children: [
            Padding(
              padding: const EdgeInsets.fromLTRB(
                AppSpacing.md,
                AppSpacing.sm,
                AppSpacing.md,
                AppSpacing.md,
              ),
              child: Row(
                children: [
                  Expanded(
                    child: Text(
                      'Historial',
                      style: Theme.of(context).textTheme.headlineSmall,
                    ),
                  ),
                ],
              ),
            ),
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
                            ),
                        ],
                      ),
                    ),
            ),
          ],
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
    return Text(
      '$icon $label',
      style: Theme.of(
        context,
      ).textTheme.labelMedium?.copyWith(color: AppColors.onSurfaceVariant),
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

  const _SessionCard({required this.session, required this.dateFormat});

  @override
  Widget build(BuildContext context) {
    final finished = session.endedAt != null;
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
            child: Row(
              children: [
                Container(
                  width: 48,
                  height: 48,
                  decoration: BoxDecoration(
                    color: AppColors.primaryContainer.withValues(alpha: 0.15),
                    borderRadius: BorderRadius.circular(AppRadius.md),
                  ),
                  child: const Icon(
                    Icons.fitness_center,
                    color: AppColors.primary,
                  ),
                ),
                const SizedBox(width: AppSpacing.md),
                Expanded(
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        session.title?.isNotEmpty == true
                            ? session.title!
                            : dateFormat.format(session.startedAt.toLocal()),
                        style: Theme.of(context).textTheme.bodyLarge?.copyWith(
                          fontWeight: FontWeight.w600,
                        ),
                        maxLines: 1,
                        overflow: TextOverflow.ellipsis,
                      ),
                      if (session.title?.isNotEmpty == true) ...[
                        const SizedBox(height: 2),
                        Text(
                          dateFormat.format(session.startedAt.toLocal()),
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(color: AppColors.onSurfaceVariant),
                        ),
                      ],
                      const SizedBox(height: 8),
                      if (finished)
                        Wrap(
                          spacing: AppSpacing.md,
                          runSpacing: 4,
                          children: [
                            _Metric(
                              icon: '⏱',
                              label: formatWorkoutDuration(session.duration),
                            ),
                            _Metric(
                              icon: '🏋',
                              label:
                                  '${session.totalVolumeKg.toStringAsFixed(0)} kg',
                            ),
                            _Metric(
                              icon: '💪',
                              label: '${session.exerciseCount} ej.',
                            ),
                            _Metric(
                              icon: '📊',
                              label: '${session.setCount} series',
                            ),
                          ],
                        )
                      else
                        Text(
                          'En curso',
                          style: Theme.of(context).textTheme.labelMedium
                              ?.copyWith(color: AppColors.secondary),
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
