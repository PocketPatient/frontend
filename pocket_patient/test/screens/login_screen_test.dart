import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket_patient/providers/auth_provider.dart';
import 'package:pocket_patient/screens/login_screen.dart';
import 'package:pocket_patient/services/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
    // AuthNotifier.build() calls hasToken() on every pump of this screen —
    // unstubbed, mocktail returns null instead of a Future<bool> and the
    // provider blows up before LoginScreen ever renders.
    when(() => mockAuthService.hasToken()).thenAnswer((_) async => false);
  });

  testWidgets('renders app name, subtitle, and Google button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
        child: const MaterialApp(home: LoginScreen()),
      ),
    );
    await tester.pumpAndSettle();

    expect(find.text('Pocket Patient v2'), findsOneWidget);
    expect(find.text('Rutgers University Clinical Simulation'), findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
  });

  // Skipped: AuthNotifier.signInWithGoogle() calls GoogleSignIn().signIn()
  // and FirebaseAuth.instance.signInWithCredential() before ever touching
  // authService.writeToken() — this project has no Firebase/Google
  // test-mocking setup (no firebase_auth_mocks / google_sign_in_mocks), so
  // the real SDK calls throw with no Firebase app initialized in the test
  // env. Needs those dev deps to un-skip properly.
  testWidgets(
    'tapping Continue with Google calls writeToken',
    skip: true,
    (tester) async {
      when(() => mockAuthService.writeToken(any())).thenAnswer((_) async {});

      final router = GoRouter(
        initialLocation: '/login',
        routes: [
          GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
          GoRoute(
            path: '/home',
            builder: (_, __) => const Scaffold(body: Text('Home')),
          ),
        ],
      );

      await tester.pumpWidget(
        ProviderScope(
          overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
          child: MaterialApp.router(routerConfig: router),
        ),
      );

      await tester.pumpAndSettle();
      await tester.tap(find.text('Continue with Google'));
      await tester.pumpAndSettle();

      verify(() => mockAuthService.writeToken(any())).called(1);
    },
  );
}
