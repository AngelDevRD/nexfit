import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../repositories/active_workout_repository.dart';

/// Descanso entre series. El tiempo restante se deriva siempre de [endsAt]
/// (instante absoluto, persistido en `ActiveWorkoutDrafts`) contra la hora
/// actual -- nunca de un contador que decrece: así, si la app se cierra y se
/// reabre a mitad del descanso, el tiempo restante sigue siendo correcto. El
/// `Timer` de acá adentro solo repinta cada segundo, no lleva la cuenta.
class RestTimerBanner extends StatefulWidget {
  final DateTime endsAt;
  final VoidCallback onDismiss;
  final ValueChanged<int> onAddSeconds;

  const RestTimerBanner({
    super.key,
    required this.endsAt,
    required this.onDismiss,
    required this.onAddSeconds,
  });

  @override
  State<RestTimerBanner> createState() => _RestTimerBannerState();
}

class _RestTimerBannerState extends State<RestTimerBanner> {
  Timer? _timer;
  late Duration _remaining;

  @override
  void initState() {
    super.initState();
    _remaining = remainingRest(widget.endsAt, DateTime.now());
    _startTimer();
  }

  @override
  void didUpdateWidget(RestTimerBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _remaining = remainingRest(widget.endsAt, DateTime.now());
    }
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      final remaining = remainingRest(widget.endsAt, DateTime.now());
      setState(() => _remaining = remaining);
      if (remaining == Duration.zero) {
        timer.cancel();
        widget.onDismiss();
      }
    });
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = _remaining.inMinutes
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    final seconds = _remaining.inSeconds
        .remainder(60)
        .toString()
        .padLeft(2, '0');
    return Material(
      color: Colors.transparent,
      child: Container(
        padding: const EdgeInsets.symmetric(
          horizontal: AppSpacing.md,
          vertical: AppSpacing.sm,
        ),
        decoration: BoxDecoration(
          color: AppColors.surfaceContainerHighest,
          borderRadius: BorderRadius.circular(AppRadius.full),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.3)),
          boxShadow: [
            BoxShadow(
              color: Colors.black.withValues(alpha: 0.3),
              blurRadius: 16,
            ),
          ],
        ),
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(Icons.refresh, color: AppColors.secondary, size: 20),
            const SizedBox(width: AppSpacing.sm),
            Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'DESCANSO',
                  style: Theme.of(context).textTheme.labelSmall?.copyWith(
                    color: AppColors.secondary,
                    fontWeight: FontWeight.bold,
                  ),
                ),
                Text(
                  '$minutes:$seconds',
                  style: Theme.of(
                    context,
                  ).textTheme.titleMedium?.copyWith(height: 1),
                ),
              ],
            ),
            const SizedBox(width: AppSpacing.sm),
            Material(
              color: AppColors.secondary.withValues(alpha: 0.15),
              borderRadius: BorderRadius.circular(AppRadius.full),
              child: InkWell(
                borderRadius: BorderRadius.circular(AppRadius.full),
                onTap: () => widget.onAddSeconds(30),
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 10, vertical: 6),
                  child: Text(
                    '+30s',
                    style: TextStyle(
                      color: AppColors.secondary,
                      fontWeight: FontWeight.bold,
                      fontSize: 12,
                    ),
                  ),
                ),
              ),
            ),
            IconButton(
              icon: const Icon(Icons.close, size: 18),
              color: AppColors.onSurfaceVariant,
              onPressed: widget.onDismiss,
              padding: EdgeInsets.zero,
              constraints: const BoxConstraints(),
            ),
          ],
        ),
      ),
    );
  }
}
