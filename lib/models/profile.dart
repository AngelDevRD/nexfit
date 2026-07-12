/// Perfil extendido del usuario (Fase 2, ver docs/ARQUITECTURA_BACKEND.md).
/// Separado de `AppUser` (identidad/sesión, Fase 1) a propósito -- el perfil
/// es un dato del usuario como rutinas u objetivos, no parte de auth.
class Profile {
  final String id;
  final String name;
  final int? age;
  final String? sex;
  final double? heightCm;
  final double? weightKg;
  final double? bodyFatPct;
  final String? goal;
  final String? experienceLevel;

  const Profile({
    required this.id,
    required this.name,
    this.age,
    this.sex,
    this.heightCm,
    this.weightKg,
    this.bodyFatPct,
    this.goal,
    this.experienceLevel,
  });

  bool get hasCompleteProfile =>
      age != null && sex != null && heightCm != null && weightKg != null;

  Profile copyWith({
    String? name,
    int? age,
    String? sex,
    double? heightCm,
    double? weightKg,
    double? bodyFatPct,
    String? goal,
    String? experienceLevel,
  }) => Profile(
    id: id,
    name: name ?? this.name,
    age: age ?? this.age,
    sex: sex ?? this.sex,
    heightCm: heightCm ?? this.heightCm,
    weightKg: weightKg ?? this.weightKg,
    bodyFatPct: bodyFatPct ?? this.bodyFatPct,
    goal: goal ?? this.goal,
    experienceLevel: experienceLevel ?? this.experienceLevel,
  );
}
