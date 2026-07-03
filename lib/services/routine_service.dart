import '../core/api_client.dart';
import '../models/routine.dart';

class RoutineService {
  final ApiClient client;

  RoutineService(this.client);

  Future<List<RoutineSummary>> list() async {
    final data = await client.get('/api/v1/routines');
    return (data as List).map((e) => RoutineSummary.fromJson(e)).toList();
  }

  Future<Routine> get(int id) async {
    final data = await client.get('/api/v1/routines/$id');
    return Routine.fromJson(data);
  }

  Future<Routine> create(Map<String, dynamic> payload) async {
    final data = await client.post('/api/v1/routines', body: payload);
    return Routine.fromJson(data);
  }

  Future<void> delete(int id) => client.delete('/api/v1/routines/$id');
}
