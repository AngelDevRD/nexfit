import 'dart:io';

import 'package:camera/camera.dart';
import 'package:flutter/material.dart';
import 'package:google_mlkit_pose_detection/google_mlkit_pose_detection.dart';

import '../../core/theme.dart';

/// Dibuja el esqueleto detectado sobre el preview de la cámara.
/// El traductor de coordenadas es el canónico de los ejemplos de ML Kit
/// (maneja rotación del sensor y espejo de la cámara frontal).
class PosePainter extends CustomPainter {
  final List<Pose> poses;
  final Size imageSize;
  final InputImageRotation rotation;
  final CameraLensDirection cameraLensDirection;

  PosePainter({
    required this.poses,
    required this.imageSize,
    required this.rotation,
    required this.cameraLensDirection,
  });

  @override
  void paint(Canvas canvas, Size size) {
    final pointPaint = Paint()
      ..style = PaintingStyle.fill
      ..color = AppColors.secondary
      ..strokeWidth = 6;
    final linePaint = Paint()
      ..style = PaintingStyle.stroke
      ..strokeWidth = 4
      ..color = AppColors.primary;

    for (final pose in poses) {
      pose.landmarks.forEach((_, landmark) {
        canvas.drawCircle(
          Offset(_x(landmark.x, size), _y(landmark.y, size)),
          4,
          pointPaint,
        );
      });

      void link(PoseLandmarkType a, PoseLandmarkType b) {
        final pa = pose.landmarks[a];
        final pb = pose.landmarks[b];
        if (pa == null || pb == null) return;
        canvas.drawLine(
          Offset(_x(pa.x, size), _y(pa.y, size)),
          Offset(_x(pb.x, size), _y(pb.y, size)),
          linePaint,
        );
      }

      // Torso
      link(PoseLandmarkType.leftShoulder, PoseLandmarkType.rightShoulder);
      link(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftHip);
      link(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightHip);
      link(PoseLandmarkType.leftHip, PoseLandmarkType.rightHip);
      // Brazos
      link(PoseLandmarkType.leftShoulder, PoseLandmarkType.leftElbow);
      link(PoseLandmarkType.leftElbow, PoseLandmarkType.leftWrist);
      link(PoseLandmarkType.rightShoulder, PoseLandmarkType.rightElbow);
      link(PoseLandmarkType.rightElbow, PoseLandmarkType.rightWrist);
      // Piernas
      link(PoseLandmarkType.leftHip, PoseLandmarkType.leftKnee);
      link(PoseLandmarkType.leftKnee, PoseLandmarkType.leftAnkle);
      link(PoseLandmarkType.rightHip, PoseLandmarkType.rightKnee);
      link(PoseLandmarkType.rightKnee, PoseLandmarkType.rightAnkle);
    }
  }

  double _x(double x, Size canvasSize) {
    final scaledW = Platform.isIOS ? imageSize.width : imageSize.height;
    switch (rotation) {
      case InputImageRotation.rotation90deg:
        return x * canvasSize.width / scaledW;
      case InputImageRotation.rotation270deg:
        return canvasSize.width - x * canvasSize.width / scaledW;
      default:
        final v = x * canvasSize.width / imageSize.width;
        return cameraLensDirection == CameraLensDirection.front
            ? canvasSize.width - v
            : v;
    }
  }

  double _y(double y, Size canvasSize) {
    switch (rotation) {
      case InputImageRotation.rotation90deg:
      case InputImageRotation.rotation270deg:
        final scaledH = Platform.isIOS ? imageSize.height : imageSize.width;
        return y * canvasSize.height / scaledH;
      default:
        return y * canvasSize.height / imageSize.height;
    }
  }

  @override
  bool shouldRepaint(covariant PosePainter oldDelegate) =>
      oldDelegate.poses != poses;
}
