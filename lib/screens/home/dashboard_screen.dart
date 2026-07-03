import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/stats.dart';
import '../../providers/auth_provider.dart';
import '../../services/stats_service.dart';
import '../calculators/calculators_hub_screen.dart';
import '../calendar/calendar_screen.dart';
import '../coach/coach_chat_screen.dart';
import '../gamification/gamification_screen.dart';
import '../goals/goals_screen.dart';
import '../nutrition/nutrition_screen.dart';
import '../recovery/recovery_screen.dart';
import '../stats/stats_hub_screen.dart';
import '../workout/start_workout_screen.dart';

class DashboardScreen extends StatefulWidget {
  const DashboardScreen({super.key});

  @override
  State<DashboardScreen> createState() => _DashboardScreenState();
}

class _DashboardScreenState extends State<DashboardScreen> {
  late final StatsService _statsService;
  TrainingStreak? _streak;
  StrengthProfile? _profile;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _statsService = StatsService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final results = await Future.wait([
        _statsService.streak(),
        _statsService.strengthProfile(),
      ]);
      setState(() {
        _streak = results[0] as TrainingStreak;
        _profile = results[1] as StrengthProfile;
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
    return Scaffold(
      appBar: AppBar(
        title: Text('Hola, ${user?.name.split(' ').first ?? ''} 👋'),
      ),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (_error != null)
              Text(
                _error!,
                style: TextStyle(color: Theme.of(context).colorScheme.error),
              ),
            if (!_loading && _error == null) ...[
              Row(
                children: [
                  Expanded(
                    child: _StatCard(
                      icon: Icons.local_fire_department,
                      label: 'Racha actual',
                      value: '${_streak?.currentStreakDays ?? 0} días',
                    ),
                  ),
                  const SizedBox(width: 12),
                  Expanded(
                    child: _StatCard(
                      icon: Icons.trending_up,
                      label: 'Volumen semanal',
                      value:
                          '${(_profile?.weeklyVolumeKg ?? 0).toStringAsFixed(0)} kg',
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 20),
            ],
            FilledButton.icon(
              onPressed: () => Navigator.of(context).push(
                MaterialPageRoute(builder: (_) => const StartWorkoutScreen()),
              ),
              icon: const Icon(Icons.play_arrow),
              label: const Text('Iniciar entrenamiento'),
              style: FilledButton.styleFrom(
                padding: const EdgeInsets.symmetric(vertical: 16),
              ),
            ),
            const SizedBox(height: 12),
            Row(
              children: [
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(builder: (_) => const StatsHubScreen()),
                    ),
                    icon: const Icon(Icons.bar_chart),
                    label: const Text('Estadísticas'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  child: OutlinedButton.icon(
                    onPressed: () => Navigator.of(context).push(
                      MaterialPageRoute(
                        builder: (_) => const CalculatorsHubScreen(),
                      ),
                    ),
                    icon: const Icon(Icons.calculate_outlined),
                    label: const Text('Calculadoras'),
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text(
              'Más funciones',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            GridView.count(
              crossAxisCount: 3,
              shrinkWrap: true,
              physics: const NeverScrollableScrollPhysics(),
              mainAxisSpacing: 8,
              crossAxisSpacing: 8,
              childAspectRatio: 0.95,
              children: [
                _QuickAccessTile(
                  icon: Icons.restaurant_outlined,
                  label: 'Nutrición',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const NutritionScreen()),
                  ),
                ),
                _QuickAccessTile(
                  icon: Icons.bedtime_outlined,
                  label: 'Recuperación',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const RecoveryScreen()),
                  ),
                ),
                _QuickAccessTile(
                  icon: Icons.flag_outlined,
                  label: 'Objetivos',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const GoalsScreen()),
                  ),
                ),
                _QuickAccessTile(
                  icon: Icons.calendar_month_outlined,
                  label: 'Calendario',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CalendarScreen()),
                  ),
                ),
                _QuickAccessTile(
                  icon: Icons.smart_toy_outlined,
                  label: 'Gemelo Digital',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(builder: (_) => const CoachChatScreen()),
                  ),
                ),
                _QuickAccessTile(
                  icon: Icons.emoji_events_outlined,
                  label: 'Nivel y logros',
                  onTap: () => Navigator.of(context).push(
                    MaterialPageRoute(
                      builder: (_) => const GamificationScreen(),
                    ),
                  ),
                ),
              ],
            ),
          ],
        ),
      ),
    );
  }
}

class _QuickAccessTile extends StatelessWidget {
  final IconData icon;
  final String label;
  final VoidCallback onTap;

  const _QuickAccessTile({
    required this.icon,
    required this.label,
    required this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: InkWell(
        onTap: onTap,
        borderRadius: BorderRadius.circular(16),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(
              label,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall,
            ),
          ],
        ),
      ),
    );
  }
}

class _StatCard extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _StatCard({
    required this.icon,
    required this.label,
    required this.value,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(height: 8),
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(label, style: Theme.of(context).textTheme.bodySmall),
          ],
        ),
      ),
    );
  }
}
