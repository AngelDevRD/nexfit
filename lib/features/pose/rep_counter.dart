import 'dart:math' as math;

import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

/// Ángulo (en grados) en el vértice `b` formado por los puntos a-b-c.
/// Devuelve un valor en [0, 180].
double angleDegrees(
  double ax,
  double ay,
  double bx,
  double by,
  double cx,
  double cy,
) {
  final abx = ax - bx;
  final aby = ay - by;
  final cbx = cx - bx;
  final cby = cy - by;
  final dot = abx * cbx + aby * cby;
  final magAb = math.sqrt(abx * abx + aby * aby);
  final magCb = math.sqrt(cbx * cbx + cby * cby);
  if (magAb == 0 || magCb == 0) return 0;
  final cos = (dot / (magAb * magCb)).clamp(-1.0, 1.0);
  return math.acos(cos) * 180 / math.pi;
}

enum RepPhase { up, down }

/// Cuenta repeticiones a partir del ángulo de una articulación.
/// Una rep se cuenta al volver a la posición "arriba" tras haber bajado.
class RepCounter {
  final double downThreshold;
  final double upThreshold;

  int reps = 0;
  RepPhase phase = RepPhase.up;

  RepCounter({this.downThreshold = 90, this.upThreshold = 160})
    : assert(downThreshold < upThreshold);

  /// Alimenta el ángulo actual. Devuelve true si se completó una repetición.
  bool update(double angle) {
    if (phase == RepPhase.up && angle < downThreshold) {
      phase = RepPhase.down;
    } else if (phase == RepPhase.down && angle > upThreshold) {
      phase = RepPhase.up;
      reps++;
      return true;
    }
    return false;
  }

  void reset() {
    reps = 0;
    phase = RepPhase.up;
  }
}

/// Ejercicio a trackear: articulación (vértice `joint`) y umbrales de ángulo.
class TrackedExercise {
  final String name;
  final PoseLandmarkType from;
  final PoseLandmarkType joint;
  final PoseLandmarkType to;
  final double downThreshold;
  final double upThreshold;

  const TrackedExercise({
    required this.name,
    required this.from,
    required this.joint,
    required this.to,
    required this.downThreshold,
    required this.upThreshold,
  });

  RepCounter newCounter() =>
      RepCounter(downThreshold: downThreshold, upThreshold: upThreshold);
}

/// Presets soportados. Ambos: ángulo chico = abajo, ángulo grande = arriba.
const trackedExercises = <TrackedExercise>[
  TrackedExercise(
    name: 'Sentadilla',
    from: PoseLandmarkType.leftHip,
    joint: PoseLandmarkType.leftKnee,
    to: PoseLandmarkType.leftAnkle,
    downThreshold: 90,
    upThreshold: 160,
  ),
  TrackedExercise(
    name: 'Flexión',
    from: PoseLandmarkType.leftShoulder,
    joint: PoseLandmarkType.leftElbow,
    to: PoseLandmarkType.leftWrist,
    downThreshold: 90,
    upThreshold: 160,
  ),
];
