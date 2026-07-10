import 'diagnosis_result.dart';

enum MessageRole { student, patient, system }

/// How long the patient has been waiting on a student reply, bucketed into the
/// thresholds surfaced as response-time dots on the home screen (Week 10).
enum WaitLevel { none, amber, orange, red }

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
  final ScoreData? score;
  final RevealData? reveal;

  const ChatSession({
    required this.id,
    required this.diseaseId,
    required this.courseId,
    required this.status,
    required this.turnCount,
    required this.startedAt,
    required this.messages,
    this.score,
    this.reveal,
  });

  bool get isActive => status == 'active';
  bool get isDiagnosed => status == 'diagnosed';

  /// How long the patient has been waiting on the student, or null when the
  /// ball isn't in the student's court: no active case, no messages, or the
  /// student sent the most recent message. System/nudge messages count as the
  /// patient waiting (see [ChatMessage.isPatient]).
  ///
  /// Computed against the most recent message by `sentAt` rather than list
  /// position, so it's correct regardless of how [messages] is ordered.
  Duration? get studentSilence {
    if (!isActive || messages.isEmpty) return null;
    final mostRecent =
        messages.reduce((a, b) => a.sentAt.isAfter(b.sentAt) ? a : b);
    if (!mostRecent.isPatient) return null;
    return DateTime.now().difference(mostRecent.sentAt);
  }

  /// Response-time bucket for the home-screen dot. Evaluated at build time, so
  /// it refreshes on interaction (pull-to-refresh / provider invalidation)
  /// rather than ticking live.
  WaitLevel get waitLevel {
    final silence = studentSilence;
    if (silence == null) return WaitLevel.none;
    if (silence >= const Duration(hours: 48)) return WaitLevel.red;
    if (silence >= const Duration(hours: 24)) return WaitLevel.orange;
    if (silence >= const Duration(hours: 12)) return WaitLevel.amber;
    return WaitLevel.none;
  }

  ChatSession copyWith({
    List<ChatMessage>? messages,
    int? turnCount,
    String? status,
    ScoreData? score,
    RevealData? reveal,
  }) =>
      ChatSession(
        id: id,
        diseaseId: diseaseId,
        courseId: courseId,
        status: status ?? this.status,
        turnCount: turnCount ?? this.turnCount,
        startedAt: startedAt,
        messages: messages ?? this.messages,
        score: score ?? this.score,
        reveal: reveal ?? this.reveal,
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
        score: json['score'] != null
            ? ScoreData.fromJson(json['score'] as Map<String, dynamic>)
            : null,
        reveal: json['reveal'] != null
            ? RevealData.fromJson(json['reveal'] as Map<String, dynamic>)
            : null,
      );
}
