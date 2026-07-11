import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_patient/models/chat_session.dart';

ChatMessage _msg({
  required MessageRole role,
  required DateTime sentAt,
  String id = 'm',
}) =>
    ChatMessage(id: id, role: role, content: 'x', sentAt: sentAt);

ChatSession _session({
  String status = 'active',
  required List<ChatMessage> messages,
}) =>
    ChatSession(
      id: 's',
      diseaseId: 'd',
      courseId: 'c',
      status: status,
      turnCount: messages.length,
      startedAt: DateTime.now().subtract(const Duration(days: 3)),
      messages: messages,
      patientName: 'Test Patient',
      patientAge: 30,
      patientGender: 'unknown',
    );

void main() {
  final now = DateTime.now();
  DateTime ago(Duration d) => now.subtract(d);

  group('ChatSession.waitLevel', () {
    test('no messages → none', () {
      expect(_session(messages: const []).waitLevel, WaitLevel.none);
    });

    test('student sent the most recent message → none', () {
      expect(
        _session(messages: [
          _msg(role: MessageRole.patient, sentAt: ago(const Duration(days: 5))),
          _msg(role: MessageRole.student, sentAt: ago(const Duration(hours: 1))),
        ]).waitLevel,
        WaitLevel.none,
      );
    });

    test('patient waiting < 12h → none', () {
      expect(
        _session(messages: [
          _msg(role: MessageRole.patient, sentAt: ago(const Duration(hours: 11, minutes: 59))),
        ]).waitLevel,
        WaitLevel.none,
      );
    });

    test('patient waiting ≥ 12h → amber', () {
      expect(
        _session(messages: [
          _msg(role: MessageRole.patient, sentAt: ago(const Duration(hours: 12, minutes: 1))),
        ]).waitLevel,
        WaitLevel.amber,
      );
    });

    test('patient waiting ≥ 24h → orange', () {
      expect(
        _session(messages: [
          _msg(role: MessageRole.patient, sentAt: ago(const Duration(hours: 25))),
        ]).waitLevel,
        WaitLevel.orange,
      );
    });

    test('patient waiting ≥ 48h → red', () {
      expect(
        _session(messages: [
          _msg(role: MessageRole.patient, sentAt: ago(const Duration(hours: 49))),
        ]).waitLevel,
        WaitLevel.red,
      );
    });

    test('system/nudge message counts as patient waiting', () {
      expect(
        _session(messages: [
          _msg(role: MessageRole.system, sentAt: ago(const Duration(hours: 25))),
        ]).waitLevel,
        WaitLevel.orange,
      );
    });

    test('uses most recent message regardless of list order', () {
      expect(
        _session(messages: [
          _msg(role: MessageRole.patient, sentAt: ago(const Duration(hours: 2))),
          _msg(role: MessageRole.patient, sentAt: ago(const Duration(hours: 60))),
        ]).waitLevel,
        WaitLevel.none, // most recent is only 2h old
      );
    });

    test('non-active session → none even if long silence', () {
      expect(
        _session(status: 'diagnosed', messages: [
          _msg(role: MessageRole.patient, sentAt: ago(const Duration(days: 5))),
        ]).waitLevel,
        WaitLevel.none,
      );
    });
  });
}
