import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/foundation.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket_patient/models/auth_response.dart';
import 'package:pocket_patient/models/user.dart';
import 'package:pocket_patient/providers/auth_provider.dart';
import 'package:pocket_patient/screens/login_screen.dart';
import 'package:pocket_patient/services/api_service.dart';
import 'package:pocket_patient/services/apple_auth_service.dart';
import 'package:pocket_patient/services/auth_service.dart';

class MockFirebaseAuth extends Mock implements FirebaseAuth {}

class MockUser extends Mock implements User {}

class FakeUserInfo extends Fake implements UserInfo {
  @override
  final String providerId;
  FakeUserInfo(this.providerId);
}

UserInfo providerInfo(String id) => FakeUserInfo(id);

class MockCredential extends Mock implements UserCredential {}

class MockAdditionalInfo extends Mock implements AdditionalUserInfo {}

class MockAuthService extends Mock implements AuthService {}

class MockApiService extends Mock implements ApiService {}

void main() {
  late MockFirebaseAuth firebase;
  late MockUser user;
  late MockCredential credential;
  late MockAuthService storage;
  late MockApiService api;
  late AppleAuthService apple;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(AppleAuthProvider()));
  setUp(() {
    firebase = MockFirebaseAuth();
    user = MockUser();
    credential = MockCredential();
    storage = MockAuthService();
    api = MockApiService();
    apple = AppleAuthService(firebase);
    when(() => storage.hasToken()).thenAnswer((_) async => false);
    when(() => storage.clearAll()).thenAnswer((_) async {});
    when(() => storage.writeToken(any())).thenAnswer((_) async {});
    when(() => storage.writeRefreshToken(any())).thenAnswer((_) async {});
    when(() => storage.writeUserId(any())).thenAnswer((_) async {});
    when(() => firebase.signInWithProvider(any()))
        .thenAnswer((_) async => credential);
    when(() => credential.user).thenReturn(user);
    when(() => user.getIdToken(true))
        .thenAnswer((_) async => 'firebase-id-token');
    when(() => api.login('firebase-id-token')).thenAnswer((_) async =>
        const AuthResponse(
            accessToken: 'app-access', refreshToken: 'app-refresh'));
    when(() => api.getMe()).thenAnswer((_) async => const AppUser(
          id: 'apple-user',
          email: 'private@privaterelay.appleid.com',
          isVerified: true,
        ));
    container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(storage),
      apiServiceProvider.overrideWithValue(api),
      appleAuthServiceProvider.overrideWithValue(apple),
    ]);
  });
  tearDown(() {
    container.dispose();
    debugDefaultTargetPlatformOverride = null;
  });

  test(
      'Apple exchanges a fresh Firebase token and accepts relay email without a name',
      () async {
    await container.read(authNotifierProvider.future);
    await container.read(authNotifierProvider.notifier).signInWithApple();
    final provider = verify(() => firebase.signInWithProvider(captureAny()))
        .captured
        .single as AppleAuthProvider;
    expect(provider.scopes, containsAll(['email', 'name']));
    verify(() => user.getIdToken(true)).called(1);
    verifyInOrder([
      () => storage.clearAll(),
      () => api.login('firebase-id-token'),
      () => storage.writeToken('app-access'),
      () => storage.writeRefreshToken('app-refresh'),
      () => api.getMe(),
      () => storage.writeUserId('apple-user'),
    ]);
    final signedIn = container.read(authNotifierProvider).requireValue!;
    expect(signedIn.email, endsWith('@privaterelay.appleid.com'));
    expect(signedIn.displayName, isNull);
  });

  test('cancelled Apple sheet does not call backend or leave an error',
      () async {
    when(() => firebase.signInWithProvider(any()))
        .thenThrow(FirebaseAuthException(code: 'canceled'));
    await container.read(authNotifierProvider.future);
    await container.read(authNotifierProvider.notifier).signInWithApple();
    expect(
        container.read(authNotifierProvider), const AsyncData<AppUser?>(null));
    verifyNever(() => api.login(any()));
    verifyNever(() => storage.clearAll());
  });

  test('missing Firebase user fails before calling backend', () async {
    when(() => credential.user).thenReturn(null);
    await container.read(authNotifierProvider.future);
    await container.read(authNotifierProvider.notifier).signInWithApple();
    expect(container.read(authNotifierProvider).hasError, isTrue);
    verifyNever(() => api.login(any()));
  });

  test('backend rejection is preserved and writes no new session tokens',
      () async {
    final request = RequestOptions(path: '/auth/login');
    final denied = DioException(
        requestOptions: request,
        response: Response(
            requestOptions: request,
            statusCode: 403,
            data: {'detail': 'Must use a Rutgers email address'}));
    when(() => api.login(any())).thenThrow(denied);
    await container.read(authNotifierProvider.future);
    await container.read(authNotifierProvider.notifier).signInWithApple();
    expect(container.read(authNotifierProvider).error, same(denied));
    verifyNever(() => storage.writeToken(any()));
    verifyNever(() => storage.writeRefreshToken(any()));
  });

  test('Apple deletion reauthenticates and revokes a fresh authorization code',
      () async {
    when(() => firebase.currentUser).thenReturn(user);
    when(() => user.providerData).thenReturn([providerInfo('apple.com')]);
    when(() => user.reauthenticateWithProvider(any()))
        .thenAnswer((_) async => credential);
    final info = MockAdditionalInfo();
    when(() => credential.additionalUserInfo).thenReturn(info);
    when(() => info.authorizationCode).thenReturn('fresh-code');
    when(() => firebase.revokeTokenWithAuthorizationCode(any()))
        .thenAnswer((_) async {});
    await apple.revokeBeforeDeletion();
    verifyInOrder([
      () => user.reauthenticateWithProvider(any()),
      () => firebase.revokeTokenWithAuthorizationCode('fresh-code'),
    ]);
  });

  test('revocation cancellation and missing authorization code fail closed',
      () async {
    when(() => firebase.currentUser).thenReturn(user);
    when(() => user.providerData).thenReturn([providerInfo('apple.com')]);
    when(() => user.reauthenticateWithProvider(any()))
        .thenThrow(FirebaseAuthException(code: 'canceled'));
    await expectLater(
        apple.revokeBeforeDeletion(), throwsA(isA<FirebaseAuthException>()));
    when(() => user.reauthenticateWithProvider(any()))
        .thenAnswer((_) async => credential);
    when(() => credential.additionalUserInfo).thenReturn(null);
    await expectLater(
        apple.revokeBeforeDeletion(), throwsA(isA<FirebaseAuthException>()));
    verifyNever(() => firebase.revokeTokenWithAuthorizationCode(any()));
  });

  test('Google-only account does not invoke Apple during deletion', () async {
    when(() => firebase.currentUser).thenReturn(user);
    when(() => user.providerData).thenReturn([providerInfo('google.com')]);
    await apple.revokeBeforeDeletion();
    verifyNever(() => user.reauthenticateWithProvider(any()));
  });

  testWidgets(
      'iOS Apple button disables during sign-in and cancellation restores it',
      (tester) async {
    final pending = Completer<UserCredential>();
    when(() => firebase.signInWithProvider(any()))
        .thenAnswer((_) => pending.future);
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: LoginScreen())));
    await tester.pumpAndSettle();
    final appleButton = find.widgetWithText(FilledButton, 'Sign in with Apple');
    expect(appleButton, findsOneWidget);
    expect(find.text('Continue with Google'), findsOneWidget);
    await tester.tap(appleButton);
    await tester.pump();
    expect(tester.widget<FilledButton>(appleButton).onPressed, isNull);
    pending.completeError(FirebaseAuthException(code: 'canceled'));
    await tester.pumpAndSettle();
    expect(tester.widget<FilledButton>(appleButton).onPressed, isNotNull);
    expect(find.byType(SnackBar), findsNothing);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets('disabled Apple provider shows an actionable error',
      (tester) async {
    when(() => firebase.signInWithProvider(any()))
        .thenThrow(FirebaseAuthException(code: 'operation-not-allowed'));
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: LoginScreen())));
    await tester.pumpAndSettle();
    await tester.tap(find.text('Sign in with Apple'));
    await tester.pumpAndSettle();
    expect(
        find.text(
            'This sign-in method is not enabled yet. Please contact support.'),
        findsOneWidget);
  }, variant: TargetPlatformVariant.only(TargetPlatform.iOS));

  testWidgets(
      'Android retains Google and email login without native Apple button',
      (tester) async {
    await tester.pumpWidget(UncontrolledProviderScope(
        container: container, child: const MaterialApp(home: LoginScreen())));
    await tester.pumpAndSettle();
    expect(find.text('Sign in with Apple'), findsNothing);
    expect(find.text('Continue with Google'), findsOneWidget);
    expect(find.text('Sign in'), findsWidgets);
  }, variant: TargetPlatformVariant.only(TargetPlatform.android));
}
