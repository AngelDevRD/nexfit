import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/api_client.dart';
import '../../core/theme.dart';
import '../../models/recovery.dart';
import '../../services/recovery_service.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  late final RecoveryService _service;
  RecoveryIndex? _index;
  bool _loading = true;
  bool _saving = false;

  double _sleepHours = 8;
  int _fatigue = 5;

  @override
  void initState() {
    super.initState();
    _service = RecoveryService(context.read<ApiClient>());
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final index = await _service.index();
    setState(() {
      _index = index;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    await _service.upsertCheckIn(DateTime.now(), _sleepHours, _fatigue);
    setState(() => _saving = false);
    _load();
  }

  Color _levelColor(String level) {
    switch (level) {
      case 'recovered':
        return AppColors.secondary;
      case 'medium':
        return AppColors.warning;
      default:
        return AppColors.danger;
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(title: const Text('Recuperación')),
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
            if (!_loading && _index == null)
              const Text('Todavía no registraste tu check-in de hoy.'),
            if (_index != null)
              Card(
                color: _levelColor(_index!.level).withValues(alpha: 0.15),
                child: Padding(
                  padding: const EdgeInsets.all(16),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Text(
                        recoveryLevelLabels[_index!.level] ?? _index!.level,
                        style: Theme.of(context).textTheme.titleLarge,
                      ),
                      const SizedBox(height: 4),
                      Text('${_index!.recoveryIndex}% de recuperación'),
                      Text(
                        'Sueño: ${_index!.sleepHours}h · Fatiga percibida: ${_index!.perceivedFatigue}/10',
                      ),
                    ],
                  ),
                ),
              ),
            const SizedBox(height: 24),
            Text(
              'Check-in de hoy',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: 12),
            Text('Horas de sueño: ${_sleepHours.toStringAsFixed(1)}'),
            Slider(
              value: _sleepHours,
              min: 0,
              max: 12,
              divisions: 24,
              label: _sleepHours.toStringAsFixed(1),
              onChanged: (v) => setState(() => _sleepHours = v),
            ),
            const SizedBox(height: 8),
            Text('Fatiga percibida: $_fatigue/10'),
            Slider(
              value: _fatigue.toDouble(),
              min: 1,
              max: 10,
              divisions: 9,
              label: '$_fatigue',
              onChanged: (v) => setState(() => _fatigue = v.round()),
            ),
            const SizedBox(height: 16),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const CircularProgressIndicator()
                  : const Text('Guardar check-in'),
            ),
          ],
        ),
      ),
    );
  }
}
