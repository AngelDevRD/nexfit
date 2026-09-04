import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../core/theme.dart';
import '../../models/recovery.dart';
import '../../repositories/recovery_repository.dart';
import '../../widgets/empty_state.dart';

/// N5: siempre vive dentro de [CuerpoHubScreen] -- el hub provee
/// Scaffold/AppBar, esta pantalla solo devuelve contenido.
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
  String? _error;
  final _checkInFormKey = GlobalKey();

  double _sleepHours = 8;
  int _fatigue = 5;

  @override
  void initState() {
    super.initState();
    _repository = context.read<RecoveryRepository>();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final index = await _repository.index();
      setState(() {
        _index = index;
        _loading = false;
      });
    } catch (e) {
      setState(() {
        _error = e.toString();
        _loading = false;
      });
    }
  }

  void _focusCheckInForm() {
    final context = _checkInFormKey.currentContext;
    if (context != null) Scrollable.ensureVisible(context);
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

  IconData _levelBattery(String level) {
    switch (level) {
      case 'recovered':
        return Icons.battery_full;
      case 'medium':
        return Icons.battery_5_bar;
      default:
        return Icons.battery_2_bar;
    }
  }

  @override
  Widget build(BuildContext context) {
    final body = RefreshIndicator(
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
            if (!_loading && _error != null)
              EmptyState.error(message: _error!, onRetry: _load),
            if (!_loading && _error == null && _index == null)
              EmptyState(
                icon: Icons.bedtime_outlined,
                message: 'Todavía no registraste tu check-in de hoy.',
                actionLabel: 'Hacer check-in',
                onAction: _focusCheckInForm,
              ),
            if (_index != null)
              Container(
                padding: const EdgeInsets.all(AppSpacing.lg),
                decoration: BoxDecoration(
                  color: AppColors.surfaceContainer,
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                ),
                child: Column(
                  children: [
                    Icon(
                      _levelBattery(_index!.level),
                      size: 56,
                      color: _levelColor(_index!.level),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Text(
                      '${_index!.recoveryIndex}%',
                      style: Theme.of(context).textTheme.headlineLarge?.copyWith(
                        fontWeight: FontWeight.w800,
                        color: _levelColor(_index!.level),
                      ),
                    ),
                    Text(
                      'Índice de Recuperación',
                      style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                        color: AppColors.onSurfaceVariant,
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
                    Container(
                      padding: const EdgeInsets.symmetric(
                        horizontal: AppSpacing.md,
                        vertical: 6,
                      ),
                      decoration: BoxDecoration(
                        borderRadius: BorderRadius.circular(AppRadius.full),
                        border: Border.all(
                          color: _levelColor(_index!.level).withValues(alpha: 0.4),
                        ),
                      ),
                      child: Row(
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Container(
                            width: 8,
                            height: 8,
                            decoration: BoxDecoration(
                              shape: BoxShape.circle,
                              color: _levelColor(_index!.level),
                            ),
                          ),
                          const SizedBox(width: 6),
                          Text(
                            recoveryLevelLabels[_index!.level] ?? _index!.level,
                            style: Theme.of(context).textTheme.labelLarge?.copyWith(
                              color: _levelColor(_index!.level),
                            ),
                          ),
                        ],
                      ),
                    ),
                    const SizedBox(height: AppSpacing.sm),
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
              key: _checkInFormKey,
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
      );

    return body;
  }
}
