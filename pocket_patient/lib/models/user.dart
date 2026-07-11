import 'package:flutter/material.dart' show TimeOfDay;

TimeOfDay? _parseTime(String? raw) {
  if (raw == null) return null;
  final parts = raw.split(':');
  if (parts.length < 2) return null;
  final hour = int.tryParse(parts[0]);
  final minute = int.tryParse(parts[1]);
  if (hour == null || minute == null) return null;
  return TimeOfDay(hour: hour, minute: minute);
}

String _formatTime(TimeOfDay t) =>
    '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

class AppUser {
  final String id;
  final String email;
  final String? role;
  final String? displayName;
  final bool isVerified;
  final bool pushEnabled;
  final TimeOfDay? quietHoursStart;
  final TimeOfDay? quietHoursEnd;

  const AppUser({
    required this.id,
    required this.email,
    this.role,
    this.displayName,
    required this.isVerified,
    this.pushEnabled = true,
    this.quietHoursStart,
    this.quietHoursEnd,
  });

  factory AppUser.fromJson(Map<String, dynamic> json) => AppUser(
        id: json['id'] as String,
        email: json['email'] as String,
        role: json['role'] as String?,
        displayName: json['display_name'] as String?,
        isVerified: json['is_verified'] as bool? ?? false,
        pushEnabled: json['push_enabled'] as bool? ?? true,
        quietHoursStart: _parseTime(json['quiet_hours_start'] as String?),
        quietHoursEnd: _parseTime(json['quiet_hours_end'] as String?),
      );

  AppUser copyWith({
    String? role,
    String? displayName,
    bool? isVerified,
    bool? pushEnabled,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    bool clearQuietHours = false,
  }) =>
      AppUser(
        id: id,
        email: email,
        role: role ?? this.role,
        displayName: displayName ?? this.displayName,
        isVerified: isVerified ?? this.isVerified,
        pushEnabled: pushEnabled ?? this.pushEnabled,
        quietHoursStart:
            clearQuietHours ? null : (quietHoursStart ?? this.quietHoursStart),
        quietHoursEnd:
            clearQuietHours ? null : (quietHoursEnd ?? this.quietHoursEnd),
      );
}

/// "HH:MM:SS" formatter shared with ApiService.updateNotificationPreferences.
String formatTimeOfDayForApi(TimeOfDay t) => _formatTime(t);
