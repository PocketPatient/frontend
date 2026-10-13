import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_patient/models/ai_consent_status.dart';

void main() {
  group('AiConsentStatus', () {
    test('parses an active, versioned consent record', () {
      final status = AiConsentStatus.fromJson({
        'active': true,
        'required_version': '2026-10-v1',
        'accepted_version': '2026-10-v1',
        'accepted_at': '2026-10-06T16:00:00Z',
      });

      expect(status.active, isTrue);
      expect(status.requiredVersion, '2026-10-v1');
      expect(status.acceptedVersion, '2026-10-v1');
      expect(status.acceptedAt, DateTime.parse('2026-10-06T16:00:00Z'));
    });

    test('defaults safely to no consent for incomplete server data', () {
      final status = AiConsentStatus.fromJson(const {});

      expect(status.active, isFalse);
      expect(status.requiredVersion, isEmpty);
      expect(status.acceptedVersion, isNull);
      expect(status.acceptedAt, isNull);
    });
  });
}
