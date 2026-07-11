/// A row in a paginated session list (GET /sessions?course_id&student_id).
/// Used by the professor transcript browser — despite the name, covers
/// active sessions too (backend only filters by status when asked to).
class CompletedSessionItem {
  final String sessionId;
  final String diseaseName;
  final String category;
  final double? score;
  final int turnCount;
  final DateTime startedAt;
  final DateTime? completedAt;
  final double? avgResponseLatencySec;

  const CompletedSessionItem({
    required this.sessionId,
    required this.diseaseName,
    required this.category,
    this.score,
    required this.turnCount,
    required this.startedAt,
    this.completedAt,
    this.avgResponseLatencySec,
  });

  bool get isActive => completedAt == null;

  factory CompletedSessionItem.fromJson(Map<String, dynamic> json) =>
      CompletedSessionItem(
        sessionId: json['session_id'] as String,
        diseaseName: json['disease_name'] as String,
        category: json['category'] as String,
        score: (json['score'] as num?)?.toDouble(),
        turnCount: json['turn_count'] as int,
        startedAt: DateTime.parse(json['started_at'] as String),
        completedAt: json['completed_at'] != null
            ? DateTime.parse(json['completed_at'] as String)
            : null,
        avgResponseLatencySec:
            (json['avg_response_latency_sec'] as num?)?.toDouble(),
      );
}

class PaginatedSessions {
  final List<CompletedSessionItem> items;
  final int total;
  final int page;
  final int pageSize;

  const PaginatedSessions({
    required this.items,
    required this.total,
    required this.page,
    required this.pageSize,
  });

  factory PaginatedSessions.fromJson(Map<String, dynamic> json) =>
      PaginatedSessions(
        items: (json['items'] as List)
            .map((e) => CompletedSessionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
        page: json['page'] as int,
        pageSize: json['page_size'] as int,
      );
}
