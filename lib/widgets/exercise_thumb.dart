import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/exercise_animation/animation_repository.dart';
import '../core/exercise_animation/exercise_animation.dart';
import '../core/theme.dart';

/// Ícono por grupo muscular usado cuando el ejercicio no tiene animación
/// propia (`AnimationType.placeholder`) -- reemplaza a la mancuerna genérica
/// única por algo que al menos distingue el tipo de movimiento a simple
/// vista, sin depender de arte nuevo.
const _muscleGroupFallbackIcon = <String, IconData>{
  'Pecho': Icons.sports_gymnastics,
  'Espalda': Icons.rowing,
  'Hombros': Icons.accessibility_new,
  'Bíceps': Icons.fitness_center,
  'Tríceps': Icons.back_hand,
  'Cuádriceps': Icons.stairs,
  'Isquiotibiales': Icons.airline_seat_legroom_extra,
  'Glúteos': Icons.hiking,
  'Pantorrillas': Icons.directions_walk,
  'Core': Icons.crop_square,
};

/// Miniatura de un ejercicio. Muestra su GIF/animación real si
/// `AnimationRepository` tiene una (ver `lib/core/exercise_animation/`); si
/// no, cae a un ícono coloreado según el grupo muscular (no siempre la misma
/// mancuerna -- ver `_muscleGroupFallbackIcon`).
class ExerciseThumb extends StatelessWidget {
  final String slug;
  final Color color;
  final double size;
  final String? muscleGroup;

  const ExerciseThumb({
    super.key,
    required this.slug,
    required this.color,
    this.size = 56,
    this.muscleGroup,
  });

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    final fallbackIcon = _muscleGroupFallbackIcon[muscleGroup] ?? Icons.fitness_center;
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: size,
        height: size,
        color: color.withValues(alpha: 0.15),
        child: FutureBuilder<ExerciseAnimation>(
          future: context.read<AnimationRepository>().getAnimation(slug),
          builder: (context, snapshot) {
            final animation = snapshot.data;
            if (animation == null) return const SizedBox.shrink();
            final isVisual =
                animation.animationType == AnimationType.gif ||
                animation.animationType == AnimationType.image;
            if (!isVisual) {
              return Icon(fallbackIcon, color: color, size: size * 0.45);
            }
            return Image.asset(
              animation.animationPath,
              fit: BoxFit.cover,
              errorBuilder: (_, _, _) =>
                  Icon(fallbackIcon, color: color, size: size * 0.45),
            );
          },
        ),
      ),
    );
  }
}
