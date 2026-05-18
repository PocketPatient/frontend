import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket_patient/providers/auth_provider.dart';
import 'package:pocket_patient/screens/home_screen.dart';
import 'package:pocket_patient/services/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

void main() {
  late MockAuthService mockAuthService;

  setUp(() {
    mockAuthService = MockAuthService();
  });

  testWidgets('renders welcome message and logout button', (tester) async {
    await tester.pumpWidget(
      ProviderScope(
        overrides: [authServiceProvider.overrideWithValue(mockAuthService)],
        child: const MaterialApp(home: HomeScreen()),
      ),
    );

    expect(find.text('Welcome, Student'), findsOneWidget);
    expect(find.text('Logout'), findsOneWidget);
  });

  testWidgets('tapping Logout calls clearToken', (tester) async {
    when(() => mockAuthService.clearToken()).thenAnswer((_) async {});

    final router = GoRouter(
      initialLocation: '/home',
      routes: [
        GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
        GoRoute(
          path: '/login',
          builder: (_, __) => const Scaffold(body: Text('Login')),
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
    await tester.tap(find.text('Logout'));
    await tester.pumpAndSettle();

    verify(() => mockAuthService.clearToken()).called(1);
  });
}
