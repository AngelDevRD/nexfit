import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/gamification.dart';
import '../../models/stats.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/gamification_repository.dart';
import '../../repositories/stats_repository.dart';
import '../calculators/calculators_hub_screen.dart';
import '../calendar/calendar_screen.dart';
import '../coach/coach_chat_screen.dart';
import '../gamification/gamification_screen.dart';
import '../goals/goals_screen.dart';
import '../measurements/measurements_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../recovery/recovery_screen.dart';
import '../../features/pose/pose_analysis_screen.dart';
import '../social/challenges_screen.dart';
import '../stats/stats_hub_screen.dart';
import '../wearables/wearables_screen.dart';
import '../workout/start_workout_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final StatsRepository _statsRepository;
  late final GamificationRepository _gamificationRepository;
  TrainingStreak? _streak;
  GamificationProfile? _gamification;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _statsRepository = context.read<StatsRepository>();
    _gamificationRepository = context.read<GamificationRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _statsRepository.streak(),
        _gamificationRepository.profile(),
      ]);
      setState(() {
        _streak = results[0] as TrainingStreak;
        _gamification = results[1] as GamificationProfile;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  @override
  Widget build(BuildContext context) {
    final user = context.watch<AuthProvider>().user;
    final firstName = user?.name.split(' ').first ?? '';
    return Scaffold(
      backgroundColor: AppColors.background,
      body: SafeArea(
        bottom: false,
        child: RefreshIndicator(
          onRefresh: _load,
          child: CustomScrollView(
            slivers: [
              SliverToBoxAdapter(
                child: Padding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.sm,
                    AppSpacing.md,
                    0,
                  ),
                  child: Row(
                    children: [
                      CircleAvatar(
                        radius: 20,
                        backgroundColor: AppColors.primaryContainer,
                        child: Text(
                          firstName.isNotEmpty
                              ? firstName[0].toUpperCase()
                              : '?',
                          style: const TextStyle(
                            color: AppColors.onPrimaryContainer,
                            fontWeight: FontWeight.bold,
                          ),
                        ),
                      ),
                      const SizedBox(width: AppSpacing.md),
                      Expanded(
                        child: Text(
                          'Hola, $firstName',
                          style: Theme.of(context).textTheme.headlineSmall
                              ?.copyWith(fontWeight: FontWeight.bold),
                        ),
                      ),
                      GestureDetector(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const GamificationScreen(),
                          ),
                        ),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            color: AppColors.primaryContainer,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                          child: Row(
                            children: [
                              const Icon(
                                Icons.military_tech,
                                size: 18,
                                color: AppColors.onPrimaryContainer,
                              ),
                              const SizedBox(width: 4),
                              Text(
                                'XP ${(_gamification?.totalXp ?? 0).toStringAsFixed(0)}',
                                style: Theme.of(context).textTheme.labelLarge
                                    ?.copyWith(
                                      color: AppColors.onPrimaryContainer,
                                    ),
                              ),
                            ],
                          ),
                        ),
                      ),
                    ],
                  ),
                ),
              ),
              if (_loading)
                const SliverFillRemaining(
                  child: Center(child: CircularProgressIndicator()),
                )
              else if (_error != null)
                SliverFillRemaining(
                  child: Center(
                    child: Text(
                      _error!,
                      style: TextStyle(
                        color: Theme.of(context).colorScheme.error,
                      ),
                    ),
                  ),
                )
              else
                SliverPadding(
                  padding: const EdgeInsets.fromLTRB(
                    AppSpacing.md,
                    AppSpacing.lg,
                    AppSpacing.md,
                    AppSpacing.xl,
                  ),
                  sliver: SliverList(
                    delegate: SliverChildListDelegate([
                      _StreakCard(streak: _streak),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Próximo entrenamiento',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      _NextWorkoutCard(
                        onStart: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const StartWorkoutScreen(),
                          ),
                        ),
                      ),
                      const SizedBox(height: AppSpacing.lg),
                      Text(
                        'Más funciones',
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: AppSpacing.md),
                      GridView.count(
                        crossAxisCount: 2,
                        shrinkWrap: true,
                        physics: const NeverScrollableScrollPhysics(),
                        mainAxisSpacing: AppSpacing.md,
                        crossAxisSpacing: AppSpacing.md,
                        childAspectRatio: 1.5,
                        children: [
                          _FeatureTile(
                            icon: Icons.restaurant,
                            iconBg: AppColors.tertiaryContainer,
                            iconColor: AppColors.onTertiaryContainer,
                            label: 'Nutrición',
                            value: 'Registro diario',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const NutritionScreen(),
                              ),
                            ),
                          ),
                          _FeatureTile(
                            icon: Icons.bedtime,
                            iconBg: AppColors.surfaceContainerHighest,
                            iconColor: AppColors.secondary,
                            label: 'Recuperación',
                            value: 'Check-in de hoy',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const RecoveryScreen(),
                              ),
                            ),
                          ),
                          _AiCoachTile(
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CoachChatScreen(),
                              ),
                            ),
                          ),
                          _FeatureTile(
                            icon: Icons.flag,
                            iconBg: AppColors.surfaceContainerHighest,
                            iconColor: AppColors.primary,
                            label: 'Objetivos',
                            value: 'Ver progreso',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const GoalsScreen(),
                              ),
                            ),
                          ),
                          _FeatureTile(
                            icon: Icons.straighten,
                            iconBg: AppColors.surfaceContainerHighest,
                            iconColor: AppColors.onSurfaceVariant,
                            label: 'Medidas',
                            value: 'Historial corporal',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const MeasurementsScreen(),
                              ),
                            ),
                          ),
                          _FeatureTile(
                            icon: Icons.calendar_month,
                            iconBg: AppColors.surfaceContainerHighest,
                            iconColor: AppColors.onSurfaceVariant,
                            label: 'Calendario',
                            value: 'Descarga y planes',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CalendarScreen(),
                              ),
                            ),
                          ),
                          _FeatureTile(
                            icon: Icons.emoji_events,
                            iconBg: AppColors.surfaceContainerHighest,
                            iconColor: AppColors.secondaryContainer,
                            label: 'Logros',
                            value: 'Nivel y medallas',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const GamificationScreen(),
                              ),
                            ),
                          ),
                          _FeatureTile(
                            icon: Icons.calculate,
                            iconBg: AppColors.surfaceContainerHighest,
                            iconColor: AppColors.primary,
                            label: 'Calculadoras',
                            value: '1RM, IMC y más',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const CalculatorsHubScreen(),
                              ),
                            ),
                          ),
                          _FeatureTile(
                            icon: Icons.bar_chart,
                            iconBg: AppColors.surfaceContainerHighest,
                            iconColor: AppColors.tertiary,
                            label: 'Estadísticas',
                            value: 'Progreso y récords',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const StatsHubScreen(),
                              ),
                            ),
                          ),
                          _FeatureTile(
                            icon: Icons.groups,
                            iconBg: AppColors.surfaceContainerHighest,
                            iconColor: AppColors.secondaryContainer,
                            label: 'Retos',
                            value: 'Competí con amigos',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const ChallengesScreen(),
                              ),
                            ),
                          ),
                          _FeatureTile(
                            icon: Icons.watch,
                            iconBg: AppColors.surfaceContainerHighest,
                            iconColor: AppColors.tertiary,
                            label: 'Wearables',
                            value: 'Pasos, pulso y sueño',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const WearablesScreen(),
                              ),
                            ),
                          ),
                          _FeatureTile(
                            icon: Icons.videocam,
                            iconBg: AppColors.surfaceContainerHighest,
                            iconColor: AppColors.danger,
                            label: 'Análisis de técnica',
                            value: 'Cuenta reps con la cámara',
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) => const PoseAnalysisScreen(),
                              ),
                            ),
                          ),
                        ],
                      ),
                    ]),
                  ),
                ),
            ],
          ),
        ),
      ),
    );
  }
}

class _StreakCard extends StatelessWidget {
  final TrainingStreak? streak;

  const _StreakCard({required this.streak});

  @override
  Widget build(BuildContext context) {
    final days = streak?.currentStreakDays ?? 0;
    return Container(
      padding: const EdgeInsets.all(AppSpacing.lg),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
        border: const Border(
          left: BorderSide(color: AppColors.secondary, width: 4),
        ),
      ),
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
                      'CONTINUIDAD',
                      style: Theme.of(context).textTheme.labelMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: 4),
                    Row(
                      children: [
                        const Icon(
                          Icons.local_fire_department,
                          color: AppColors.secondary,
                          size: 28,
                        ),
                        const SizedBox(width: 4),
                        Flexible(
                          child: Text(
                            'Racha de $days días',
                            style: Theme.of(context).textTheme.headlineSmall,
                          ),
                        ),
                      ],
                    ),
                  ],
                ),
              ),
              const Icon(
                Icons.trending_up,
                size: 48,
                color: AppColors.secondary,
              ),
            ],
          ),
          const SizedBox(height: AppSpacing.md),
          SizedBox(
            height: 32,
            child: Row(
              crossAxisAlignment: CrossAxisAlignment.end,
              children: List.generate(7, (i) {
                final active = i < (days.clamp(0, 7));
                final heights = [10.0, 16.0, 13.0, 22.0, 18.0, 26.0, 32.0];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Container(
                      height: heights[i],
                      decoration: BoxDecoration(
                        color: active
                            ? AppColors.secondary
                            : AppColors.surfaceContainerHighest,
                        borderRadius: BorderRadius.circular(AppRadius.full),
                      ),
                    ),
                  ),
                );
              }),
            ),
          ),
          const SizedBox(height: AppSpacing.sm),
          Text(
            days > 0
                ? '¡Seguí así, vas muy bien esta semana!'
                : 'Arrancá hoy tu racha de entrenamiento.',
            style: Theme.of(
              context,
            ).textTheme.bodyMedium?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        ],
      ),
    );
  }
}

class _NextWorkoutCard extends StatelessWidget {
  final VoidCallback onStart;

  const _NextWorkoutCard({required this.onStart});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainerHigh,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onStart,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.lg),
          child: Row(
            children: [
              Container(
                width: 48,
                height: 48,
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: const Icon(
                  Icons.fitness_center,
                  color: AppColors.onPrimaryContainer,
                ),
              ),
              const SizedBox(width: AppSpacing.md),
              Expanded(
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      'Elegí una rutina o entrená libre',
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    Text(
                      'Registro de series en tiempo real',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
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
                decoration: BoxDecoration(
                  color: AppColors.primaryContainer,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Row(
                  children: [
                    Text(
                      'Comenzar',
                      style: Theme.of(context).textTheme.labelLarge?.copyWith(
                        color: AppColors.onPrimaryContainer,
                      ),
                    ),
                    const SizedBox(width: 4),
                    const Icon(
                      Icons.play_arrow,
                      size: 18,
                      color: AppColors.onPrimaryContainer,
                    ),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _FeatureTile extends StatelessWidget {
  final IconData icon;
  final Color iconBg;
  final Color iconColor;
  final String label;
  final String value;
  final VoidCallback onTap;

  const _FeatureTile({
    required this.icon,
    required this.iconBg,
    required this.iconColor,
    required this.label,
    required this.value,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.surfaceContainer,
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: iconBg,
                  borderRadius: BorderRadius.circular(AppRadius.md),
                ),
                child: Icon(icon, color: iconColor, size: 20),
              ),
              const SizedBox(height: AppSpacing.sm),
              Text(label, style: Theme.of(context).textTheme.labelLarge),
              Text(
                value,
                style: Theme.of(context).textTheme.bodySmall?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
                maxLines: 1,
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _AiCoachTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AiCoachTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      borderRadius: BorderRadius.circular(AppRadius.lg),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        onTap: onTap,
        child: Container(
          decoration: BoxDecoration(
            borderRadius: BorderRadius.circular(AppRadius.lg),
            gradient: const LinearGradient(
              colors: [AppColors.primaryContainer, AppColors.tertiaryContainer],
            ),
          ),
          padding: const EdgeInsets.all(AppSpacing.md),
          child: Row(
            children: [
              Container(
                width: 40,
                height: 40,
                decoration: BoxDecoration(
                  color: Colors.white.withValues(alpha: 0.2),
                  shape: BoxShape.circle,
                ),
                child: const Icon(Icons.smart_toy, color: Colors.white),
              ),
              const SizedBox(width: AppSpacing.sm),
              const Expanded(
                child: Text(
                  'Gemelo Digital',
                  style: TextStyle(
                    color: Colors.white,
                    fontWeight: FontWeight.bold,
                  ),
                  maxLines: 1,
                  overflow: TextOverflow.ellipsis,
                ),
              ),
              const Icon(Icons.chevron_right, color: Colors.white),
            ],
          ),
        ),
      ),
    );
  }
}
