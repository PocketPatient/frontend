import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:go_router/go_router.dart';
import 'package:mocktail/mocktail.dart';
import 'package:shared_preferences/shared_preferences.dart';
import 'package:pocket_patient/models/ai_consent_status.dart';
import 'package:pocket_patient/models/chat_session.dart';
import 'package:pocket_patient/models/course.dart';
import 'package:pocket_patient/providers/auth_provider.dart';
import 'package:pocket_patient/providers/connectivity_provider.dart';
import 'package:pocket_patient/screens/privacy_settings_screen.dart';
import 'package:pocket_patient/screens/student/chat_screen.dart';
import 'package:pocket_patient/services/api_service.dart';
import 'package:pocket_patient/utils/api_error.dart';

class MockApiService extends Mock implements ApiService {}

DioException apiError(int status, Object data) {
  final request = RequestOptions(path: '/sessions');
  return DioException(
    requestOptions: request,
    response: Response(requestOptions: request, statusCode: status, data: data),
    type: DioExceptionType.badResponse,
  );
}

void main() {
  test('consent errors are distinct from other forbidden responses', () {
    for (final body in [
      {'code': 'AI_CONSENT_REQUIRED'},
      {
        'detail': {'code': 'AI_CONSENT_REQUIRED'}
      },
    ]) {
      expect(isAiConsentRequired(apiError(403, body)), isTrue);
      expect(friendlyErrorMessage(apiError(403, body)), contains('consent'));
    }
    for (final body in [
      null,
      'Forbidden',
      {'code': 'FORBIDDEN'}
    ]) {
      expect(isAiConsentRequired(apiError(403, body ?? '')), isFalse);
    }
    expect(isAiConsentRequired(apiError(500, {'code': 'AI_CONSENT_REQUIRED'})),
        isFalse);
  });

  for (final grantConsent in [true, false]) {
    testWidgets('case creation recovery with consent granted=$grantConsent',
        (tester) async {
      SharedPreferences.setMockInitialValues({});
      final api = MockApiService();
      var accepted = false;
      AiConsentStatus consent() => AiConsentStatus(
            active: accepted,
            requiredVersion: '2026-10-v1',
          );
      when(() => api.getActiveSession('course'))
          .thenAnswer((_) async => throw apiError(404, {}));
      when(() => api.getUnits('course')).thenAnswer((_) async => []);
      when(() => api.getAiConsent()).thenAnswer((_) async => consent());
      when(() => api.acceptAiConsent()).thenAnswer((_) async {
        accepted = true;
        return consent();
      });
      when(() => api.createSession('course')).thenAnswer((_) async {
        if (!accepted) throw apiError(403, {'code': 'AI_CONSENT_REQUIRED'});
        return ChatSession(
          id: 'session',
          diseaseId: 'disease',
          courseId: 'course',
          status: 'active',
          turnCount: 0,
          startedAt: DateTime(2026),
          messages: const [],
          patientName: 'Test Patient',
          patientAge: 30,
          patientGender: 'Female',
        );
      });
      final course = Course(
        id: 'course',
        title: 'Psychiatry 101',
        classCode: 'TEST',
        professorId: 'prof',
        isActive: true,
        studentCount: 1,
        msgTimezone: 'America/New_York',
        createdAt: DateTime(2026),
      );
      final router = GoRouter(routes: [
        GoRoute(path: '/', builder: (_, __) => ChatScreen(course: course)),
        GoRoute(
            path: '/privacy-settings',
            builder: (_, __) => const PrivacySettingsScreen()),
      ]);
      addTearDown(router.dispose);
      await tester.pumpWidget(ProviderScope(
        overrides: [
          apiServiceProvider.overrideWithValue(api),
          connectivityProvider.overrideWith((ref) => Stream.value(true)),
        ],
        child: MaterialApp.router(routerConfig: router),
      ));
      await tester.pumpAndSettle();
      await tester.tap(find.text('Dev: force-create new case'));
      await tester.pumpAndSettle();
      expect(
          find.text("You don't have permission to view this."), findsNothing);
      await tester.tap(find.text('Review AI consent'));
      await tester.pumpAndSettle();
      expect(find.text('Privacy and account'), findsOneWidget);
      if (grantConsent) {
        await tester.tap(find.byType(SwitchListTile));
        await tester.pumpAndSettle();
      }
      router.pop();
      await tester.pumpAndSettle();
      verify(() => api.createSession('course')).called(grantConsent ? 2 : 1);
      expect(find.text('Review AI consent'),
          grantConsent ? findsNothing : findsOneWidget);
      if (grantConsent) {
        expect(find.text('Dev: force-create new case'), findsNothing);
      }
      expect(tester.takeException(), isNull);
      await tester.pumpWidget(const SizedBox.shrink());
    });
  }
}
