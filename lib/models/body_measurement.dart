class BodyMeasurement {
  final DateTime measuredAt;
  final double? weightKg;
  final double? fatPercent;
  final double? neckCm;
  final double? shoulderCm;
  final double? chestCm;
  final double? leftBicepCm;
  final double? rightBicepCm;
  final double? leftForearmCm;
  final double? rightForearmCm;
  final double? abdomenCm;
  final double? waistCm;
  final double? hipsCm;
  final double? leftThighCm;
  final double? rightThighCm;
  final double? leftCalfCm;
  final double? rightCalfCm;

  const BodyMeasurement({
    required this.measuredAt,
    this.weightKg,
    this.fatPercent,
    this.neckCm,
    this.shoulderCm,
    this.chestCm,
    this.leftBicepCm,
    this.rightBicepCm,
    this.leftForearmCm,
    this.rightForearmCm,
    this.abdomenCm,
    this.waistCm,
    this.hipsCm,
    this.leftThighCm,
    this.rightThighCm,
    this.leftCalfCm,
    this.rightCalfCm,
  });
}
