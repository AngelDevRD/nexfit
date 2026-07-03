import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/calendar.dart';
import '../../services/calendar_service.dart';

class CalendarScreen extends StatefulWidget {
  const CalendarScreen({super.key});

  @override
  State<CalendarScreen> createState() => _CalendarScreenState();
}

class _CalendarScreenState extends State<CalendarScreen> {
  CalendarOverview? _overview;
  bool _loading = true;
  final _dateFormat = DateFormat('dd/MM/yyyy');

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final overview = await CalendarService(
      context.read<ApiClient>(),
    ).overview();
    setState(() {
      _overview = overview;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    if (_loading) {
      return Scaffold(
        appBar: AppBar(title: const Text('Calendario inteligente')),
        body: const Center(child: CircularProgressIndicator()),
      );
    }
    final overview = _overview!;

    return Scaffold(
      appBar: AppBar(title: const Text('Calendario inteligente')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            Card(
              color: overview.deload.recommended
                  ? AppColors.warning.withValues(alpha: 0.15)
                  : null,
              child: Padding(
                padding: const EdgeInsets.all(16),
                child: Row(
                  children: [
                    Icon(
                      overview.deload.recommended
                          ? Icons.warning_amber
                          : Icons.check_circle_outline,
                    ),
                    const SizedBox(width: 12),
                    Expanded(child: Text(overview.deload.reason)),
                  ],
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              'Objetivos próximos',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (overview.upcomingGoals.isEmpty)
              const Text('Sin objetivos pendientes.'),
            for (final goal in overview.upcomingGoals)
              Card(
                child: ListTile(
                  title: Text(goal.title),
                  subtitle: Text(
                    goal.targetDate != null
                        ? 'Fecha objetivo: ${_dateFormat.format(goal.targetDate!)}'
                        : 'Sin fecha límite',
                  ),
                  trailing: Text('${goal.progressPct.toStringAsFixed(0)}%'),
                ),
              ),
            const SizedBox(height: 20),
            Text(
              'Predicción de próximos récords',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 8),
            if (overview.upcomingRecordPredictions.isEmpty)
              const Text('Sin suficiente histórico todavía.'),
            for (final prediction in overview.upcomingRecordPredictions)
              Card(
                child: ListTile(
                  title: Text(prediction.exerciseName),
                  subtitle: Text('Actual: ${prediction.currentBestKg} kg'),
                  trailing: Text(
                    '${prediction.predictedKg} kg en ${prediction.weeksAhead} sem.',
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}
