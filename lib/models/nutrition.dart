class NutritionLog {
  final int id;
  final DateTime logDate;
  final double calories;
  final double proteinG;
  final double carbsG;
  final double fatG;
  final double waterMl;
  final String? notes;

  NutritionLog({
    required this.id,
    required this.logDate,
    required this.calories,
    required this.proteinG,
    required this.carbsG,
    required this.fatG,
    required this.waterMl,
    this.notes,
  });

  factory NutritionLog.fromJson(Map<String, dynamic> json) => NutritionLog(
    id: json['id'],
    logDate: DateTime.parse(json['log_date']),
    calories: (json['calories'] as num).toDouble(),
    proteinG: (json['protein_g'] as num).toDouble(),
    carbsG: (json['carbs_g'] as num).toDouble(),
    fatG: (json['fat_g'] as num).toDouble(),
    waterMl: (json['water_ml'] as num).toDouble(),
    notes: json['notes'],
  );
}
