import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/gamification.dart';
import '../../models/stats.dart';
import '../../providers/auth_provider.dart';
import '../../repositories/gamification_repository.dart';
import '../../repositories/stats_repository.dart';
import '../coach/coach_chat_screen.dart';
import '../workout/start_workout_screen.dart';

/// N2: antes tenía 9 tiles que apilaban una instancia NUEVA del mismo hub que
/// ya está a un toque en la barra inferior (sin esa barra, solo con "atrás").
/// Ahora el Dashboard es solo lo que no existe en ningún otro lado: racha,
/// próximo entrenamiento y el coach IA -- reanudar una sesión activa lo
/// cubre el banner de todo el shell (ver `HomeShell`/N3). Lo único que sigue
/// yendo a un hub (la insignia de XP -> Progreso/Logros) cambia de pestaña
/// en vez de apilar, vía [onOpenProgresoTab].
class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key, this.onOpenProgresoTab});

  final ValueChanged<int>? onOpenProgresoTab;

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final StatsRepository _statsRepository;
  late final GamificationRepository _gamificationRepository;
  TrainingStreak? _streak;
  List<bool>? _trainedLast7Days;
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
        _statsRepository.trainedLast7Days(),
        _gamificationRepository.profile(),
      ]);
      setState(() {
        _streak = results[0] as TrainingStreak;
        _trainedLast7Days = results[1] as List<bool>;
        _gamification = results[2] as GamificationProfile;
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
                        // N2: cambia de pestaña (Progreso, sub-tab Logros) en
                        // vez de apilar una instancia nueva del hub.
                        onTap: () => widget.onOpenProgresoTab?.call(3),
                        child: Container(
                          padding: const EdgeInsets.symmetric(
                            horizontal: 12,
                            vertical: 6,
                          ),
                          decoration: BoxDecoration(
                            gradient: AppGradients.heroAccent,
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
                      _StreakCard(
                        streak: _streak,
                        trainedLast7Days: _trainedLast7Days,
                      ),
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
                      _AiCoachTile(
                        onTap: () => Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) => const CoachChatScreen(),
                          ),
                        ),
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
  // U2: antes eran 7 alturas hardcodeadas ([10,16,13,22,18,26,32]) que solo
  // cambiaban de color -- parecían un gráfico de volumen sin serlo. Ahora
  // son los 7 días reales (más viejo a más nuevo, hoy incluido) con sesión.
  final List<bool>? trainedLast7Days;

  const _StreakCard({required this.streak, required this.trainedLast7Days});

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
          if (trainedLast7Days != null)
            Row(
              children: List.generate(7, (i) {
                final active = trainedLast7Days![i];
                final label = const [
                  'L',
                  'M',
                  'M',
                  'J',
                  'V',
                  'S',
                  'D',
                ][DateTime.now().subtract(Duration(days: 6 - i)).weekday - 1];
                return Expanded(
                  child: Padding(
                    padding: const EdgeInsets.symmetric(horizontal: 2),
                    child: Column(
                      children: [
                        Container(
                          height: 8,
                          decoration: BoxDecoration(
                            color: active
                                ? AppColors.secondary
                                : AppColors.surfaceContainerHighest,
                            borderRadius: BorderRadius.circular(AppRadius.full),
                          ),
                        ),
                        const SizedBox(height: 4),
                        Text(
                          label,
                          style: Theme.of(context).textTheme.labelSmall
                              ?.copyWith(
                                color: active
                                    ? AppColors.secondary
                                    : AppColors.onSurfaceVariant,
                                fontWeight: active
                                    ? FontWeight.bold
                                    : FontWeight.normal,
                              ),
                        ),
                      ],
                    ),
                  ),
                );
              }),
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
                  gradient: AppGradients.heroAccent,
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

class _AiCoachTile extends StatelessWidget {
  final VoidCallback onTap;

  const _AiCoachTile({required this.onTap});

  @override
  Widget build(BuildContext context) {
    // Única tarjeta de la pantalla con tratamiento "glass" (borde
    // translúcido + highlight diagonal sobre el gradiente azul->violeta):
    // el usuario pidió glassmorfismo puntual en tarjetas especiales, no
    // generalizado -- esta es la más destacada del Dashboard.
    return Container(
      decoration: BoxDecoration(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        boxShadow: AppGlow.tertiary,
      ),
      child: Material(
        borderRadius: BorderRadius.circular(AppRadius.lg),
        clipBehavior: Clip.antiAlias,
        child: InkWell(
          onTap: onTap,
          child: Ink(
            decoration: const BoxDecoration(gradient: AppGradients.heroAccent),
            child: Stack(
              children: [
                Positioned(
                  top: -30,
                  right: -20,
                  child: Container(
                    width: 120,
                    height: 120,
                    decoration: BoxDecoration(
                      shape: BoxShape.circle,
                      color: Colors.white.withValues(alpha: 0.08),
                    ),
                  ),
                ),
                Container(
                  padding: const EdgeInsets.all(AppSpacing.md),
                  decoration: BoxDecoration(
                    border: Border.all(
                      color: Colors.white.withValues(alpha: 0.12),
                    ),
                    borderRadius: BorderRadius.circular(AppRadius.lg),
                  ),
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
                      Expanded(
                        child: Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            const Text(
                              'Gemelo Digital',
                              style: TextStyle(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                            Text(
                              'Tu coach con IA, disponible ahora',
                              style: Theme.of(context).textTheme.bodySmall
                                  ?.copyWith(color: Colors.white70),
                              maxLines: 1,
                              overflow: TextOverflow.ellipsis,
                            ),
                          ],
                        ),
                      ),
                      const Icon(Icons.chevron_right, color: Colors.white),
                    ],
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
