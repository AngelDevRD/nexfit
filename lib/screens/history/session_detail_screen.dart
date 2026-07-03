import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/workout.dart';
import '../../services/workout_service.dart';

class SessionDetailScreen extends StatefulWidget {
  final int sessionId;

  const SessionDetailScreen({super.key, required this.sessionId});

  @override
  State<SessionDetailScreen> createState() => _SessionDetailScreenState();
}

class _SessionDetailScreenState extends State<SessionDetailScreen> {
  WorkoutSession? _session;
  List<PersonalRecord> _records = [];
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    final service = WorkoutService(context.read<ApiClient>());
    Future.wait([
      service.get(widget.sessionId),
      service.sessionRecords(widget.sessionId),
    ]).then((results) {
      setState(() {
        _session = results[0] as WorkoutSession;
        _records = results[1] as List<PersonalRecord>;
      });
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_session == null) {
      return const Scaffold(body: Center(child: CircularProgressIndicator()));
    }
    final session = _session!;
    final grouped = <int, List<WorkoutSet>>{};
    final exerciseNames = <int, String>{};
    for (final set in session.sets) {
      grouped.putIfAbsent(set.exercise.id, () => []).add(set);
      exerciseNames[set.exercise.id] = set.exercise.name;
    }

    return Scaffold(
      appBar: AppBar(
        title: Text(_dateFormat.format(session.startedAt.toLocal())),
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          if (_records.isNotEmpty)
            Card(
              color: Theme.of(context).colorScheme.primaryContainer,
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    const Text(
                      '🏆 Récords logrados',
                      style: TextStyle(fontWeight: FontWeight.bold),
                    ),
                    const SizedBox(height: 6),
                    for (final r in _records)
                      Text(
                        '${recordTypeLabels[r.recordType] ?? r.recordType}: ${r.value}',
                      ),
                  ],
                ),
              ),
            ),
          const SizedBox(height: 12),
          if (session.notes != null && session.notes!.isNotEmpty) ...[
            Text('Notas', style: Theme.of(context).textTheme.titleMedium),
            Text(session.notes!),
            const SizedBox(height: 16),
          ],
          for (final entry in grouped.entries)
            Card(
              margin: const EdgeInsets.only(bottom: 12),
              child: Padding(
                padding: const EdgeInsets.all(12),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Text(
                      exerciseNames[entry.key]!,
                      style: Theme.of(context).textTheme.titleMedium,
                    ),
                    const Divider(),
                    for (final set in entry.value)
                      ListTile(
                        dense: true,
                        contentPadding: EdgeInsets.zero,
                        leading: CircleAvatar(
                          radius: 14,
                          child: Text('${set.setNumber}'),
                        ),
                        title: Text(
                          '${set.weightKg} kg × ${set.reps} reps${set.isWarmup ? ' (calentamiento)' : ''}',
                        ),
                        subtitle: set.rpe != null || set.rir != null
                            ? Text(
                                [
                                  if (set.rpe != null) 'RPE ${set.rpe}',
                                  if (set.rir != null) 'RIR ${set.rir}',
                                ].join(' · '),
                              )
                            : null,
                      ),
                  ],
                ),
              ),
            ),
        ],
      ),
    );
  }
}
