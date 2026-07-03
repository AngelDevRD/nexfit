import 'dart:async';

import 'package:flutter/material.dart';

import '../../core/theme.dart';

class RestTimerBanner extends StatefulWidget {
  final int seconds;
  final VoidCallback onDismiss;

  const RestTimerBanner({
    super.key,
    required this.seconds,
    required this.onDismiss,
  });

  @override
  State<RestTimerBanner> createState() => _RestTimerBannerState();
}

class _RestTimerBannerState extends State<RestTimerBanner> {
  late int _remaining;
  Timer? _timer;

  @override
  void initState() {
    super.initState();
    _remaining = widget.seconds;
    _startTimer();
  }

  void _startTimer() {
    _timer?.cancel();
    _timer = Timer.periodic(const Duration(seconds: 1), (timer) {
      setState(() {
        _remaining--;
      });
      if (_remaining <= 0) {
        timer.cancel();
        widget.onDismiss();
      }
    });
  }

  void _addSeconds(int amount) {
    setState(() => _remaining += amount);
  }

  @override
  void dispose() {
    _timer?.cancel();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final minutes = (_remaining.abs() ~/ 60).toString().padLeft(2, '0');
    final seconds = (_remaining.abs() % 60).toString().padLeft(2, '0');
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
                onTap: () => _addSeconds(30),
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
