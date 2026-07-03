import '../core/api_client.dart';
import '../models/exercise.dart';

class ExerciseService {
  final ApiClient client;

  ExerciseService(this.client);

  Future<List<ExerciseSummary>> list({String? muscleGroup}) async {
    final data = await client.get(
      '/api/v1/exercises',
      query: muscleGroup != null ? {'muscle_group': muscleGroup} : null,
    );
    return (data as List).map((e) => ExerciseSummary.fromJson(e)).toList();
  }

  Future<Exercise> get(int id) async {
    final data = await client.get('/api/v1/exercises/$id');
    return Exercise.fromJson(data);
  }
}
