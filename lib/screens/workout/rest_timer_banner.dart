import 'dart:async';

import 'package:flutter/material.dart';

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
      color: Theme.of(context).colorScheme.primaryContainer,
      child: Padding(
        padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
        child: Row(
          children: [
            const Icon(Icons.timer_outlined),
            const SizedBox(width: 12),
            Text(
              'Descanso: $minutes:$seconds',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const Spacer(),
            TextButton(
              onPressed: widget.onDismiss,
              child: const Text('Saltar'),
            ),
          ],
        ),
      ),
    );
  }
}
