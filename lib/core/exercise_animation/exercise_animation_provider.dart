import 'exercise_animation.dart';

/// Fuente de animaciones de ejercicio. Cada implementación conoce su propio
/// origen (assets propios, un dataset de terceros, etc.) y lo mantiene
/// privado -- el resto de la app solo ve esta interfaz.
abstract class ExerciseAnimationProvider {
  /// Orden de consulta dentro de `AnimationRepository`: menor número se
  /// intenta primero. Agregar/reordenar proveedores es cambiar este valor en
  /// la implementación correspondiente -- `AnimationRepository` nunca
  /// necesita saber qué proveedor va antes que otro.
  int get priority;

  /// `true` si este proveedor tiene una animación para [exerciseSlug].
  Future<bool> hasAnimation(String exerciseSlug);

  /// La animación resuelta para [exerciseSlug], o `null` si este proveedor
  /// no tiene nada para ese ejercicio. Nunca lanza por "no encontrado" --
  /// solo por errores reales de lectura.
  Future<ExerciseAnimation?> getAnimation(String exerciseSlug);
}
