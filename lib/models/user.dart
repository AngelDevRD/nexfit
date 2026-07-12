class AppUser {
  // String en vez de int: el id ahora puede venir del backend FastAPI (numerico,
  // serializado como string) o de Supabase Auth (UUID) -- ver
  // lib/core/auth/auth_repository.dart.
  final String id;
  final String email;
  final String name;
  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;
  final double? bodyFatPct;
  final String? goal;
  final String? experienceLevel;

  AppUser({
    required this.id,
    required this.email,
    required this.name,
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.bodyFatPct,
    this.goal,
    this.experienceLevel,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
    id: json['id'].toString(),
    email: json['email'],
    name: json['name'],
    age: json['age'],
    sex: json['sex'],
    heightCm: (json['height_cm'] as num?)?.toDouble(),
    weightKg: (json['weight_kg'] as num?)?.toDouble(),
    bodyFatPct: (json['body_fat_pct'] as num?)?.toDouble(),
    goal: json['goal'],
    experienceLevel: json['experience_level'],
  );

  bool get hasCompleteProfile =>
      age != null && sex != null && heightCm != null && weightKg != null;
}

const goalOptions = <String, String>{
  'hypertrophy': 'Hipertrofia',
  'strength': 'Fuerza',
  'fat_loss': 'Pérdida de grasa',
  'recomposition': 'Recomposición corporal',
  'endurance': 'Resistencia',
  'sport_prep': 'Preparación deportiva',
};

const experienceOptions = <String, String>{
  'beginner': 'Principiante',
  'intermediate': 'Intermedio',
  'advanced': 'Avanzado',
};

const sexOptions = <String, String>{'male': 'Masculino', 'female': 'Femenino'};
