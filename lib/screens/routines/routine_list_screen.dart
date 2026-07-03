import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../models/routine.dart';
import '../../services/routine_service.dart';
import 'routine_builder_screen.dart';
import 'routine_detail_screen.dart';

class RoutineListScreen extends StatefulWidget {
  const RoutineListScreen({super.key});

  @override
  State<RoutineListScreen> createState() => _RoutineListScreenState();
}

class _RoutineListScreenState extends State<RoutineListScreen> {
  late final RoutineService _service;
  List<RoutineSummary> _routines = [];
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _service = RoutineService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final routines = await _service.list();
      setState(() {
        _routines = routines;
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
    return Scaffold(
      appBar: AppBar(title: const Text('Mis rutinas')),
      floatingActionButton: FloatingActionButton.extended(
        onPressed: () async {
          final created = await Navigator.of(context).push<bool>(
            MaterialPageRoute(builder: (_) => const RoutineBuilderScreen()),
          );
          if (created == true) _load();
        },
        icon: const Icon(Icons.add),
        label: const Text('Nueva rutina'),
      ),
      body: _loading
          ? const Center(child: CircularProgressIndicator())
          : _error != null
          ? Center(child: Text(_error!))
          : _routines.isEmpty
          ? const Center(child: Text('Todavía no creaste ninguna rutina.'))
          : RefreshIndicator(
              onRefresh: _load,
              child: ListView.separated(
                padding: const EdgeInsets.all(12),
                itemCount: _routines.length,
                separatorBuilder: (_, __) => const SizedBox(height: 8),
                itemBuilder: (context, index) {
                  final routine = _routines[index];
                  return Card(
                    child: ListTile(
                      leading: const Icon(Icons.list_alt),
                      title: Text(routine.name),
                      subtitle: Text('${routine.daysPerWeek} días por semana'),
                      trailing: const Icon(Icons.chevron_right),
                      onTap: () async {
                        await Navigator.of(context).push(
                          MaterialPageRoute(
                            builder: (_) =>
                                RoutineDetailScreen(routineId: routine.id),
                          ),
                        );
                        _load();
                      },
                    ),
                  );
                },
              ),
            ),
    );
  }
}
