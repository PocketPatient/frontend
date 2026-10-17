import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  WidgetsFlutterBinding.ensureInitialized();
  await Firebase.initializeApp(options: DefaultFirebaseOptions.currentPlatform);
  FirebaseMessaging.onBackgroundMessage(firebaseMessagingBackgroundHandler);

  late final NotificationService notificationService;
  final container = ProviderContainer(overrides: [
    // Provider is read lazily, after notificationService is assigned below.
    notificationServiceProvider.overrideWith((ref) => notificationService),
  ]);
  notificationService = NotificationService(
    container: container,
    navigatorKey: container.read(navigatorKeyProvider),
  );
  await notificationService.init();

  runApp(UncontrolledProviderScope(container: container, child: const App()));
}
