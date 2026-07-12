const _activityMultipliers = <String, double>{
  'sedentary': 1.2,
  'light': 1.375,
  'moderate': 1.55,
  'active': 1.725,
  'very_active': 1.9,
};

const _goalCalorieFactor = <String, double>{
  'fat_loss': 0.8,
  'hypertrophy': 1.1,
  'strength': 1.1,
  'recomposition': 1.0,
  'endurance': 1.05,
  'sport_prep': 1.05,
};

const _goalProteinPerKg = <String, double>{
  'fat_loss': 2.2,
  'hypertrophy': 2.0,
  'strength': 1.8,
  'recomposition': 2.0,
  'endurance': 1.6,
  'sport_prep': 1.8,
};

double _round(double value, int decimals) {
  final factor = decimals == 1 ? 10.0 : (decimals == 2 ? 100.0 : 1.0);
  return (value * factor).round() / factor;
}

const activityLevelOptions = <String, String>{
  'sedentary': 'Sedentario',
  'light': 'Actividad ligera',
  'moderate': 'Actividad moderada',
  'active': 'Activo',
  'very_active': 'Muy activo',
};

/// Reemplaza a `CalculatorService` (FastAPI) -- port directo de
/// `legacy/backend_fastapi/app/services/calculators.py`. Estas son funciones puras del
/// input del usuario (sin depender de historial ni de sesión), así que no
/// tenía sentido que dependieran de una llamada de red -- de hecho el
/// backend ya las servía con `auth: false` (Fase 3c).
class Calculators {
  const Calculators._();

  static double oneRepMax(double weightKg, int reps) {
    if (reps <= 1) return _round(weightKg, 1);
    return _round(weightKg * (1 + reps / 30), 1);
  }

  static (double bmi, String category) bmi(double weightKg, double heightCm) {
    final heightM = heightCm / 100;
    final value = weightKg / (heightM * heightM);
    final String category;
    if (value < 18.5) {
      category = 'bajo_peso';
    } else if (value < 25) {
      category = 'normal';
    } else if (value < 30) {
      category = 'sobrepeso';
    } else {
      category = 'obesidad';
    }
    return (_round(value, 1), category);
  }

  static double leanBodyMass(
    double weightKg,
    double heightCm,
    String sex, {
    double? bodyFatPct,
  }) {
    if (bodyFatPct != null) {
      return _round(weightKg * (1 - bodyFatPct / 100), 1);
    }
    final lbm = sex == 'male'
        ? 0.407 * weightKg + 0.267 * heightCm - 19.2
        : 0.252 * weightKg + 0.473 * heightCm - 48.3;
    return _round(lbm, 1);
  }

  static double idealWeight(double heightCm, String sex) {
    final heightIn = heightCm / 2.54;
    final base = sex == 'male' ? 50.0 : 45.5;
    final extra = heightIn - 60 > 0 ? heightIn - 60 : 0;
    return _round(base + 2.3 * extra, 1);
  }

  static double waterIntake(double weightKg) => _round(weightKg * 35, 0);

  static Map<String, double> nutrition({
    required double weightKg,
    required double heightCm,
    required int age,
    required String sex,
    required String activityLevel,
    required String goal,
  }) {
    final bmr = sex == 'male'
        ? 10 * weightKg + 6.25 * heightCm - 5 * age + 5
        : 10 * weightKg + 6.25 * heightCm - 5 * age - 161;

    final tdee = bmr * _activityMultipliers[activityLevel]!;
    final targetCalories = tdee * _goalCalorieFactor[goal]!;

    final proteinG = _goalProteinPerKg[goal]! * weightKg;
    final fatG = 0.8 * weightKg;
    final remainingCalories = targetCalories - (proteinG * 4) - (fatG * 9);
    final carbsG = remainingCalories / 4 > 0 ? remainingCalories / 4 : 0.0;

    return {
      'bmr': _round(bmr, 0),
      'tdee': _round(tdee, 0),
      'target_calories': _round(targetCalories, 0),
      'protein_g': _round(proteinG, 0),
      'carbs_g': _round(carbsG, 0),
      'fat_g': _round(fatG, 0),
      'water_ml': waterIntake(weightKg),
    };
  }

  static Map<String, double> fatLossRate(
    double currentWeightKg,
    double targetWeightKg,
  ) {
    final weightToLose = currentWeightKg - targetWeightKg;
    final minWeeklyLoss = currentWeightKg * 0.005;
    final maxWeeklyLoss = currentWeightKg * 0.01;
    final avgWeeklyLoss = (minWeeklyLoss + maxWeeklyLoss) / 2;
    final weeksEstimate = avgWeeklyLoss > 0
        ? weightToLose / avgWeeklyLoss
        : 0.0;

    return {
      'weight_to_lose_kg': _round(weightToLose, 1),
      'min_weekly_loss_kg': _round(minWeeklyLoss, 2),
      'max_weekly_loss_kg': _round(maxWeeklyLoss, 2),
      'estimated_weeks': _round(weeksEstimate, 1),
    };
  }
}
