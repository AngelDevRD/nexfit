import '../core/api_client.dart';
import '../core/api_exception.dart';
import '../models/recovery.dart';

class RecoveryService {
  final ApiClient client;

  RecoveryService(this.client);

  Future<void> upsertCheckIn(
    DateTime date,
    double sleepHours,
    int perceivedFatigue,
  ) async {
    await client.put(
      '/api/v1/recovery/checkins',
      body: {
        'checkin_date': date.toIso8601String().split('T').first,
        'sleep_hours': sleepHours,
        'perceived_fatigue': perceivedFatigue,
      },
    );
  }

  Future<RecoveryIndex?> index() async {
    try {
      final data = await client.get('/api/v1/recovery/index');
      return RecoveryIndex.fromJson(data);
    } on ApiException catch (e) {
      if (e.statusCode == 404) return null;
      rethrow;
    }
  }
}
