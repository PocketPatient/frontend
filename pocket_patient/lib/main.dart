import 'dart:async';

import 'package:firebase_core/firebase_core.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_native_splash/flutter_native_splash.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'app.dart';
import 'firebase_options.dart';
import 'providers/auth_provider.dart';
import 'services/notification_service.dart';

Future<void> main() async {
  final binding = WidgetsFlutterBinding.ensureInitialized();
  // Hold the launch screen until the stored session is checked, so a
  // signed-in user never sees the login page flash.
  FlutterNativeSplash.preserve(widgetsBinding: binding);
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

  // Usually instant (cached user). Without a cache this waits on the network,
  // so cap it: past that, the login screen shows its own loading state.
  unawaited(container
      .read(authNotifierProvider.future)
      .timeout(const Duration(seconds: 3))
      .then<void>((_) {}, onError: (_) {})
      .whenComplete(FlutterNativeSplash.remove));
}
