import '../core/api_client.dart';
import '../models/goal.dart';

class GoalService {
  final ApiClient client;

  GoalService(this.client);

  Future<List<Goal>> list() async {
    final data = await client.get('/api/v1/goals');
    return (data as List).map((e) => Goal.fromJson(e)).toList();
  }

  Future<Goal> create(Map<String, dynamic> payload) async {
    final data = await client.post('/api/v1/goals', body: payload);
    return Goal.fromJson(data);
  }

  Future<void> delete(int id) => client.delete('/api/v1/goals/$id');
}
