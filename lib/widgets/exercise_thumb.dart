import 'package:flutter/material.dart';

import '../core/theme.dart';

/// Miniatura de un ejercicio. Intenta cargar la imagen
/// `assets/images/exercises/<slug>.webp` (offline). Si no está, cae de forma
/// elegante a un ícono coloreado con el color del grupo muscular.
///
/// Para agregar imágenes reales, ver `assets/images/exercises/README.md`.
class ExerciseThumb extends StatelessWidget {
  final String slug;
  final Color color;
  final double size;

  const ExerciseThumb({
    super.key,
    required this.slug,
    required this.color,
    this.size = 56,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        color: color.withValues(alpha: 0.15),
        child: Image.asset(
          'assets/images/exercises/$slug.webp',
          fit: BoxFit.cover,
          errorBuilder: (_, _, _) =>
              Icon(Icons.fitness_center, color: color, size: size * 0.45),
        ),
      ),
    );
  }
}
