import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket_patient/models/ai_consent_status.dart';
import 'package:pocket_patient/providers/auth_provider.dart';
import 'package:pocket_patient/screens/ai_consent_screen.dart';
import 'package:pocket_patient/services/api_service.dart';

class MockApiService extends Mock implements ApiService {}

Future<void> _pumpConsentOverHome(WidgetTester tester, ApiService api) async {
  final router = GoRouter(initialLocation: '/home', routes: [
    GoRoute(path: '/home', builder: (_, __) => const Scaffold(body: Text('HOME'))),
    GoRoute(path: '/ai-consent', builder: (_, __) => const AiConsentScreen()),
  ]);
  await tester.pumpWidget(ProviderScope(
    overrides: [apiServiceProvider.overrideWithValue(api)],
    child: MaterialApp.router(routerConfig: router),
  ));
  router.push('/ai-consent'); // as role selection does for new students
  await tester.pumpAndSettle();
}

void main() {
  testWidgets('explains how to change consent to No later', (tester) async {
    await _pumpConsentOverHome(tester, MockApiService());
    final line = tester.widget<RichText>(find.descendant(
      of: find.byKey(const Key('ai-consent-change-later')),
      matching: find.byType(RichText),
    ).first);
    final text = line.text.toPlainText();
    expect(text, contains('change this to No'));
    expect(text, contains('Allow simulated AI patient responses'));
    expect(find.byIcon(Icons.shield_outlined), findsOneWidget);
  });

  testWidgets('"I agree" records consent and continues to home', (tester) async {
    final api = MockApiService();
    when(() => api.acceptAiConsent()).thenAnswer((_) async =>
        const AiConsentStatus(active: true, requiredVersion: '2026-10-v1'));
    await _pumpConsentOverHome(tester, api);

    await tester.tap(find.text('I agree'));
    await tester.pumpAndSettle();

    verify(() => api.acceptAiConsent()).called(1);
    expect(find.text('HOME'), findsOneWidget);
  });

  testWidgets('"Not now" continues without recording consent', (tester) async {
    final api = MockApiService();
    await _pumpConsentOverHome(tester, api);

    await tester.tap(find.text('Not now'));
    await tester.pumpAndSettle();

    verifyNever(() => api.acceptAiConsent());
    expect(find.text('HOME'), findsOneWidget);
  });
}
