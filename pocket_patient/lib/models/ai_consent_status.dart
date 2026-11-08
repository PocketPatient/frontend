import '../utils/api_date.dart';

class AiConsentStatus {
  final bool active;
  final String requiredVersion;
  final String? acceptedVersion;
  final DateTime? acceptedAt;

  const AiConsentStatus({
    required this.active,
    required this.requiredVersion,
    this.acceptedVersion,
    this.acceptedAt,
  });

  factory AiConsentStatus.fromJson(Map<String, dynamic> json) =>
      AiConsentStatus(
        active: json['active'] as bool? ?? false,
        requiredVersion: json['required_version'] as String? ?? '',
        acceptedVersion: json['accepted_version'] as String?,
        acceptedAt: tryParseApiDate(json['accepted_at'] as String?),
      );
}
