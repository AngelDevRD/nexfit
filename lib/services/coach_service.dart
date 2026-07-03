import '../core/api_client.dart';

class CoachService {
  final ApiClient client;

  CoachService(this.client);

  Future<String> sendMessage(String message) async {
    final data = await client.post(
      '/api/v1/coach/chat',
      body: {'message': message},
    );
    return data['reply'];
  }
}
