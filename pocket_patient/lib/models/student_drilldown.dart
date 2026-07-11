import 'completed_session_item.dart';
import 'student_summary.dart';

/// Mirrors backend's StudentDrilldown (GET /analytics/professor/student/{id})
/// — a StudentSummary plus the student's session list. The backend flattens
/// StudentSummary's fields into the same JSON object (Python's `**dict`), so
/// StudentSummary.fromJson works directly on this payload too.
class StudentDrilldown {
  final StudentSummary summary;
  final List<CompletedSessionItem> sessions;
  final int total;

  const StudentDrilldown({
    required this.summary,
    required this.sessions,
    required this.total,
  });

  factory StudentDrilldown.fromJson(Map<String, dynamic> json) => StudentDrilldown(
        summary: StudentSummary.fromJson(json),
        sessions: (json['sessions'] as List)
            .map((e) => CompletedSessionItem.fromJson(e as Map<String, dynamic>))
            .toList(),
        total: json['total'] as int,
      );
}
