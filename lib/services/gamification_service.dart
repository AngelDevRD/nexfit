import '../core/api_client.dart';
import '../models/gamification.dart';

class GamificationService {
  final ApiClient client;

  GamificationService(this.client);

  Future<GamificationProfile> profile() async {
    final data = await client.get('/api/v1/gamification/profile');
    return GamificationProfile.fromJson(data);
  }
}
