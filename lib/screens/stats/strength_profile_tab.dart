import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/stats.dart';
import '../../services/stats_service.dart';

class StrengthProfileTab extends StatefulWidget {
  const StrengthProfileTab({super.key});

  @override
  State<StrengthProfileTab> createState() => _StrengthProfileTabState();
}

class _StrengthProfileTabState extends State<StrengthProfileTab> {
  StrengthProfile? _profile;
  TrainingStreak? _streak;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final service = StatsService(context.read<ApiClient>());
    final results = await Future.wait([
      service.strengthProfile(),
      service.streak(),
    ]);
    setState(() {
      _profile = results[0] as StrengthProfile;
      _streak = results[1] as TrainingStreak;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) return const Center(child: CircularProgressIndicator());
    final profile = _profile!;
    final streak = _streak!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Row(
            children: [
              Expanded(
                child: _MiniStat(
                  icon: Icons.local_fire_department,
                  label: 'Racha actual',
                  value: '${streak.currentStreakDays} días',
                ),
              ),
              const SizedBox(width: 12),
              Expanded(
                child: _MiniStat(
                  icon: Icons.emoji_events_outlined,
                  label: 'Mejor racha',
                  value: '${streak.longestStreakDays} días',
                ),
              ),
            ],
          ),
          const SizedBox(height: 12),
          _MiniStat(
            icon: Icons.trending_up,
            label: 'Volumen semanal',
            value: '${profile.weeklyVolumeKg.toStringAsFixed(0)} kg',
            fullWidth: true,
          ),
          const SizedBox(height: 20),
          Text(
            'Fuerza máxima por ejercicio',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (profile.maxStrengthByExercise.isEmpty)
            const Text('Todavía no registraste series no-calentamiento.'),
          for (final entry in profile.maxStrengthByExercise)
            Card(
              child: ListTile(
                title: Text(entry.exerciseName),
                trailing: Text(
                  '${entry.maxWeightKg} kg',
                  style: Theme.of(context).textTheme.titleMedium,
                ),
              ),
            ),
          const SizedBox(height: 20),
          Text(
            'Frecuencia semanal por músculo',
            style: Theme.of(context).textTheme.titleMedium,
          ),
          const SizedBox(height: 8),
          if (profile.weeklyFrequencyByMuscle.isEmpty)
            const Text('Sin entrenamientos esta semana.'),
          for (final entry in profile.weeklyFrequencyByMuscle)
            ListTile(
              contentPadding: EdgeInsets.zero,
              title: Text(entry.muscleGroup),
              trailing: Text('${entry.sessions} sesiones'),
            ),
        ],
      ),
    );
  }
}

class _MiniStat extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final bool fullWidth;

  const _MiniStat({
    required this.icon,
    required this.label,
    required this.value,
    this.fullWidth = false,
  });

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.all(16),
        child: Row(
          children: [
            Icon(icon, color: Theme.of(context).colorScheme.primary),
            const SizedBox(width: 12),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              children: [
                Text(value, style: Theme.of(context).textTheme.titleMedium),
                Text(label, style: Theme.of(context).textTheme.bodySmall),
              ],
            ),
          ],
        ),
      ),
    );
  }
}
