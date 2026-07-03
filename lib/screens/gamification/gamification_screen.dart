import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/gamification.dart';
import '../../services/gamification_service.dart';

class GamificationScreen extends StatefulWidget {
  const GamificationScreen({super.key});

  @override
  State<GamificationScreen> createState() => _GamificationScreenState();
}

class _GamificationScreenState extends State<GamificationScreen> {
  GamificationProfile? _profile;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    final profile = await GamificationService(
      context.read<ApiClient>(),
    ).profile();
    setState(() => _profile = profile);
  }

  @override
  Widget build(BuildContext context) {
    if (_profile == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final profile = _profile!;

    return Scaffold(
      appBar: AppBar(title: const Text('Nivel y logros')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              child: Padding(
                padding: const EdgeInsets.all(20),
                child: Column(
                  children: [
                    Text(
                      'Nivel ${profile.level}',
                      style: Theme.of(context).textTheme.headlineMedium,
                    ),
                    Text(
                      levelBandLabels[profile.levelBand] ?? profile.levelBand,
                    ),
                    const SizedBox(height: 16),
                    ClipRRect(
                      borderRadius: BorderRadius.circular(8),
                      child: LinearProgressIndicator(
                        value: profile.progressPct / 100,
                        minHeight: 10,
                      ),
                    ),
                    const SizedBox(height: 8),
                    Text(
                      '${profile.totalXp.toStringAsFixed(0)} XP · faltan ${profile.xpToNextLevel.toStringAsFixed(0)} XP para el siguiente nivel',
                    ),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 16),
            Row(
              children: [
                Expanded(
                  child: _StatChip(
                    label: 'Entrenamientos',
                    value: '${profile.sessionsCompleted}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(
                    label: 'Récords',
                    value: '${profile.recordsCount}',
                  ),
                ),
                const SizedBox(width: 8),
                Expanded(
                  child: _StatChip(
                    label: 'Mejor racha',
                    value: '${profile.longestStreakDays}d',
                  ),
                ),
              ],
            ),
            const SizedBox(height: 24),
            Text('Logros', style: Theme.of(context).textTheme.titleMedium),
            const SizedBox(height: 8),
            for (final achievement in profile.achievements)
              Card(
                child: ListTile(
                  leading: Icon(
                    achievement.unlocked
                        ? Icons.emoji_events
                        : Icons.emoji_events_outlined,
                    color: achievement.unlocked ? Colors.amber : null,
                  ),
                  title: Text(achievement.title),
                  trailing: achievement.unlocked
                      ? const Icon(Icons.check, color: Colors.green)
                      : null,
                ),
              ),
          ],
        ),
      ),
    );
  }
}

class _StatChip extends StatelessWidget {
  final String label;
  final String value;

  const _StatChip({required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Card(
      child: Padding(
        padding: const EdgeInsets.symmetric(vertical: 12),
        child: Column(
          children: [
            Text(value, style: Theme.of(context).textTheme.titleLarge),
            Text(
              label,
              style: Theme.of(context).textTheme.bodySmall,
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
