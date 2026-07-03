import 'goal.dart';
import 'stats.dart';

class DeloadRecommendation {
  final bool recommended;
  final String reason;

  DeloadRecommendation({required this.recommended, required this.reason});

  factory DeloadRecommendation.fromJson(Map<String, dynamic> json) =>
      DeloadRecommendation(
        recommended: json['recommended'],
        reason: json['reason'],
      );
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

  factory CalendarOverview.fromJson(Map<String, dynamic> json) =>
      CalendarOverview(
        upcomingGoals: (json['upcoming_goals'] as List)
            .map((e) => Goal.fromJson(e))
            .toList(),
        deload: DeloadRecommendation.fromJson(json['deload']),
        upcomingRecordPredictions: (json['upcoming_record_predictions'] as List)
            .map((e) => RecordPrediction.fromJson(e))
            .toList(),
      );
}
