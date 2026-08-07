import 'exercise_animation.dart';
import 'exercise_animation_provider.dart';

/// Único punto de la app para pedir la animación de un ejercicio. Nadie más
/// -- pantallas, widgets, otros repos -- debe instanciar un
/// [ExerciseAnimationProvider] directamente.
///
/// No conoce ninguna implementación concreta de [ExerciseAnimationProvider]
/// (ni GymVisual, ni recursos propios): la lista de proveedores se arma en
/// el composition root de la app (`main.dart`, junto con el resto de los
/// repositorios). Sustituir un proveedor por otro, o agregar uno nuevo, es
/// un cambio ahí -- este archivo no se toca.
///
/// Los proveedores se consultan ordenados por [ExerciseAnimationProvider.
/// priority] (menor primero); el primero que devuelva una animación gana.
/// Si ninguno tiene nada, se devuelve un placeholder.
class AnimationRepository {
  final List<ExerciseAnimationProvider> _providers;

  AnimationRepository({required List<ExerciseAnimationProvider> providers})
    : _providers = [...providers]
        ..sort((a, b) => a.priority.compareTo(b.priority));

  Future<ExerciseAnimation> getAnimation(String exerciseSlug) async {
    for (final provider in _providers) {
      final animation = await provider.getAnimation(exerciseSlug);
      if (animation != null) return animation;
    }
    return ExerciseAnimation.placeholder(exerciseSlug);
  }
}
