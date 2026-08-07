/// Formato del recurso animado. Agregar un formato nuevo (ej. spriteSheet)
/// solo requiere un caso más acá y un renderer más en
/// `ExerciseAnimationViewer` -- ningún otro archivo cambia.
enum AnimationType {
  gif,
  mp4,
  webm,
  lottie,
  image,
  imageSequence,
  placeholder,
}

/// Animación de un ejercicio, ya resuelta y lista para mostrar. No sabe de
/// dónde vino el archivo (Mixamo, GymVisual, un recurso propio, etc.) -- eso
/// es responsabilidad exclusiva del `ExerciseAnimationProvider` que la creó.
class ExerciseAnimation {
  /// Identificador del ejercicio (slug), no de la animación en sí.
  final String id;

  /// Ruta al asset o URL del recurso. Vacío cuando [animationType] es
  /// [AnimationType.placeholder].
  final String animationPath;

  final AnimationType animationType;

  /// Texto de atribución a mostrar junto a la animación, si el proveedor
  /// que la resolvió lo requiere (ej. licencias de terceros). `null` si no
  /// hace falta.
  final String? attribution;

  /// Nombre del proveedor que resolvió esta animación (ej. "custom",
  /// "gymvisual"). Solo informativo/debug -- la UI no debe ramificar lógica
  /// según este valor.
  final String provider;

  const ExerciseAnimation({
    required this.id,
    required this.animationPath,
    required this.animationType,
    required this.provider,
    this.attribution,
  });

  const ExerciseAnimation.placeholder(this.id)
    : animationPath = '',
      animationType = AnimationType.placeholder,
      provider = 'none',
      attribution = null;
}
