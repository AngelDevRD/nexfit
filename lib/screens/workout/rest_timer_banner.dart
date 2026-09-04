import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';
import '../../repositories/active_workout_repository.dart';

/// Descanso entre series. El tiempo restante se deriva siempre de [endsAt]
/// (instante absoluto, persistido en `ActiveWorkoutDrafts`) contra la hora
/// actual -- nunca de un contador que decrece: así, si la app se cierra y se
/// reabre a mitad del descanso, el tiempo restante sigue siendo correcto. El
/// `Timer` de acá adentro solo repinta cada segundo, no lleva la cuenta.
///
/// Barra completa anclada abajo (C5): antes era una píldora chica en la
/// esquina, fácil de perder de vista justo cuando más importa (arranca al
/// completar una serie). [totalSeconds] alimenta la barra de progreso -- si
/// no se conoce (p. ej. se restauró un descanso que ya estaba corriendo antes
/// de reabrir la app), se usa el restante en ese momento como el 100%.
class RestTimerBanner extends StatefulWidget {
  final DateTime endsAt;
  final int? totalSeconds;
  final VoidCallback onDismiss;
  final ValueChanged<int> onAddSeconds;

  const RestTimerBanner({
    super.key,
    required this.endsAt,
    this.totalSeconds,
    required this.onDismiss,
    required this.onAddSeconds,
  });

  @override
  State<RestTimerBanner> createState() => _RestTimerBannerState();
}

class _RestTimerBannerState extends State<RestTimerBanner> {
  Timer? _timer;
  late Duration _remaining;
  late int _totalSeconds;
  bool _paused = false;

  @override
  void initState() {
    super.initState();
    _remaining = remainingRest(widget.endsAt, DateTime.now());
    _totalSeconds =
        widget.totalSeconds ?? _remaining.inSeconds.clamp(1, 1 << 30);
    _startTimer();
  }

  @override
  void didUpdateWidget(RestTimerBanner oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (oldWidget.endsAt != widget.endsAt) {
      _remaining = remainingRest(widget.endsAt, DateTime.now());
      if (widget.totalSeconds != null) _totalSeconds = widget.totalSeconds!;
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

  DateTime? _pausedAt;

  // Pausar no persiste (efímero, se pierde si se cierra la app a mitad de una
  // pausa) -- correr el descanso mientras se llega al próximo set sí persiste
  // vía `endsAt`, esto es solo una comodidad de UI. Al reanudar, se corre
  // `endsAt` hacia adelante exactamente lo que duró la pausa.
  void _togglePause() {
    if (_paused) {
      final pausedFor = DateTime.now().difference(_pausedAt!);
      widget.onAddSeconds(pausedFor.inSeconds);
      setState(() => _paused = false);
      _startTimer();
    } else {
      _timer?.cancel();
      setState(() {
        _paused = true;
        _pausedAt = DateTime.now();
      });
    }
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
    final progress = (_remaining.inSeconds / _totalSeconds).clamp(0.0, 1.0);

    return Material(
      color: Colors.transparent,
      child: Container(
        decoration: BoxDecoration(
          gradient: LinearGradient(
            begin: Alignment.topLeft,
            end: Alignment.bottomRight,
            colors: [
              AppColors.secondaryContainer.withValues(alpha: 0.95),
              AppColors.surfaceContainerHigh.withValues(alpha: 0.98),
            ],
          ),
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          border: Border.all(color: AppColors.secondary.withValues(alpha: 0.4)),
          boxShadow: AppGlow.secondary,
        ),
        child: ClipRRect(
          borderRadius: const BorderRadius.vertical(
            top: Radius.circular(AppRadius.xl),
          ),
          child: Column(
            mainAxisSize: MainAxisSize.min,
            children: [
              // Barra de progreso: se vacía de izquierda a derecha a medida
              // que corre el descanso -- referencia visual instantánea sin
              // tener que leer el número.
              LayoutBuilder(
                builder: (context, constraints) => Stack(
                  children: [
                    Container(
                      height: 4,
                      color: AppColors.onSecondaryContainer.withValues(
                        alpha: 0.15,
                      ),
                    ),
                    AnimatedContainer(
                      duration: const Duration(milliseconds: 300),
                      height: 4,
                      width: constraints.maxWidth * progress,
                      color: AppColors.secondary,
                    ),
                  ],
                ),
              ),
              Padding(
                padding: const EdgeInsets.fromLTRB(
                  AppSpacing.lg,
                  AppSpacing.sm,
                  AppSpacing.md,
                  AppSpacing.md,
                ),
                child: Row(
                  children: [
                    const Icon(
                      Icons.self_improvement,
                      color: AppColors.onSecondaryContainer,
                      size: 22,
                    ),
                    const SizedBox(width: AppSpacing.sm),
                    Expanded(
                      child: Column(
                        crossAxisAlignment: CrossAxisAlignment.start,
                        mainAxisSize: MainAxisSize.min,
                        children: [
                          Text(
                            'DESCANSO',
                            style: Theme.of(context).textTheme.labelSmall
                                ?.copyWith(
                                  color: AppColors.onSecondaryContainer
                                      .withValues(alpha: 0.8),
                                  fontWeight: FontWeight.bold,
                                  letterSpacing: 1.2,
                                ),
                          ),
                          Text(
                            '$minutes:$seconds',
                            style: Theme.of(context).textTheme.headlineMedium
                                ?.copyWith(
                                  color: AppColors.onSecondaryContainer,
                                  fontWeight: FontWeight.bold,
                                  height: 1,
                                  fontFeatures: const [
                                    FontFeature.tabularFigures(),
                                  ],
                                ),
                          ),
                        ],
                      ),
                    ),
                    _RestAction(
                      label: '+30s',
                      onTap: () => widget.onAddSeconds(30),
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _RestIconAction(
                      icon: _paused ? Icons.play_arrow : Icons.pause,
                      onTap: _togglePause,
                    ),
                    const SizedBox(width: AppSpacing.xs),
                    _RestIconAction(icon: Icons.close, onTap: widget.onDismiss),
                  ],
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}

class _RestAction extends StatelessWidget {
  final String label;
  final VoidCallback onTap;

  const _RestAction({required this.label, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.onSecondaryContainer.withValues(alpha: 0.15),
      borderRadius: BorderRadius.circular(AppRadius.full),
      child: InkWell(
        borderRadius: BorderRadius.circular(AppRadius.full),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 10),
          child: Text(
            label,
            style: Theme.of(context).textTheme.labelLarge?.copyWith(
              color: AppColors.onSecondaryContainer,
              fontWeight: FontWeight.bold,
            ),
          ),
        ),
      ),
    );
  }
}

class _RestIconAction extends StatelessWidget {
  final IconData icon;
  final VoidCallback onTap;

  const _RestIconAction({required this.icon, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: AppColors.onSecondaryContainer.withValues(alpha: 0.15),
      shape: const CircleBorder(),
      child: InkWell(
        customBorder: const CircleBorder(),
        onTap: onTap,
        child: Padding(
          padding: const EdgeInsets.all(10),
          child: Icon(icon, size: 18, color: AppColors.onSecondaryContainer),
        ),
      ),
    );
  }
}
