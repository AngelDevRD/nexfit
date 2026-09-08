import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../core/exercise_animation/animation_repository.dart';
import '../core/theme.dart';

/// A4: pie de atribución legal, una vez por pantalla -- una miniatura de
/// 56px (`ExerciseThumb`) no tiene espacio para el texto de licencia. Se
/// arma en base a `ExerciseAnimation.attribution` de los ejercicios
/// visibles: si ninguno viene de un proveedor que la exija (ej. GymVisual),
/// no ocupa espacio. El texto nunca se hardcodea acá -- si el día de mañana
/// cambia el proveedor de media, este widget no cambia.
class AttributionFooter extends StatefulWidget {
  final List<String> slugs;

  const AttributionFooter({super.key, required this.slugs});

  @override
  State<AttributionFooter> createState() => _AttributionFooterState();
}

class _AttributionFooterState extends State<AttributionFooter> {
  late Future<Set<String>> _attributions;

  @override
  void initState() {
    super.initState();
    _resolve();
  }

  @override
  void didUpdateWidget(covariant AttributionFooter oldWidget) {
    super.didUpdateWidget(oldWidget);
    if (!listEquals(oldWidget.slugs, widget.slugs)) _resolve();
  }

  void _resolve() {
    final repository = context.read<AnimationRepository>();
    _attributions = Future.wait(widget.slugs.map(repository.getAnimation))
        .then(
          (animations) => animations
              .map((a) => a.attribution)
              .whereType<String>()
              .toSet(),
        );
  }

  @override
  Widget build(BuildContext context) {
    return FutureBuilder<Set<String>>(
      future: _attributions,
      builder: (context, snapshot) {
        final attributions = snapshot.data;
        if (attributions == null || attributions.isEmpty) {
          return const SizedBox.shrink();
        }
        return Padding(
          padding: const EdgeInsets.symmetric(
            horizontal: AppSpacing.md,
            vertical: AppSpacing.sm,
          ),
          child: Text(
            attributions.join(' · '),
            textAlign: TextAlign.center,
            style: Theme.of(
              context,
            ).textTheme.labelSmall?.copyWith(color: AppColors.onSurfaceVariant),
          ),
        );
      },
    );
  }
}
