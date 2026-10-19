import Flutter
import UIKit
import UserNotifications

@main
@objc class AppDelegate: FlutterAppDelegate, FlutterImplicitEngineDelegate {
  override func application(
    _ application: UIApplication,
    didFinishLaunchingWithOptions launchOptions: [UIApplication.LaunchOptionsKey: Any]?
  ) -> Bool {
    return super.application(application, didFinishLaunchingWithOptions: launchOptions)
  }

  func didInitializeImplicitFlutterEngine(_ engineBridge: FlutterImplicitEngineBridge) {
    GeneratedPluginRegistrant.register(with: engineBridge.pluginRegistry)

    // With the implicit (UIScene) engine, plugins register after
    // UIApplicationDidFinishLaunchingNotification has already fired, so
    // firebase_messaging never runs its launch-time setup: it never calls
    // registerForRemoteNotifications (no APNs token, so no FCM token and no
    // pushes) and never becomes the notification-center delegate (no
    // foreground or tap handling). Do both here, now that the plugin is
    // registered to receive the forwarded callbacks.
    UNUserNotificationCenter.current().delegate = self
    UIApplication.shared.registerForRemoteNotifications()
  }
}
