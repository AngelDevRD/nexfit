import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../core/theme.dart';
import 'pose_painter.dart';
import 'rep_counter.dart';

/// Análisis de técnica en vivo: usa la cámara + ML Kit Pose Detection
/// (100% on-device, sin red) para dibujar el esqueleto y contar repeticiones.
class PoseAnalysisScreen extends StatefulWidget {
  const PoseAnalysisScreen({super.key});

  @override
  State<PoseAnalysisScreen> createState() => _PoseAnalysisScreenState();
}

class _PoseAnalysisScreenState extends State<PoseAnalysisScreen> {
  final PoseDetector _detector = PoseDetector(
    options: PoseDetectorOptions(model: PoseDetectionModel.base),
  );

  CameraController? _controller;
  CameraDescription? _camera;
  List<Pose> _poses = [];
  bool _busy = false;
  String? _error;

  TrackedExercise _exercise = trackedExercises.first;
  late RepCounter _counter = _exercise.newCounter();

  static const _orientations = {
    DeviceOrientation.portraitUp: 0,
    DeviceOrientation.landscapeLeft: 90,
    DeviceOrientation.portraitDown: 180,
    DeviceOrientation.landscapeRight: 270,
  };

  @override
  void initState() {
    super.initState();
    _start();
  }

  Future<void> _start() async {
    try {
      final cameras = await availableCameras();
      if (cameras.isEmpty) {
        setState(() => _error = 'No se encontró ninguna cámara');
        return;
      }
      _camera = cameras.firstWhere(
        (c) => c.lensDirection == CameraLensDirection.back,
        orElse: () => cameras.first,
      );
      final controller = CameraController(
        _camera!,
        ResolutionPreset.medium,
        enableAudio: false,
        imageFormatGroup: Platform.isAndroid
            ? ImageFormatGroup.nv21
            : ImageFormatGroup.bgra8888,
      );
      await controller.initialize();
      if (!mounted) return;
      await controller.startImageStream(_processImage);
      setState(() => _controller = controller);
    } catch (e) {
      setState(() => _error = e.toString());
    }
  }

  void _changeExercise(TrackedExercise exercise) {
    setState(() {
      _exercise = exercise;
      _counter = exercise.newCounter();
    });
  }

  Future<void> _processImage(CameraImage image) async {
    if (_busy) return;
    _busy = true;
    try {
      final input = _toInputImage(image);
      if (input == null) return;
      final poses = await _detector.processImage(input);
      _evaluate(poses);
      if (mounted) setState(() => _poses = poses);
    } finally {
      _busy = false;
    }
  }

  void _evaluate(List<Pose> poses) {
    if (poses.isEmpty) return;
    final lm = poses.first.landmarks;
    final a = lm[_exercise.from];
    final b = lm[_exercise.joint];
    final c = lm[_exercise.to];
    if (a == null || b == null || c == null) return;
    final angle = angleDegrees(a.x, a.y, b.x, b.y, c.x, c.y);
    _counter.update(angle);
  }

  InputImage? _toInputImage(CameraImage image) {
    final camera = _camera;
    final controller = _controller;
    if (camera == null || controller == null) return null;

    final sensorOrientation = camera.sensorOrientation;
    InputImageRotation? rotation;
    if (Platform.isIOS) {
      rotation = InputImageRotationValue.fromRawValue(sensorOrientation);
    } else {
      var compensation = _orientations[controller.value.deviceOrientation];
      if (compensation == null) return null;
      if (camera.lensDirection == CameraLensDirection.front) {
        compensation = (sensorOrientation + compensation) % 360;
      } else {
        compensation = (sensorOrientation - compensation + 360) % 360;
      }
      rotation = InputImageRotationValue.fromRawValue(compensation);
    }
    if (rotation == null) return null;

    final format = InputImageFormatValue.fromRawValue(image.format.raw);
    if (format == null ||
        (Platform.isAndroid && format != InputImageFormat.nv21) ||
        (Platform.isIOS && format != InputImageFormat.bgra8888)) {
      return null;
    }
    if (image.planes.length != 1) return null;
    final plane = image.planes.first;

    return InputImage.fromBytes(
      bytes: plane.bytes,
      metadata: InputImageMetadata(
        size: Size(image.width.toDouble(), image.height.toDouble()),
        rotation: rotation,
        format: format,
        bytesPerRow: plane.bytesPerRow,
      ),
    );
  }

  @override
  void dispose() {
    _controller?.stopImageStream().catchError((_) {});
    _controller?.dispose();
    _detector.close();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.black,
      appBar: AppBar(
        backgroundColor: Colors.black,
        title: const Text('Análisis de técnica'),
        actions: [
          IconButton(
            onPressed: () => setState(_counter.reset),
            icon: const Icon(Icons.restart_alt),
            tooltip: 'Reiniciar conteo',
          ),
        ],
      ),
      body: _error != null
          ? _ErrorView(message: _error!)
          : _controller == null
          ? const Center(child: CircularProgressIndicator())
          : Stack(
              fit: StackFit.expand,
              children: [
                CameraPreview(_controller!),
                CustomPaint(
                  painter: PosePainter(
                    poses: _poses,
                    imageSize: _controller!.value.previewSize ?? Size.zero,
                    rotation: _rotationForPainter(),
                    cameraLensDirection: _camera!.lensDirection,
                  ),
                ),
                _Hud(
                  exercise: _exercise,
                  reps: _counter.reps,
                  phase: _counter.phase,
                  onChange: _changeExercise,
                ),
              ],
            ),
    );
  }

  InputImageRotation _rotationForPainter() {
    final raw = _camera?.sensorOrientation ?? 0;
    return InputImageRotationValue.fromRawValue(raw) ??
        InputImageRotation.rotation0deg;
  }
}

class _Hud extends StatelessWidget {
  final TrackedExercise exercise;
  final int reps;
  final RepPhase phase;
  final ValueChanged<TrackedExercise> onChange;

  const _Hud({
    required this.exercise,
    required this.reps,
    required this.phase,
    required this.onChange,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      child: Column(
        children: [
          const Spacer(),
          Padding(
            padding: const EdgeInsets.all(AppSpacing.md),
            child: Column(
              children: [
                Wrap(
                  spacing: AppSpacing.sm,
                  children: [
                    for (final e in trackedExercises)
                      ChoiceChip(
                        label: Text(e.name),
                        selected: e.name == exercise.name,
                        onSelected: (_) => onChange(e),
                      ),
                  ],
                ),
                const SizedBox(height: AppSpacing.md),
                Material(
                  color: Colors.black.withValues(alpha: 0.55),
                  borderRadius: BorderRadius.circular(AppRadius.lg),
                  child: Padding(
                    padding: const EdgeInsets.symmetric(
                      horizontal: AppSpacing.lg,
                      vertical: AppSpacing.md,
                    ),
                    child: Row(
                      mainAxisSize: MainAxisSize.min,
                      children: [
                        Text(
                          '$reps',
                          style: Theme.of(context).textTheme.displaySmall
                              ?.copyWith(
                                color: Colors.white,
                                fontWeight: FontWeight.bold,
                              ),
                        ),
                        const SizedBox(width: AppSpacing.md),
                        Column(
                          crossAxisAlignment: CrossAxisAlignment.start,
                          children: [
                            Text(
                              'reps',
                              style: Theme.of(context).textTheme.labelLarge
                                  ?.copyWith(color: Colors.white70),
                            ),
                            Text(
                              phase == RepPhase.down ? 'Abajo' : 'Arriba',
                              style: Theme.of(context).textTheme.titleMedium
                                  ?.copyWith(
                                    color: phase == RepPhase.down
                                        ? AppColors.secondary
                                        : AppColors.primary,
                                    fontWeight: FontWeight.bold,
                                  ),
                            ),
                          ],
                        ),
                      ],
                    ),
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

class _ErrorView extends StatelessWidget {
  final String message;

  const _ErrorView({required this.message});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(AppSpacing.lg),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.videocam_off_outlined,
              size: 64,
              color: Colors.white70,
            ),
            const SizedBox(height: AppSpacing.md),
            Text(
              'No se pudo iniciar la cámara',
              style: Theme.of(
                context,
              ).textTheme.titleMedium?.copyWith(color: Colors.white),
              textAlign: TextAlign.center,
            ),
            const SizedBox(height: AppSpacing.sm),
            Text(
              message,
              style: const TextStyle(color: Colors.white54),
              textAlign: TextAlign.center,
            ),
          ],
        ),
      ),
    );
  }
}
