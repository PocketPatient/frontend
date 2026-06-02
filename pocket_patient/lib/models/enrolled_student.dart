class EnrolledStudent {
  final String userId;
  final String email;
  final String? displayName;
  final DateTime enrolledAt;

  const EnrolledStudent({
    required this.userId,
    required this.email,
    this.displayName,
    required this.enrolledAt,
  });

  factory EnrolledStudent.fromJson(Map<String, dynamic> json) =>
      EnrolledStudent(
        userId: json['user_id'] as String,
        email: json['email'] as String,
        displayName: json['display_name'] as String?,
        enrolledAt: DateTime.parse(json['enrolled_at'] as String),
      );

  String get displayLabel => displayName?.isNotEmpty == true ? displayName! : email;
}
