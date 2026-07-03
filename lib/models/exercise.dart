class ExerciseSummary {
  final int id;
  final String slug;
  final String name;
  final String muscleGroup;
  final String difficulty;
  final String? imageUrl;

  ExerciseSummary({
    required this.id,
    required this.slug,
    required this.name,
    required this.muscleGroup,
    required this.difficulty,
    this.imageUrl,
  });

  factory ExerciseSummary.fromJson(Map<String, dynamic> json) =>
      ExerciseSummary(
        id: json['id'],
        slug: json['slug'],
        name: json['name'],
        muscleGroup: json['muscle_group'],
        difficulty: json['difficulty'],
        imageUrl: json['image_url'],
      );
}

class Exercise {
  final int id;
  final String slug;
  final String name;
  final String muscleGroup;
  final List<String> primaryMuscles;
  final List<String> secondaryMuscles;
  final List<String> equipment;
  final String difficulty;
  final String movementType;
  final String? imageUrl;
  final String? animationUrl;
  final String description;
  final List<String> instructions;
  final List<String> tips;
  final List<String> commonMistakes;
  final List<String> variants;
  final List<String> benefits;

  Exercise({
    required this.id,
    required this.slug,
    required this.name,
    required this.muscleGroup,
    required this.primaryMuscles,
    required this.secondaryMuscles,
    required this.equipment,
    required this.difficulty,
    required this.movementType,
    this.imageUrl,
    this.animationUrl,
    required this.description,
    required this.instructions,
    required this.tips,
    required this.commonMistakes,
    required this.variants,
    required this.benefits,
  });

  static List<String> _strList(dynamic value) =>
      (value as List).map((e) => e.toString()).toList();

  factory Exercise.fromJson(Map<String, dynamic> json) => Exercise(
    id: json['id'],
    slug: json['slug'],
    name: json['name'],
    muscleGroup: json['muscle_group'],
    primaryMuscles: _strList(json['primary_muscles']),
    secondaryMuscles: _strList(json['secondary_muscles']),
    equipment: _strList(json['equipment']),
    difficulty: json['difficulty'],
    movementType: json['movement_type'],
    imageUrl: json['image_url'],
    animationUrl: json['animation_url'],
    description: json['description'] ?? '',
    instructions: _strList(json['instructions']),
    tips: _strList(json['tips']),
    commonMistakes: _strList(json['common_mistakes']),
    variants: _strList(json['variants']),
    benefits: _strList(json['benefits']),
  );
}

const difficultyLabels = <String, String>{
  'beginner': 'Principiante',
  'intermediate': 'Intermedio',
  'advanced': 'Avanzado',
};
