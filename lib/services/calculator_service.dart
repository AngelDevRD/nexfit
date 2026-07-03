import '../core/api_client.dart';

class CalculatorService {
  final ApiClient client;

  CalculatorService(this.client);

  Future<Map<String, dynamic>> oneRepMax(double weightKg, int reps) async {
    final data = await client.post(
      '/api/v1/calculators/one-rep-max',
      body: {'weight_kg': weightKg, 'reps': reps},
      auth: false,
    );
    return data;
  }

  Future<Map<String, dynamic>> bmi(double weightKg, double heightCm) async {
    final data = await client.post(
      '/api/v1/calculators/bmi',
      body: {'weight_kg': weightKg, 'height_cm': heightCm},
      auth: false,
    );
    return data;
  }

  Future<Map<String, dynamic>> leanBodyMass(
    double weightKg,
    double heightCm,
    String sex, {
    double? bodyFatPct,
  }) async {
    final data = await client.post(
      '/api/v1/calculators/lean-body-mass',
      body: {
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'sex': sex,
        if (bodyFatPct != null) 'body_fat_pct': bodyFatPct,
      },
      auth: false,
    );
    return data;
  }

  Future<Map<String, dynamic>> idealWeight(double heightCm, String sex) async {
    final data = await client.post(
      '/api/v1/calculators/ideal-weight',
      body: {'height_cm': heightCm, 'sex': sex},
      auth: false,
    );
    return data;
  }

  Future<Map<String, dynamic>> nutrition({
    required double weightKg,
    required double heightCm,
    required int age,
    required String sex,
    required String activityLevel,
    required String goal,
  }) async {
    final data = await client.post(
      '/api/v1/calculators/nutrition',
      body: {
        'weight_kg': weightKg,
        'height_cm': heightCm,
        'age': age,
        'sex': sex,
        'activity_level': activityLevel,
        'goal': goal,
      },
      auth: false,
    );
    return data;
  }

  Future<Map<String, dynamic>> waterIntake(double weightKg) async {
    final data = await client.post(
      '/api/v1/calculators/water-intake',
      body: {'weight_kg': weightKg},
      auth: false,
    );
    return data;
  }

  Future<Map<String, dynamic>> fatLossRate(
    double currentWeightKg,
    double targetWeightKg,
  ) async {
    final data = await client.post(
      '/api/v1/calculators/fat-loss-rate',
      body: {
        'current_weight_kg': currentWeightKg,
        'target_weight_kg': targetWeightKg,
      },
      auth: false,
    );
    return data;
  }
}

const activityLevelOptions = <String, String>{
  'sedentary': 'Sedentario',
  'light': 'Actividad ligera',
  'moderate': 'Actividad moderada',
  'active': 'Activo',
  'very_active': 'Muy activo',
};
