import 'package:flutter/material.dart';
import 'package:flutter/services.dart' show rootBundle;
import 'package:flutter_3d_controller/flutter_3d_controller.dart';

import '../../core/theme.dart';

/// Visor 3D de un ejercicio. Carga el modelo animado desde
/// `assets/models_3d/<slug>_<gender>.glb` (offline). Si el archivo no está,
/// muestra un placeholder con el nombre exacto que falta.
///
/// Cámara: rotar/zoom con gestos táctiles (built-in del visor).
/// Controles: género, play/pausa, reencuadrar cámara.
class Exercise3DView extends StatefulWidget {
  final String slug;
  final String exerciseName;

  const Exercise3DView({
    super.key,
    required this.slug,
    required this.exerciseName,
  });

  @override
  State<Exercise3DView> createState() => _Exercise3DViewState();
}

class _Exercise3DViewState extends State<Exercise3DView> {
  final Flutter3DController _controller = Flutter3DController();
  String _gender = 'male';
  bool _checking = true;
  bool _assetPresent = false;
  bool _playing = true;

  String get _assetPath => 'assets/models_3d/${widget.slug}_$_gender.glb';

  @override
  void initState() {
    super.initState();
    _checkAsset();
  }

  Future<void> _checkAsset() async {
    setState(() => _checking = true);
    bool present;
    try {
      await rootBundle.load(_assetPath);
      present = true;
    } catch (_) {
      present = false;
    }
    if (!mounted) return;
    setState(() {
      _assetPresent = present;
      _checking = false;
      _playing = true;
    });
  }

  void _setGender(String gender) {
    if (gender == _gender) return;
    setState(() => _gender = gender);
    _checkAsset();
  }

  void _togglePlay() {
    if (_playing) {
      _controller.pauseAnimation();
    } else {
      _controller.playAnimation();
    }
    setState(() => _playing = !_playing);
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: AppColors.background,
      appBar: AppBar(title: Text('${widget.exerciseName} · 3D')),
      body: Column(
        children: [
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: SegmentedButton<String>(
              segments: const [
                ButtonSegment(
                  value: 'male',
                  label: Text('Masculino'),
                  icon: Icon(Icons.male),
                ),
                ButtonSegment(
                  value: 'female',
                  label: Text('Femenino'),
                  icon: Icon(Icons.female),
                ),
              ],
              selected: {_gender},
              onSelectionChanged: (s) => _setGender(s.first),
            ),
          ),
          Expanded(
            child: _checking
                ? const Center(child: CircularProgressIndicator())
                : _assetPresent
                ? Flutter3DViewer(
                    src: _assetPath,
                    controller: _controller,
                    progressBarColor: AppColors.primary,
                  )
                : _MissingAsset(assetPath: _assetPath),
          ),
          if (_assetPresent)
            Padding(
              padding: const EdgeInsets.all(AppSpacing.md),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.spaceEvenly,
                children: [
                  IconButton.filled(
                    onPressed: _togglePlay,
                    icon: Icon(_playing ? Icons.pause : Icons.play_arrow),
                    tooltip: _playing ? 'Pausar' : 'Reproducir',
                  ),
                  IconButton.filledTonal(
                    onPressed: () => _controller.resetCameraOrbit(),
                    icon: const Icon(Icons.center_focus_strong),
                    tooltip: 'Reencuadrar cámara',
                  ),
                ],
              ),
            ),
        ],
      ),
    );
  }
}

class _MissingAsset extends StatelessWidget {
  final String assetPath;

  const _MissingAsset({required this.assetPath});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.view_in_ar_outlined,
              size: 64,
              color: AppColors.onSurfaceVariant,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'Modelo 3D no disponible',
              style: Theme.of(context).textTheme.titleMedium,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              'Agregá el archivo:\n$assetPath\n(ver assets/models_3d/README.md)',
              textAlign: TextAlign.center,
              style: Theme.of(context).textTheme.bodySmall?.copyWith(
                color: AppColors.onSurfaceVariant,
              ),
            ),
          ],
        ),
      ),
    );
  }
}
