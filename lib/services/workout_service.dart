import '../core/api_client.dart';
import '../models/workout.dart';

class WorkoutService {
  final ApiClient client;

  WorkoutService(this.client);

  Future<WorkoutSession> startSession({int? routineId}) async {
    final data = await client.post(
      '/api/v1/workouts',
      body: {if (routineId != null) 'routine_id': routineId},
    );
    return WorkoutSession.fromJson(data);
  }

  Future<WorkoutSession> get(int sessionId) async {
    final data = await client.get('/api/v1/workouts/$sessionId');
    return WorkoutSession.fromJson(data);
  }

  Future<WorkoutSession> finishSession(int sessionId) async {
    final data = await client.patch(
      '/api/v1/workouts/$sessionId',
      body: {'ended_at': DateTime.now().toUtc().toIso8601String()},
    );
    return WorkoutSession.fromJson(data);
  }

  Future<WorkoutSet> addSet(int sessionId, Map<String, dynamic> payload) async {
    final data = await client.post(
      '/api/v1/workouts/$sessionId/sets',
      body: payload,
    );
    return WorkoutSet.fromJson(data);
  }

  Future<WorkoutSet> updateSet(int setId, Map<String, dynamic> payload) async {
    final data = await client.patch(
      '/api/v1/workouts/sets/$setId',
      body: payload,
    );
    return WorkoutSet.fromJson(data);
  }

  Future<void> deleteSet(int setId) =>
      client.delete('/api/v1/workouts/sets/$setId');

  Future<List<PersonalRecord>> sessionRecords(int sessionId) async {
    final data = await client.get('/api/v1/workouts/$sessionId/records');
    return (data as List).map((e) => PersonalRecord.fromJson(e)).toList();
  }

  Future<List<WorkoutSessionSummary>> history({
    int? exerciseId,
    String? muscleGroup,
    int? routineId,
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, dynamic>{
      if (exerciseId != null) 'exercise_id': exerciseId,
      if (muscleGroup != null) 'muscle_group': muscleGroup,
      if (routineId != null) 'routine_id': routineId,
      if (dateFrom != null)
        'date_from': dateFrom.toIso8601String().split('T').first,
      if (dateTo != null) 'date_to': dateTo.toIso8601String().split('T').first,
    };
    final data = await client.get('/api/v1/workouts', query: query);
    return (data as List)
        .map((e) => WorkoutSessionSummary.fromJson(e))
        .toList();
  }
}
