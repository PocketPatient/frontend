enum MessageRole { student, patient, system }

class ChatMessage {
  final String id;
  final MessageRole role;
  final String content;
  final DateTime sentAt;
  final double? responseLatencySec;

  const ChatMessage({
    required this.id,
    required this.role,
    required this.content,
    required this.sentAt,
    this.responseLatencySec,
  });

  bool get isPatient =>
      role == MessageRole.patient || role == MessageRole.system;

  factory ChatMessage.fromJson(Map<String, dynamic> json) {
    final roleStr = json['role'] as String;
    final role = switch (roleStr) {
      'patient' => MessageRole.patient,
      'system' => MessageRole.system,
      _ => MessageRole.student,
    };
    return ChatMessage(
      id: json['id'] as String,
      role: role,
      content: json['content'] as String,
      sentAt: DateTime.parse(json['sent_at'] as String),
      responseLatencySec: (json['response_latency_sec'] as num?)?.toDouble(),
    );
  }
}

class ChatSession {
  final String id;
  final String diseaseId;
  final String courseId;
  final String status; // 'active' | 'diagnosed' | 'abandoned'
  final int turnCount;
  final DateTime startedAt;
  final List<ChatMessage> messages;

  const ChatSession({
    required this.id,
    required this.diseaseId,
    required this.courseId,
    required this.status,
    required this.turnCount,
    required this.startedAt,
    required this.messages,
  });

  bool get isActive => status == 'active';

  ChatSession copyWith({List<ChatMessage>? messages, int? turnCount}) =>
      ChatSession(
        id: id,
        diseaseId: diseaseId,
        courseId: courseId,
        status: status,
        turnCount: turnCount ?? this.turnCount,
        startedAt: startedAt,
        messages: messages ?? this.messages,
      );

  factory ChatSession.fromJson(Map<String, dynamic> json) => ChatSession(
        id: json['id'] as String,
        diseaseId: json['disease_id'] as String,
        courseId: json['course_id'] as String,
        status: (json['status'] as String?) ?? 'active',
        turnCount: json['turn_count'] as int? ?? 0,
        startedAt: DateTime.parse(json['started_at'] as String),
        messages: json['messages'] != null
            ? (json['messages'] as List)
                .map((e) => ChatMessage.fromJson(e as Map<String, dynamic>))
                .toList()
            : const [],
      );
}
