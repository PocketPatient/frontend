import 'dart:async';

import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../providers/auth_provider.dart';
import '../providers/session_provider.dart';

/// Top-level background message handler, required by firebase_messaging.
///
/// No work is needed here: PocketPatient always sends a `notification`
/// payload alongside `data`, so the OS displays the system notification
/// automatically while the app is backgrounded or terminated. This handler
/// just satisfies the plugin's registration requirement.
@pragma('vm:entry-point')
Future<void> firebaseMessagingBackgroundHandler(RemoteMessage message) async {}

/// Wires up FCM token registration and the three notification states
/// (foreground banner, background tap, terminated launch) to in-app
/// navigation.
/// The app-wide [NotificationService], provided by main(). Null in tests and
/// anywhere main() didn't wire it up.
final notificationServiceProvider =
    Provider<NotificationService?>((ref) => null);

class NotificationService {
  static const _kPushPromptedKey = 'push_permission_prompted_v1';

  final ProviderContainer container;
  final GlobalKey<NavigatorState> navigatorKey;

  NotificationService({required this.container, required this.navigatorKey});

  Future<void> init() async {
    // No permission prompt at launch: it happens once, after sign-in
    // (onSignedIn), so the user knows what the app is first.

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_navigate);

    // App launched from a terminated state by tapping a notification.
    try {
      final initialMessage = await FirebaseMessaging.instance
          .getInitialMessage()
          .timeout(const Duration(seconds: 3));
      if (initialMessage != null) {
        WidgetsBinding.instance
            .addPostFrameCallback((_) => _navigate(initialMessage));
      }
    } catch (_) {
      // Never block app startup on messaging.
    }

    FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);

    // Fetch the FCM token in the background: init() runs before runApp(), and
    // on iOS getToken() throws or stalls until an APNs token exists (e.g.
    // before notification permission is granted), which would leave the app
    // stuck on the launch screen.
    unawaited(_registerCurrentToken());
  }

  /// Call when a signed-in user reaches the home screen. The first time on
  /// this install, asks for push permission; afterwards (and after granting),
  /// registers this device's token for the current account — the launch-time
  /// registration runs before sign-in and is rejected without a session.
  Future<void> onSignedIn() async {
    try {
      final prefs = await SharedPreferences.getInstance();
      if (!(prefs.getBool(_kPushPromptedKey) ?? false)) {
        await prefs.setBool(_kPushPromptedKey, true);
        await FirebaseMessaging.instance
            .requestPermission(alert: true, badge: true, sound: true);
      }
      final settings =
          await FirebaseMessaging.instance.getNotificationSettings();
      if (settings.authorizationStatus == AuthorizationStatus.authorized ||
          settings.authorizationStatus == AuthorizationStatus.provisional) {
        await _registerCurrentToken();
      }
    } catch (_) {
      // Never let notification setup break the home screen.
    }
  }

  Future<void> _registerCurrentToken() async {
    try {
      if (defaultTargetPlatform == TargetPlatform.iOS) {
        // Right after permission is granted iOS needs a moment to deliver the
        // APNs token; poll briefly instead of giving up on the first null.
        String? apnsToken;
        for (var i = 0; i < 10 && apnsToken == null; i++) {
          apnsToken = await FirebaseMessaging.instance
              .getAPNSToken()
              .timeout(const Duration(seconds: 5));
          if (apnsToken == null) await Future.delayed(const Duration(seconds: 1));
        }
        // Still none: onTokenRefresh fires once one is available.
        if (apnsToken == null) return;
      }
      final token = await FirebaseMessaging.instance
          .getToken()
          .timeout(const Duration(seconds: 10));
      if (token != null) await _registerToken(token);
    } catch (_) {
      // Best-effort — retried on token refresh or next app start.
    }
  }

  /// Call from a user-initiated reminder setting, never at app launch.
  Future<bool> requestPermissionForReminders() async {
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) _showPermissionRationale();
    return granted;
  }

  /// Shown when notification permission was denied. Kept dependency-free —
  /// an informational banner rather than a deep link into system settings.
  void _showPermissionRationale() {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      const SnackBar(
        content: Text(
          'Notifications are off. You won’t be alerted when a patient '
          'reaches out or replies — turn them on in your device settings.',
        ),
        duration: Duration(seconds: 6),
      ),
    );
  }

  Future<void> _registerToken(String token) async {
    try {
      await container.read(apiServiceProvider).updateFcmToken(token);
    } catch (_) {
      // Best-effort — retried on next app start or token refresh.
    }
  }

  /// Foreground: app is open, so FCM does not show a system notification.
  /// Show an in-app banner instead.
  void _handleForegroundMessage(RemoteMessage message) {
    // The chat screen has no polling — a patient reply that lands while the
    // user is already looking at it would otherwise only appear after a
    // manual pull-to-refresh. Refresh the session in the background so it
    // shows up immediately, independent of whether the banner below is seen.
    if (message.data['type'] == 'new_message') {
      unawaited(_refreshSessionFor(message.data['session_id']));
    }

    final notification = message.notification;
    final context = navigatorKey.currentContext;
    if (notification == null || context == null) return;

    ScaffoldMessenger.of(context).showSnackBar(
      SnackBar(
        content: Text(
          [notification.title, notification.body]
              .whereType<String>()
              .join(': '),
        ),
        action: SnackBarAction(
          label: 'View',
          onPressed: () => _navigate(message),
        ),
        duration: const Duration(seconds: 4),
      ),
    );
  }

  /// Looks up the session's course and refreshes its [sessionProvider] so a
  /// patient reply that arrived via push is pulled into state without
  /// requiring a manual pull-to-refresh. Best-effort — silently gives up if
  /// the session is no longer reachable (e.g. case closed).
  Future<void> _refreshSessionFor(String? sessionId) async {
    if (sessionId == null) return;
    try {
      final api = container.read(apiServiceProvider);
      final session = await api.getSession(sessionId);
      await container
          .read(sessionProvider(session.courseId).notifier)
          .refresh();
    } catch (_) {}
  }

  /// Background tap or terminated launch: route based on the `data` payload.
  /// `type: "new_message"` -> the chat for that session.
  /// `type: "new_case"` -> home (the new case will appear there).
  Future<void> _navigate(RemoteMessage message) async {
    final context = navigatorKey.currentContext;
    if (context == null) return;

    final type = message.data['type'];
    final sessionId = message.data['session_id'];

    if (type == 'new_message' && sessionId != null) {
      try {
        final api = container.read(apiServiceProvider);
        final session = await api.getSession(sessionId);
        final course = await api.getCourse(session.courseId);
        if (!context.mounted) return;
        context.push('/chat/${course.id}', extra: course);
        return;
      } catch (_) {
        // Session/course no longer reachable (e.g. case closed). Tell the
        // student rather than silently dropping them on home with no
        // explanation — this is the tap-a-stale-notification path (Week 11).
        if (context.mounted) {
          ScaffoldMessenger.of(context).showSnackBar(
            const SnackBar(content: Text('This case has been closed.')),
          );
        }
      }
    }

    if (context.mounted) context.go('/home');
  }
}
