import 'dart:developer' as developer;

import 'package:health/health.dart';

/// Resumen de hoy leído desde Health Connect (Android) / HealthKit (iOS).
class HealthSummary {
  final int steps;
  final double? avgHeartRate;
  final double? activeCalories;
  final int? sleepMinutes;

  HealthSummary({
    required this.steps,
    required this.avgHeartRate,
    required this.activeCalories,
    required this.sleepMinutes,
  });
}

/// Lectura de métricas de wearables. Solo READ, nunca escribe en Health Connect.
class HealthService {
  final Health _health = Health();

  static final List<HealthDataType> _types = [
    HealthDataType.STEPS,
    HealthDataType.HEART_RATE,
    HealthDataType.ACTIVE_ENERGY_BURNED,
    HealthDataType.SLEEP_ASLEEP,
  ];

  List<HealthDataAccess> get _readPerms =>
      _types.map((_) => HealthDataAccess.READ).toList();

  bool _configured = false;

  Future<void> _ensureConfigured() async {
    if (_configured) return;
    await _health.configure();
    _configured = true;
  }

  /// En Android, indica si Health Connect está disponible / hay que instalarlo.
  Future<HealthConnectSdkStatus?> sdkStatus() async {
    await _ensureConfigured();
    return _health.getHealthConnectSdkStatus();
  }

  Future<void> installHealthConnect() => _health.installHealthConnect();

  Future<bool> hasPermissions() async {
    await _ensureConfigured();
    final granted = await _health.hasPermissions(
      _types,
      permissions: _readPerms,
    );
    return granted ?? false;
  }

  Future<bool> requestPermissions() async {
    await _ensureConfigured();
    return _health.requestAuthorization(_types, permissions: _readPerms);
  }

  double? _numeric(HealthValue value) =>
      value is NumericHealthValue ? value.numericValue.toDouble() : null;

  /// Lee el resumen de hoy. Devuelve null si falla la lectura (sin permisos, etc.).
  Future<HealthSummary?> fetchToday() async {
    await _ensureConfigured();
    final now = DateTime.now();
    final startOfDay = DateTime(now.year, now.month, now.day);
    // El sueño se busca desde las 18:00 de ayer para cubrir la noche anterior.
    final sleepFrom = startOfDay.subtract(const Duration(hours: 6));

    try {
      final steps = await _health.getTotalStepsInInterval(startOfDay, now) ?? 0;

      final hrPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.HEART_RATE],
        startTime: startOfDay,
        endTime: now,
      );
      final hrValues = hrPoints
          .map((p) => _numeric(p.value))
          .whereType<double>()
          .toList();
      final avgHeartRate = hrValues.isEmpty
          ? null
          : hrValues.reduce((a, b) => a + b) / hrValues.length;

      final calPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.ACTIVE_ENERGY_BURNED],
        startTime: startOfDay,
        endTime: now,
      );
      final calValues = calPoints
          .map((p) => _numeric(p.value))
          .whereType<double>()
          .toList();
      final activeCalories = calValues.isEmpty
          ? null
          : calValues.reduce((a, b) => a + b);

      final sleepPoints = await _health.getHealthDataFromTypes(
        types: [HealthDataType.SLEEP_ASLEEP],
        startTime: sleepFrom,
        endTime: now,
      );
      final sleepMinutes = sleepPoints.isEmpty
          ? null
          : sleepPoints
                .map((p) => p.dateTo.difference(p.dateFrom).inMinutes)
                .fold<int>(0, (a, b) => a + b);

      return HealthSummary(
        steps: steps,
        avgHeartRate: avgHeartRate,
        activeCalories: activeCalories,
        sleepMinutes: sleepMinutes,
      );
    } catch (e, st) {
      developer.log(
        'Error leyendo datos de salud',
        name: 'HealthService',
        error: e,
        stackTrace: st,
      );
      return null;
    }
  }
}
