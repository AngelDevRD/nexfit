import 'package:flutter/material.dart';
import 'package:intl/intl.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/workout.dart';
import '../../services/workout_service.dart';
import 'session_detail_screen.dart';

class HistoryListScreen extends StatefulWidget {
  const HistoryListScreen({super.key});

  @override
  State<HistoryListScreen> createState() => _HistoryListScreenState();
}

class _HistoryListScreenState extends State<HistoryListScreen> {
  late final WorkoutService _service;
  List<WorkoutSessionSummary> _sessions = [];
  bool _loading = true;
  String? _muscleGroup;
  final _dateFormat = DateFormat('dd/MM/yyyy HH:mm');

  @override
  void initState() {
    super.initState();
    _service = WorkoutService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final sessions = await _service.history(muscleGroup: _muscleGroup);
    setState(() {
      _sessions = sessions;
      _loading = false;
    });
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Historial')),
      body: Column(
        children: [
          SizedBox(
            height: 48,
            child: ListView(
              scrollDirection: Axis.horizontal,
              padding: const EdgeInsets.symmetric(horizontal: 12),
              children: [
                Padding(
                  padding: const EdgeInsets.symmetric(
                    horizontal: 4,
                    vertical: 6,
                  ),
                  child: ChoiceChip(
                    label: const Text('Todos'),
                    selected: _muscleGroup == null,
                    onSelected: (_) {
                      setState(() => _muscleGroup = null);
                      _load();
                    },
                  ),
                ),
                ...muscleGroupColors.keys.map(
                  (group) => Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: 4,
                      vertical: 6,
                    ),
                    child: ChoiceChip(
                      label: Text(group),
                      selected: _muscleGroup == group,
                      onSelected: (_) {
                        setState(() => _muscleGroup = group);
                        _load();
                      },
                    ),
                  ),
                ),
              ],
            ),
          ),
          const Divider(height: 1),
          Expanded(
            child: _loading
                ? const Center(child: CircularProgressIndicator())
                : _sessions.isEmpty
                ? const Center(
                    child: Text('Sin entrenamientos registrados todavía.'),
                  )
                : RefreshIndicator(
                    onRefresh: _load,
                    child: ListView.separated(
                      padding: const EdgeInsets.all(12),
                      itemCount: _sessions.length,
                      separatorBuilder: (_, __) => const SizedBox(height: 8),
                      itemBuilder: (context, index) {
                        final session = _sessions[index];
                        return Card(
                          child: ListTile(
                            leading: const Icon(Icons.fitness_center),
                            title: Text(
                              _dateFormat.format(session.startedAt.toLocal()),
                            ),
                            subtitle: Text(
                              session.endedAt != null
                                  ? 'Duración: ${session.endedAt!.difference(session.startedAt).inMinutes} min'
                                  : 'En curso',
                            ),
                            trailing: const Icon(Icons.chevron_right),
                            onTap: () => Navigator.of(context).push(
                              MaterialPageRoute(
                                builder: (_) =>
                                    SessionDetailScreen(sessionId: session.id),
                              ),
                            ),
                          ),
                        );
                      },
                    ),
                  ),
          ),
        ],
      ),
    );
  }
}
