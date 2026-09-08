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
class ExerciseThumb extends StatefulWidget {
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
  State<ExerciseThumb> createState() => _ExerciseThumbState();
}

class _ExerciseThumbState extends State<ExerciseThumb> {
  late Future<ExerciseAnimation> _animationFuture;

  @override
  void initState() {
    super.initState();
    _resolveAnimation();
  }

  @override
  void didUpdateWidget(covariant ExerciseThumb oldWidget) {
    super.didUpdateWidget(oldWidget);
    // A10: la animación se resuelve una sola vez por slug, no en cada
    // rebuild -- antes `getAnimation` (que resuelve un `Future`) se llamaba
    // dentro de `build()`, así que cada `setState` ajeno (cada tecla en un
    // buscador, cada tick del entrenamiento activo) volvía a resolverla para
    // todas las filas visibles.
    if (oldWidget.slug != widget.slug) {
      _resolveAnimation();
    }
  }

  void _resolveAnimation() {
    _animationFuture = context.read<AnimationRepository>().getAnimation(
      widget.slug,
    );
  }

  @override
  Widget build(BuildContext context) {
    final radius = BorderRadius.circular(AppRadius.md);
    final fallbackIcon =
        _muscleGroupFallbackIcon[widget.muscleGroup] ?? Icons.fitness_center;
    return ClipRRect(
      borderRadius: radius,
      child: Container(
        width: widget.size,
        height: widget.size,
        color: widget.color.withValues(alpha: 0.15),
        child: FutureBuilder<ExerciseAnimation>(
          future: _animationFuture,
          builder: (context, snapshot) {
            final animation = snapshot.data;
            if (animation == null) return const SizedBox.shrink();
            final isVisual =
                animation.animationType == AnimationType.gif ||
                animation.animationType == AnimationType.image;
            if (!isVisual) {
              return Icon(fallbackIcon, color: widget.color, size: widget.size * 0.45);
            }
            // A16 (corregido -- ver historial: un `ColorFilter.mode(...,
            // BlendMode.multiply)` oscurecía el fondo blanco del GIF, pero
            // `multiply` con negro da negro siempre, así que el trazo del
            // dibujo -negro sobre blanco en el dataset de GymVisual- quedaba
            // con contraste ~1,3:1 contra el fondo oscurecido: prácticamente
            // invisible, peor que el problema original.
            //
            // En vez de pelear con la media, se la enmarca: fondo blanco
            // propio + borde de `AppColors.outlineVariant`, para que lea
            // como una miniatura/foto (patrón común en apps fitness con
            // tema oscuro) en vez de un agujero en la UI. No se toca un
            // solo píxel del GIF. Mismo tratamiento en
            // `ExerciseAnimationViewer`.
            return Container(
              decoration: BoxDecoration(
                color: Colors.white,
                border: Border.all(color: AppColors.outlineVariant),
              ),
              child: Image.asset(
                animation.animationPath,
                fit: BoxFit.cover,
                errorBuilder: (_, _, _) => Icon(
                  fallbackIcon,
                  color: widget.color,
                  size: widget.size * 0.45,
                ),
              ),
            );
          },
        ),
      ),
    );
  }
}
