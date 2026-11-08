import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_patient/models/chat_session.dart';
import 'package:pocket_patient/utils/api_date.dart';

void main() {
  test('API timestamps are shown in device-local time, same instant', () {
    final dt = parseApiDate('2026-11-08T13:58:00+00:00');
    expect(dt.isUtc, isFalse);
    expect(dt.isAtSameMomentAs(DateTime.utc(2026, 11, 8, 13, 58)), isTrue);
    expect(dt.hour, DateTime.utc(2026, 11, 8, 13, 58).toLocal().hour);
  });

  test('tryParseApiDate handles null and garbage', () {
    expect(tryParseApiDate(null), isNull);
    expect(tryParseApiDate('not a date'), isNull);
    expect(tryParseApiDate('2026-11-08T13:58:00Z')?.isUtc, isFalse);
  });

  test('chat messages parse sent_at as local time', () {
    final msg = ChatMessage.fromJson({
      'id': 'm1',
      'role': 'patient',
      'content': 'hi',
      'sent_at': '2026-11-08T13:58:00+00:00',
    });
    expect(msg.sentAt.isUtc, isFalse);
  });
}
