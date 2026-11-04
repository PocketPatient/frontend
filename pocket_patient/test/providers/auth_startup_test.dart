import 'dart:async';

import 'package:flutter/material.dart' show TimeOfDay;
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket_patient/models/user.dart';
import 'package:pocket_patient/providers/auth_provider.dart';
import 'package:pocket_patient/services/api_service.dart';
import 'package:pocket_patient/services/auth_service.dart';

class MockAuthService extends Mock implements AuthService {}

class MockApiService extends Mock implements ApiService {}

const _cached = AppUser(
  id: 'u1',
  email: 'student@scarletmail.rutgers.edu',
  role: 'student',
  isVerified: true,
);

void main() {
  late MockAuthService storage;
  late MockApiService api;
  late ProviderContainer container;

  setUpAll(() => registerFallbackValue(_cached));
  setUp(() {
    storage = MockAuthService();
    api = MockApiService();
    when(() => storage.writeCachedUser(any())).thenAnswer((_) async {});
    container = ProviderContainer(overrides: [
      authServiceProvider.overrideWithValue(storage),
      apiServiceProvider.overrideWithValue(api),
    ]);
  });
  tearDown(() => container.dispose());

  test('signed-in cold start returns the cached user without waiting on the network',
      () async {
    final me = Completer<AppUser>();
    when(() => storage.hasToken()).thenAnswer((_) async => true);
    when(() => storage.readCachedUser()).thenAnswer((_) async => _cached);
    when(() => api.getMe()).thenAnswer((_) => me.future);

    final user = await container.read(authNotifierProvider.future);
    expect(user?.id, 'u1');

    // The background refresh then swaps in the server's copy.
    me.complete(_cached.copyWith(displayName: 'Fresh Name'));
    await pumpEventQueue();
    expect(container.read(authNotifierProvider).value?.displayName, 'Fresh Name');
    verify(() => storage.writeCachedUser(any())).called(greaterThan(0));
  });

  test('failed background refresh keeps the cached user signed in', () async {
    when(() => storage.hasToken()).thenAnswer((_) async => true);
    when(() => storage.readCachedUser()).thenAnswer((_) async => _cached);
    when(() => api.getMe()).thenThrow(Exception('offline'));

    await container.read(authNotifierProvider.future);
    await pumpEventQueue();
    expect(container.read(authNotifierProvider).value?.id, 'u1');
  });

  test('no cached user falls back to the server', () async {
    when(() => storage.hasToken()).thenAnswer((_) async => true);
    when(() => storage.readCachedUser()).thenAnswer((_) async => null);
    when(() => api.getMe()).thenAnswer((_) async => _cached);

    expect((await container.read(authNotifierProvider.future))?.id, 'u1');
  });

  test('cached user is ignored without stored tokens', () async {
    when(() => storage.hasToken()).thenAnswer((_) async => false);

    expect(await container.read(authNotifierProvider.future), isNull);
    verifyNever(() => storage.readCachedUser());
    verifyNever(() => api.getMe());
  });

  test('AppUser survives a toJson/fromJson round trip', () {
    const user = AppUser(
      id: 'u2',
      email: 'prof@rutgers.edu',
      role: 'professor',
      displayName: 'Dr. P',
      isVerified: true,
      pushEnabled: false,
      quietHoursStart: TimeOfDay(hour: 22, minute: 30),
      quietHoursEnd: TimeOfDay(hour: 7, minute: 0),
    );
    final back = AppUser.fromJson(user.toJson());
    expect(back.toJson(), user.toJson());
  });
}
