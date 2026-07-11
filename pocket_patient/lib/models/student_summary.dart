/// Mirrors backend's StudentSummary (GET /analytics/student/summary).
class ScoreByCase {
  final String sessionId;
  final String diseaseName;
  final String category;
  final double? score;
  final DateTime? completedAt;

  const ScoreByCase({
    required this.sessionId,
    required this.diseaseName,
    required this.category,
    this.score,
    this.completedAt,
  });

  factory ScoreByCase.fromJson(Map<String, dynamic> json) => ScoreByCase(
        sessionId: json['session_id'] as String,
        diseaseName: json['disease_name'] as String,
        category: json['category'] as String,
        score: (json['score'] as num?)?.toDouble(),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
      );
}

class CategoryScore {
  final double avgScore;
  final int count;

  const CategoryScore({required this.avgScore, required this.count});

  factory CategoryScore.fromJson(Map<String, dynamic> json) => CategoryScore(
        avgScore: (json['avg_score'] as num).toDouble(),
        count: json['count'] as int,
      );
}

class ResponseTimePoint {
  final int caseNumber;
  final double? avgLatencySec;

  const ResponseTimePoint({required this.caseNumber, this.avgLatencySec});

  factory ResponseTimePoint.fromJson(Map<String, dynamic> json) =>
      ResponseTimePoint(
        caseNumber: json['case_number'] as int,
        avgLatencySec: (json['avg_latency_sec'] as num?)?.toDouble(),
      );
}

class StudentSummary {
  final int totalCases;
  final int completedCases;
  final double? avgScore;
  final double? avgResponseTimeSec;
  final List<ScoreByCase> scoresByCase;
  final Map<String, CategoryScore> scoresByCategory;
  final List<ResponseTimePoint> responseTimeTrend;
  final List<String> weakCategories;

  const StudentSummary({
    required this.totalCases,
    required this.completedCases,
    this.avgScore,
    this.avgResponseTimeSec,
    required this.scoresByCase,
    required this.scoresByCategory,
    required this.responseTimeTrend,
    required this.weakCategories,
  });

  /// Cases scored above 70 are correct.
  static const int _streakThreshold = 70;

  /// Consecutive most-recent cases scored > 70. scoresByCase order matches
  /// the backend's chronological ordering; walk from the end.
  int get currentStreak {
    var streak = 0;
    for (final s in scoresByCase.reversed) {
      if (s.score == null) continue;
      if (s.score! > _streakThreshold) {
        streak++;
      } else {
        break;
      }
    }
    return streak;
  }

  factory StudentSummary.fromJson(Map<String, dynamic> json) => StudentSummary(
        totalCases: json['total_cases'] as int,
        completedCases: json['completed_cases'] as int,
        avgScore: (json['avg_score'] as num?)?.toDouble(),
        avgResponseTimeSec: (json['avg_response_time_sec'] as num?)?.toDouble(),
        scoresByCase: (json['scores_by_case'] as List)
            .map((e) => ScoreByCase.fromJson(e as Map<String, dynamic>))
            .toList(),
        scoresByCategory: (json['scores_by_category'] as Map<String, dynamic>)
            .map((k, v) => MapEntry(k, CategoryScore.fromJson(v as Map<String, dynamic>))),
        responseTimeTrend: (json['response_time_trend'] as List)
            .map((e) => ResponseTimePoint.fromJson(e as Map<String, dynamic>))
            .toList(),
        weakCategories:
            (json['weak_categories'] as List).map((e) => e as String).toList(),
      );
}
