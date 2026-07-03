import '../core/api_client.dart';
import '../models/calendar.dart';

class CalendarService {
  final ApiClient client;

  CalendarService(this.client);

  Future<CalendarOverview> overview() async {
    final data = await client.get('/api/v1/calendar/overview');
    return CalendarOverview.fromJson(data);
  }
}
