import 'goal.dart';
import 'stats.dart';

class DeloadRecommendation {
  final bool recommended;
  final String reason;

  DeloadRecommendation({required this.recommended, required this.reason});
}

class CalendarOverview {
  final List<Goal> upcomingGoals;
  final DeloadRecommendation deload;
  final List<RecordPrediction> upcomingRecordPredictions;

  CalendarOverview({
    required this.upcomingGoals,
    required this.deload,
    required this.upcomingRecordPredictions,
  });
}
