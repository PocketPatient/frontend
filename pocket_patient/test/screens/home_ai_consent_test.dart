import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket_patient/models/ai_consent_status.dart';
import 'package:pocket_patient/models/course.dart';
import 'package:pocket_patient/models/user.dart';
import 'package:pocket_patient/providers/auth_provider.dart';
import 'package:pocket_patient/providers/courses_provider.dart';
import 'package:pocket_patient/screens/home_screen.dart';
import 'package:pocket_patient/screens/privacy_settings_screen.dart';
import 'package:pocket_patient/services/notification_service.dart';
import 'package:shared_preferences/shared_preferences.dart';

class MockNotificationService extends Mock implements NotificationService {}

class _EmptyCoursesNotifier extends CoursesNotifier {
  @override
  Future<List<Course>> build() async => [];
}

class _SignedIn extends AuthNotifier {
  _SignedIn(this.role);
  final String role;

  @override
  Future<AppUser?> build() async =>
      AppUser(id: 'u1', email: 'u1@rutgers.edu', role: role, isVerified: true);
}

AiConsentStatus _consent(bool active) =>
    AiConsentStatus(active: active, requiredVersion: 'v1');

void main() {
  late MockNotificationService notifications;

  setUp(() {
    notifications = MockNotificationService();
    when(() => notifications.onSignedIn()).thenAnswer((_) async {});
  });

  Future<void> pumpHome(WidgetTester tester,
      {String role = 'student', bool consent = false}) async {
    final router = GoRouter(initialLocation: '/home', routes: [
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
          path: '/ai-consent',
          builder: (_, __) => const Scaffold(body: Text('CONSENT SCREEN'))),
    ]);
    await tester.pumpWidget(ProviderScope(
      overrides: [
        authNotifierProvider.overrideWith(() => _SignedIn(role)),
        coursesProvider.overrideWith(_EmptyCoursesNotifier.new),
        notificationServiceProvider.overrideWithValue(notifications),
        aiConsentProvider.overrideWith((ref) async => _consent(consent)),
      ],
      child: MaterialApp.router(routerConfig: router),
    ));
    await tester.pumpAndSettle();
  }

  testWidgets('student without consent is shown the consent screen once',
      (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpHome(tester);

    expect(find.text('CONSENT SCREEN'), findsOneWidget);
    final prefs = await SharedPreferences.getInstance();
    expect(prefs.getBool(kAiConsentPromptedKey), isTrue);
  });

  testWidgets('already prompted: no screen, but the banner explains no cases',
      (tester) async {
    SharedPreferences.setMockInitialValues({kAiConsentPromptedKey: true});
    await pumpHome(tester);

    expect(find.text('CONSENT SCREEN'), findsNothing);
    expect(find.byKey(const Key('ai-consent-off-banner')), findsOneWidget);
    verify(() => notifications.onSignedIn()).called(1);

    await tester.tap(find.text('Turn on'));
    await tester.pumpAndSettle();
    expect(find.text('CONSENT SCREEN'), findsOneWidget);
  });

  testWidgets('student with consent sees neither', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpHome(tester, consent: true);

    expect(find.text('CONSENT SCREEN'), findsNothing);
    expect(find.byKey(const Key('ai-consent-off-banner')), findsNothing);
  });

  testWidgets('professors are never asked', (tester) async {
    SharedPreferences.setMockInitialValues({});
    await pumpHome(tester, role: 'professor');

    expect(find.text('CONSENT SCREEN'), findsNothing);
    expect(find.byKey(const Key('ai-consent-off-banner')), findsNothing);
  });
}
