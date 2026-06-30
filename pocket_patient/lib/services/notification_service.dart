import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../providers/auth_provider.dart';

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
class NotificationService {
  final ProviderContainer container;
  final GlobalKey<NavigatorState> navigatorKey;

  NotificationService({required this.container, required this.navigatorKey});

  Future<void> init() async {
    // Request permission on first launch. iOS returns the live status here;
    // Android 13+ shows the system prompt and reports the result too.
    final settings = await FirebaseMessaging.instance.requestPermission(
      alert: true,
      badge: true,
      sound: true,
    );

    FirebaseMessaging.onMessage.listen(_handleForegroundMessage);
    FirebaseMessaging.onMessageOpenedApp.listen(_navigate);

    // App launched from a terminated state by tapping a notification.
    final initialMessage = await FirebaseMessaging.instance.getInitialMessage();
    if (initialMessage != null) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _navigate(initialMessage));
    }

    FirebaseMessaging.instance.onTokenRefresh.listen(_registerToken);

    final token = await FirebaseMessaging.instance.getToken();
    if (token != null) await _registerToken(token);

    // Notifications drive the entire async case model, so if the student
    // declined, explain what they lose. init() runs before the first frame,
    // so defer the banner until a navigator context exists.
    final granted =
        settings.authorizationStatus == AuthorizationStatus.authorized ||
            settings.authorizationStatus == AuthorizationStatus.provisional;
    if (!granted) {
      WidgetsBinding.instance
          .addPostFrameCallback((_) => _showPermissionRationale());
    }
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
        // Session/course no longer reachable (e.g. case closed) — fall
        // through to home.
      }
    }

    if (context.mounted) context.go('/home');
  }
}
