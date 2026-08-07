import 'package:flutter/material.dart';

import '../../theme.dart';
import '../exercise_animation.dart';

/// Renderiza una [ExerciseAnimation] sin saber de dónde salió. No conoce
/// GymVisual, Mixamo, ni ningún proveedor -- solo el formato
/// ([AnimationType]) que le llega. Agregar un formato nuevo (lottie, sprite
/// sheet) es agregar un `case` acá, no tocar pantallas.
class ExerciseAnimationViewer extends StatelessWidget {
  final ExerciseAnimation animation;

  const ExerciseAnimationViewer({super.key, required this.animation});

  @override
  Widget build(BuildContext context) {
    return Column(
      mainAxisSize: MainAxisSize.min,
      children: [
        Expanded(child: _renderer(context)),
        if (animation.attribution != null)
          Padding(
            padding: const EdgeInsets.symmetric(
              vertical: AppSpacing.xs,
              horizontal: AppSpacing.sm,
            ),
            child: Text(
              animation.attribution!,
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.labelSmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ),
      ],
    );
  }

  Widget _renderer(BuildContext context) {
    switch (animation.animationType) {
      case AnimationType.gif:
      case AnimationType.image:
        // Image.asset ya anima GIFs solo -- una imagen estática se ve
        // igual con el mismo widget, no hace falta un renderer aparte.
        return _AssetImageRenderer(path: animation.animationPath);
      case AnimationType.mp4:
      case AnimationType.webm:
      case AnimationType.lottie:
      case AnimationType.imageSequence:
        return _UnsupportedFormat(animationType: animation.animationType);
      case AnimationType.placeholder:
        return const _Placeholder();
    }
  }
}

class _AssetImageRenderer extends StatelessWidget {
  final String path;

  const _AssetImageRenderer({required this.path});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Image.asset(
        path,
        fit: BoxFit.contain,
        errorBuilder: (_, _, _) => const _Placeholder(),
      ),
    );
  }
}

class _UnsupportedFormat extends StatelessWidget {
  final AnimationType animationType;

  const _UnsupportedFormat({required this.animationType});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.movie_creation_outlined,
              size: 64,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Formato ${animationType.name} aún no soportado por el visor',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}

class _Placeholder extends StatelessWidget {
  const _Placeholder();

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.fitness_center,
              size: 64,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Animación no disponible para este ejercicio',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodyMedium?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
