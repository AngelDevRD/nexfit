import '../core/api_client.dart';
import '../models/nutrition.dart';

class NutritionService {
  final ApiClient client;

  NutritionService(this.client);

  Future<NutritionLog> upsert(Map<String, dynamic> payload) async {
    final data = await client.put('/api/v1/nutrition/logs', body: payload);
    return NutritionLog.fromJson(data);
  }

  Future<List<NutritionLog>> list({
    DateTime? dateFrom,
    DateTime? dateTo,
  }) async {
    final query = <String, dynamic>{
      if (dateFrom != null)
        'date_from': dateFrom.toIso8601String().split('T').first,
      if (dateTo != null) 'date_to': dateTo.toIso8601String().split('T').first,
    };
    final data = await client.get('/api/v1/nutrition/logs', query: query);
    return (data as List).map((e) => NutritionLog.fromJson(e)).toList();
  }

  Future<void> delete(DateTime date) => client.delete(
    '/api/v1/nutrition/logs/${date.toIso8601String().split('T').first}',
  );
}
