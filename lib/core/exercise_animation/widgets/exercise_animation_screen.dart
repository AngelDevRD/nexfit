import 'package:flutter/material.dart';
import 'package:provider/provider.dart';

import '../../theme.dart';
import '../animation_repository.dart';
import '../exercise_animation.dart';
import 'exercise_animation_viewer.dart';

/// Pantalla de animación de un ejercicio. Solo habla con
/// [AnimationRepository] -- no sabe (ni le importa) si la animación viene de
/// un recurso propio o de un proveedor temporal de terceros.
class ExerciseAnimationScreen extends StatefulWidget {
  final String exerciseSlug;
  final String exerciseName;

  const ExerciseAnimationScreen({
    super.key,
    required this.exerciseSlug,
    required this.exerciseName,
  });

  @override
  State<ExerciseAnimationScreen> createState() =>
      _ExerciseAnimationScreenState();
}

class _ExerciseAnimationScreenState extends State<ExerciseAnimationScreen> {
  ExerciseAnimation? _animation;

  @override
  void initState() {
    super.initState();
    context
        .read<AnimationRepository>()
        .getAnimation(widget.exerciseSlug)
        .then((a) => setState(() => _animation = a));
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text(widget.exerciseName)),
      body: _animation == null
          ? const Center(child: CircularProgressIndicator())
          : ExerciseAnimationViewer(animation: _animation!),
    );
  }
}
