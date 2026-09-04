import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Silueta humana (vista frontal + posterior) que resalta los grupos
/// musculares entrenados en una sesión, con intensidad proporcional al
/// volumen relativo de cada uno. Usa los mismos 10 grupos de
/// `muscleGroupColors` que ya usa toda la app (Historial, Estadísticas,
/// filtros de ejercicio) para no crear una segunda taxonomía muscular
/// paralela -- "Antebrazos" se representa junto a Bíceps/Tríceps y
/// "Abdomen" junto a Core.
class MuscleSilhouette extends StatelessWidget {
  final Map<String, double> volumeByMuscle;

  const MuscleSilhouette({super.key, required this.volumeByMuscle});

  @override
  Widget build(BuildContext context) {
    final maxVolume = volumeByMuscle.values.isEmpty
        ? 0.0
        : volumeByMuscle.values.reduce((a, b) => a > b ? a : b);

    Color colorFor(String muscle) {
      final volume = volumeByMuscle[muscle];
      final base = muscleGroupColors[muscle] ?? AppColors.surfaceContainerHighest;
      if (volume == null || volume <= 0 || maxVolume <= 0) {
        return AppColors.surfaceContainerHighest;
      }
      final intensity = (volume / maxVolume).clamp(0.35, 1.0);
      return Color.lerp(AppColors.surfaceContainerHighest, base, intensity)!;
    }

    return Container(
      padding: const EdgeInsets.all(AppSpacing.md),
      decoration: BoxDecoration(
        color: AppColors.surfaceContainer,
        borderRadius: BorderRadius.circular(AppRadius.lg),
      ),
      child: Column(
        children: [
          AspectRatio(
            aspectRatio: 2,
            child: CustomPaint(
              painter: _SilhouettePainter(colorFor: colorFor),
              child: const SizedBox.expand(),
            ),
          ),
          const SizedBox(height: AppSpacing.md),
          Wrap(
            spacing: AppSpacing.sm,
            runSpacing: AppSpacing.xs,
            alignment: WrapAlignment.center,
            children: volumeByMuscle.keys.map((muscle) {
              final color = muscleGroupColors[muscle] ?? Colors.grey;
              return Row(
                mainAxisSize: MainAxisSize.min,
                children: [
                  Container(
                    width: 8,
                    height: 8,
                    decoration: BoxDecoration(shape: BoxShape.circle, color: color),
                  ),
                  const SizedBox(width: 4),
                  Text(
                    muscle,
                    style: Theme.of(context).textTheme.labelSmall?.copyWith(
                      color: AppColors.onSurfaceVariant,
                    ),
                  ),
                ],
              );
            }).toList(),
          ),
        ],
      ),
    );
  }
}

/// Dibuja dos siluetas simplificadas lado a lado (frontal a la izquierda,
/// posterior a la derecha) sobre un lienzo normalizado 0..1, reescalado al
/// tamaño real en `paint`. Cada región es un `Path` propio para poder
/// colorearla de forma independiente.
class _SilhouettePainter extends CustomPainter {
  final Color Function(String muscle) colorFor;

  _SilhouettePainter({required this.colorFor});

  @override
  void paint(Canvas canvas, Size size) {
    final halfWidth = size.width / 2;
    _paintFront(canvas, Rect.fromLTWH(0, 0, halfWidth, size.height));
    _paintBack(canvas, Rect.fromLTWH(halfWidth, 0, halfWidth, size.height));
  }

  Offset _p(Rect r, double x, double y) => Offset(r.left + r.width * x, r.top + r.height * y);

  void _fill(Canvas canvas, Path path, Color color) {
    canvas.drawPath(path, Paint()..color = color..style = PaintingStyle.fill);
  }

  void _paintFront(Canvas canvas, Rect r) {
    // Cabeza + torso base (neutro, no es un grupo entrenable en sí).
    final head = Path()..addOval(Rect.fromCenter(center: _p(r, 0.5, 0.08), width: r.width * 0.16, height: r.height * 0.12));
    _fill(canvas, head, AppColors.surfaceContainerHighest);

    // Hombros
    final shoulders = Path()
      ..moveTo(_p(r, 0.28, 0.2).dx, _p(r, 0.28, 0.2).dy)
      ..lineTo(_p(r, 0.72, 0.2).dx, _p(r, 0.72, 0.2).dy)
      ..lineTo(_p(r, 0.68, 0.28).dx, _p(r, 0.68, 0.28).dy)
      ..lineTo(_p(r, 0.32, 0.28).dx, _p(r, 0.32, 0.28).dy)
      ..close();
    _fill(canvas, shoulders, colorFor('Hombros'));

    // Pecho
    final chest = Path()
      ..moveTo(_p(r, 0.34, 0.28).dx, _p(r, 0.34, 0.28).dy)
      ..lineTo(_p(r, 0.66, 0.28).dx, _p(r, 0.66, 0.28).dy)
      ..lineTo(_p(r, 0.64, 0.42).dx, _p(r, 0.64, 0.42).dy)
      ..lineTo(_p(r, 0.36, 0.42).dx, _p(r, 0.36, 0.42).dy)
      ..close();
    _fill(canvas, chest, colorFor('Pecho'));

    // Core / abdomen
    final core = Path()
      ..moveTo(_p(r, 0.38, 0.42).dx, _p(r, 0.38, 0.42).dy)
      ..lineTo(_p(r, 0.62, 0.42).dx, _p(r, 0.62, 0.42).dy)
      ..lineTo(_p(r, 0.6, 0.56).dx, _p(r, 0.6, 0.56).dy)
      ..lineTo(_p(r, 0.4, 0.56).dx, _p(r, 0.4, 0.56).dy)
      ..close();
    _fill(canvas, core, colorFor('Core'));

    // Bíceps (izq/der)
    for (final side in [-1.0, 1.0]) {
      final x0 = 0.5 + side * 0.22;
      final biceps = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(_p(r, x0 - 0.05, 0.28).dx, _p(r, x0, 0.28).dy, r.width * 0.1, r.height * 0.16),
          Radius.circular(r.width * 0.03),
        ));
      _fill(canvas, biceps, colorFor('Bíceps'));
    }

    // Cuádriceps (izq/der)
    for (final side in [-1.0, 1.0]) {
      final x0 = 0.5 + side * 0.13;
      final quad = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(_p(r, x0 - 0.09, 0.58).dx, _p(r, x0, 0.58).dy, r.width * 0.18, r.height * 0.28),
          Radius.circular(r.width * 0.04),
        ));
      _fill(canvas, quad, colorFor('Cuádriceps'));
    }

    // Pantorrillas (izq/der)
    for (final side in [-1.0, 1.0]) {
      final x0 = 0.5 + side * 0.13;
      final calf = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(_p(r, x0 - 0.07, 0.86).dx, _p(r, x0, 0.86).dy, r.width * 0.14, r.height * 0.13),
          Radius.circular(r.width * 0.03),
        ));
      _fill(canvas, calf, colorFor('Pantorrillas'));
    }
  }

  void _paintBack(Canvas canvas, Rect r) {
    final head = Path()..addOval(Rect.fromCenter(center: _p(r, 0.5, 0.08), width: r.width * 0.16, height: r.height * 0.12));
    _fill(canvas, head, AppColors.surfaceContainerHighest);

    // Espalda (trapecio + dorsales, una sola región)
    final back = Path()
      ..moveTo(_p(r, 0.3, 0.2).dx, _p(r, 0.3, 0.2).dy)
      ..lineTo(_p(r, 0.7, 0.2).dx, _p(r, 0.7, 0.2).dy)
      ..lineTo(_p(r, 0.64, 0.5).dx, _p(r, 0.64, 0.5).dy)
      ..lineTo(_p(r, 0.36, 0.5).dx, _p(r, 0.36, 0.5).dy)
      ..close();
    _fill(canvas, back, colorFor('Espalda'));

    // Tríceps (izq/der)
    for (final side in [-1.0, 1.0]) {
      final x0 = 0.5 + side * 0.22;
      final triceps = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(_p(r, x0 - 0.05, 0.28).dx, _p(r, x0, 0.28).dy, r.width * 0.1, r.height * 0.16),
          Radius.circular(r.width * 0.03),
        ));
      _fill(canvas, triceps, colorFor('Tríceps'));
    }

    // Glúteos
    final glutes = Path()
      ..moveTo(_p(r, 0.36, 0.5).dx, _p(r, 0.36, 0.5).dy)
      ..lineTo(_p(r, 0.64, 0.5).dx, _p(r, 0.64, 0.5).dy)
      ..lineTo(_p(r, 0.62, 0.6).dx, _p(r, 0.62, 0.6).dy)
      ..lineTo(_p(r, 0.38, 0.6).dx, _p(r, 0.38, 0.6).dy)
      ..close();
    _fill(canvas, glutes, colorFor('Glúteos'));

    // Isquiotibiales (izq/der)
    for (final side in [-1.0, 1.0]) {
      final x0 = 0.5 + side * 0.13;
      final hamstring = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(_p(r, x0 - 0.09, 0.6).dx, _p(r, x0, 0.6).dy, r.width * 0.18, r.height * 0.24),
          Radius.circular(r.width * 0.04),
        ));
      _fill(canvas, hamstring, colorFor('Isquiotibiales'));
    }

    // Pantorrillas (comparten grupo con la vista frontal, se ven desde atrás)
    for (final side in [-1.0, 1.0]) {
      final x0 = 0.5 + side * 0.13;
      final calf = Path()
        ..addRRect(RRect.fromRectAndRadius(
          Rect.fromLTWH(_p(r, x0 - 0.07, 0.86).dx, _p(r, x0, 0.86).dy, r.width * 0.14, r.height * 0.13),
          Radius.circular(r.width * 0.03),
        ));
      _fill(canvas, calf, colorFor('Pantorrillas'));
    }
  }

  @override
  bool shouldRepaint(covariant _SilhouettePainter oldDelegate) => true;
}
