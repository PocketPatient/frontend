class Course {
  final String id;
  final String title;
  final String? semester;
  final String classCode;
  final String professorId;
  final bool isActive;
  final int studentCount;
  final String? msgWindowStart;
  final String? msgWindowEnd;
  final String msgTimezone;
  final DateTime createdAt;

  const Course({
    required this.id,
    required this.title,
    this.semester,
    required this.classCode,
    required this.professorId,
    required this.isActive,
    required this.studentCount,
    this.msgWindowStart,
    this.msgWindowEnd,
    required this.msgTimezone,
    required this.createdAt,
  });

  factory Course.fromJson(Map<String, dynamic> json) => Course(
        id: json['id'] as String,
        title: json['title'] as String,
        semester: json['semester'] as String?,
        classCode: json['class_code'] as String,
        professorId: json['professor_id'] as String,
        isActive: json['is_active'] as bool? ?? true,
        studentCount: json['student_count'] as int? ?? 0,
        msgWindowStart: json['msg_window_start'] as String?,
        msgWindowEnd: json['msg_window_end'] as String?,
        msgTimezone: json['msg_timezone'] as String? ?? 'America/New_York',
        createdAt: DateTime.parse(json['created_at'] as String),
      );
}
