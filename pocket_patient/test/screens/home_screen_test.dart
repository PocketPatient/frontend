import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket_patient/models/course.dart';
import 'package:pocket_patient/providers/auth_provider.dart';
import 'package:pocket_patient/providers/courses_provider.dart';
import 'package:pocket_patient/screens/home_screen.dart';
import 'package:pocket_patient/services/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

/// Bypasses the real API call — the home screen tests care about auth state
/// and chrome, not the course list itself.
class _EmptyCoursesNotifier extends CoursesNotifier {
  @override
  Future<List<Course>> build() async => [];
}

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
    // AuthNotifier.build() calls hasToken() on every pump of this screen —
    // unstubbed, mocktail returns null instead of a Future<bool> and the
    // provider blows up before HomeScreen ever renders.
    when(() => mockAuthService.hasToken()).thenAnswer((_) async => false);
  });

  testWidgets('renders title and sign-out button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [
          authServiceProvider.overrideWithValue(mockAuthService),
          coursesProvider.overrideWith(_EmptyCoursesNotifier.new),
        ],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pocket Patient v2'), findsOneWidget);
    expect(find.byTooltip('Sign out'), findsOneWidget);
  });

  // Skipped: AuthNotifier.signOut() calls FirebaseAuth.instance.signOut()
  // after clearAll(), and this project has no Firebase test-mocking setup
  // (no firebase_auth_mocks / setupFirebaseCoreMocks) — that call throws
  // with no Firebase app initialized in the test env. Needs
  // firebase_auth_mocks + google_sign_in_mocks as dev deps to un-skip.
  testWidgets(
    'tapping sign-out calls clearAll',
    skip: true,
    (tester) async {
      when(() => mockAuthService.clearAll()).thenAnswer((_) async {});

      final router = GoRouter(
        initialLocation: '/home',
        routes: [
          GoRoute(
            path: '/home',
            builder: (_, __) => const HomeScreen(),
          ),
          GoRoute(
            path: '/login',
            builder: (_, __) => const Scaffold(body: Text('Login')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [
            authServiceProvider.overrideWithValue(mockAuthService),
            coursesProvider.overrideWith(_EmptyCoursesNotifier.new),
          ],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.byTooltip('Sign out'));
      await tester.pumpAndSettle();

      verify(() => mockAuthService.clearAll()).called(1);
    },
  );
}
