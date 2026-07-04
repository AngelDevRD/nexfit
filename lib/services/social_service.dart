import '../core/api_client.dart';
import '../models/social.dart';

class SocialService {
  final ApiClient client;

  SocialService(this.client);

  Future<List<ChallengeSummary>> listMine() async {
    final data = await client.get('/api/v1/challenges') as List;
    return data.map((e) => ChallengeSummary.fromJson(e)).toList();
  }

  Future<ChallengeDetail> detail(int id) async {
    final data = await client.get('/api/v1/challenges/$id');
    return ChallengeDetail.fromJson(data);
  }

  Future<ChallengeDetail> create({
    required String name,
    String? description,
    required String metric,
    required DateTime startsOn,
    required DateTime endsOn,
  }) async {
    final data = await client.post(
      '/api/v1/challenges',
      body: {
        'name': name,
        'description': description,
        'metric': metric,
        'starts_on': _date(startsOn),
        'ends_on': _date(endsOn),
      },
    );
    return ChallengeDetail.fromJson(data);
  }

  Future<ChallengeDetail> join(String inviteCode) async {
    final data = await client.post(
      '/api/v1/challenges/join',
      body: {'invite_code': inviteCode},
    );
    return ChallengeDetail.fromJson(data);
  }

  Future<void> leave(int id) => client.delete('/api/v1/challenges/$id/leave');

  Future<void> remove(int id) => client.delete('/api/v1/challenges/$id');

  static String _date(DateTime d) =>
      '${d.year.toString().padLeft(4, '0')}-'
      '${d.month.toString().padLeft(2, '0')}-'
      '${d.day.toString().padLeft(2, '0')}';
}
