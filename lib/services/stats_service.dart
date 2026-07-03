import '../core/api_client.dart';
import '../models/stats.dart';

class StatsService {
  final ApiClient client;

  StatsService(this.client);

  Future<List<MuscleVolumeEntry>> muscleAnalysis({int days = 30}) async {
    final data = await client.get(
      '/api/v1/stats/muscle-analysis',
      query: {'days': days},
    );
    return (data as List).map((e) => MuscleVolumeEntry.fromJson(e)).toList();
  }

  Future<StrengthProfile> strengthProfile() async {
    final data = await client.get('/api/v1/stats/strength-profile');
    return StrengthProfile.fromJson(data);
  }

  Future<List<ExerciseProgressEntry>> exerciseProgress(int exerciseId) async {
    final data = await client.get('/api/v1/stats/progress/$exerciseId');
    return (data as List)
        .map((e) => ExerciseProgressEntry.fromJson(e))
        .toList();
  }

  Future<List<TonnagePeriodEntry>> tonnage({
    String period = 'week',
    int periods = 12,
  }) async {
    final data = await client.get(
      '/api/v1/stats/tonnage',
      query: {'period': period, 'periods': periods},
    );
    return (data as List).map((e) => TonnagePeriodEntry.fromJson(e)).toList();
  }

  Future<TrainingStreak> streak() async {
    final data = await client.get('/api/v1/stats/streak');
    return TrainingStreak.fromJson(data);
  }
}
