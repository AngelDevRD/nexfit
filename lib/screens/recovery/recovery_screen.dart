import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/recovery.dart';
import '../../repositories/recovery_repository.dart';

class RecoveryScreen extends StatefulWidget {
  const RecoveryScreen({super.key});

  @override
  State<RecoveryScreen> createState() => _RecoveryScreenState();
}

class _RecoveryScreenState extends State<RecoveryScreen> {
  late final RecoveryRepository _repository;
  RecoveryIndex? _index;
  bool _loading = true;
  bool _saving = false;

  double _sleepHours = 8;
  int _fatigue = 5;

  @override
  void initState() {
    super.initState();
    _repository = context.read<RecoveryRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() => _loading = true);
    final index = await _repository.index();
    setState(() {
      _index = index;
      _loading = false;
    });
  }

  Future<void> _submit() async {
    setState(() => _saving = true);
    await _repository.upsertCheckIn(DateTime.now(), _sleepHours, _fatigue);
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
      backgroundColor: AppColors.background,
      appBar: AppBar(title: const Text('Recuperación')),
      body: RefreshIndicator(
        onRefresh: _load,
        child: ListView(
          padding: const EdgeInsets.all(AppSpacing.md),
          children: [
            if (_loading)
              const Center(
                child: Padding(
                  padding: EdgeInsets.all(24),
                  child: CircularProgressIndicator(),
                ),
              ),
            if (!_loading && _index == null)
              Text(
                'Todavía no registraste tu check-in de hoy.',
                style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                  color: AppColors.onSurfaceVariant,
                ),
              ),
            if (_index != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  border: Border(
                    left: BorderSide(
                      color: _levelColor(_index!.level),
                      width: 4,
                    ),
                  ),
                ),
                child: Column(
                  crossAxisAlignment: CrossAxisAlignment.start,
                  children: [
                    Row(
                      children: [
                        Icon(Icons.bedtime, color: _levelColor(_index!.level)),
                        const SizedBox(width: AppSpacing.sm),
                        Text(
                          recoveryLevelLabels[_index!.level] ?? _index!.level,
                          style: Theme.of(context).textTheme.titleLarge,
                        ),
                      ],
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${_index!.recoveryIndex}% de recuperación',
                      style: Theme.of(context).textTheme.bodyLarge,
                    ),
                    const SizedBox(height: 4),
                    Text(
                      'Sueño: ${_index!.sleepHours}h · Fatiga percibida: ${_index!.perceivedFatigue}/10',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                  ],
                ),
              ),
            const SizedBox(height: AppSpacing.lg),
            Text(
              'Check-in de hoy',
              style: Theme.of(context).textTheme.titleLarge,
            ),
            const SizedBox(height: AppSpacing.md),
            Container(
              padding: const EdgeInsets.all(AppSpacing.md),
              decoration: BoxDecoration(
                color: AppColors.surfaceContainer,
                borderRadius: BorderRadius.circular(AppRadius.lg),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text(
                    'Horas de sueño: ${_sleepHours.toStringAsFixed(1)}',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Slider(
                    value: _sleepHours,
                    min: 0,
                    max: 12,
                    divisions: 24,
                    label: _sleepHours.toStringAsFixed(1),
                    onChanged: (v) => setState(() => _sleepHours = v),
                  ),
                  const SizedBox(height: AppSpacing.xs),
                  Text(
                    'Fatiga percibida: $_fatigue/10',
                    style: Theme.of(context).textTheme.bodyLarge,
                  ),
                  Slider(
                    value: _fatigue.toDouble(),
                    min: 1,
                    max: 10,
                    divisions: 9,
                    label: '$_fatigue',
                    onChanged: (v) => setState(() => _fatigue = v.round()),
                  ),
                ],
              ),
            ),
            const SizedBox(height: AppSpacing.md),
            FilledButton(
              onPressed: _saving ? null : _submit,
              child: _saving
                  ? const SizedBox(
                      height: 18,
                      width: 18,
                      child: CircularProgressIndicator(strokeWidth: 2),
                    )
                  : const Text('Guardar check-in'),
            ),
          ],
        ),
      ),
    );
  }
}
