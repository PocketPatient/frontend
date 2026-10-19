import 'dart:convert';
import 'dart:typed_data';

import 'package:dio/dio.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_patient/services/api_service.dart';
import 'package:pocket_patient/services/auth_service.dart';

/// In-memory AuthService: lets tests see exactly what was kept or cleared.
class FakeAuthService extends AuthService {
  final Map<String, String> store = {};
  FakeAuthService(Map<String, String> initial) {
    store.addAll(initial);
  }
  @override
  Future<bool> hasToken() async => store.containsKey('access');
  @override
  Future<String?> readAccessToken() async => store['access'];
  @override
  Future<void> writeToken(String token) async => store['access'] = token;
  @override
  Future<String?> readRefreshToken() async => store['refresh'];
  @override
  Future<void> writeRefreshToken(String token) async => store['refresh'] = token;
  @override
  Future<String?> readUserId() async => store['user'];
  @override
  Future<void> clearAll() async => store.clear();
}

/// Serves a scripted response per path; a null status simulates no network.
class ScriptedAdapter implements HttpClientAdapter {
  final Map<String, List<int?>> statuses;
  final Map<String, Object> bodies;
  final List<String> calls = [];
  ScriptedAdapter(this.statuses, [this.bodies = const {}]);

  @override
  Future<ResponseBody> fetch(RequestOptions options,
      Stream<Uint8List>? requestStream, Future<void>? cancelFuture) async {
    calls.add(options.path);
    final status = statuses[options.path]!.removeAt(0);
    if (status == null) {
      throw DioException(
          requestOptions: options, type: DioExceptionType.connectionError);
    }
    return ResponseBody.fromString(
      jsonEncode(bodies[options.path] ?? {'detail': 'x'}),
      status,
      headers: {
        Headers.contentTypeHeader: [Headers.jsonContentType]
      },
    );
  }

  @override
  void close({bool force = false}) {}
}

const _user = {
  'id': 'u1',
  'email': 'a@rutgers.edu',
  'role': 'student',
};

void main() {
  late FakeAuthService auth;
  late bool signedOut;

  ApiService api(ScriptedAdapter main, ScriptedAdapter refresh) {
    final dio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = main;
    final refreshDio = Dio(BaseOptions(baseUrl: 'https://api.test'))
      ..httpClientAdapter = refresh;
    return ApiService(
      authService: auth,
      dio: dio,
      refreshDio: refreshDio,
      onUnauthenticated: () => signedOut = true,
    );
  }

  setUp(() {
    auth = FakeAuthService({'access': 'old', 'refresh': 'r1'});
    signedOut = false;
  });

  test('expired access token is refreshed and the request retried', () async {
    final main = ScriptedAdapter({'/users/me': [401, 200]}, {'/users/me': _user});
    final refresh = ScriptedAdapter({'/auth/refresh': [200]}, {
      '/auth/refresh': {'access_token': 'new', 'refresh_token': 'r2'}
    });

    final user = await api(main, refresh).getMe();

    expect(user.id, 'u1');
    expect(auth.store, {'access': 'new', 'refresh': 'r2'});
    expect(signedOut, isFalse);
  });

  test('no network during refresh keeps the session (regression)', () async {
    final main = ScriptedAdapter({'/users/me': [401]});
    final refresh = ScriptedAdapter({'/auth/refresh': [null]});

    final call = api(main, refresh).getMe();

    await expectLater(
        call,
        throwsA(isA<DioException>()
            .having((e) => e.response, 'response', isNull)
            .having((e) => e.type, 'type', DioExceptionType.connectionError)));
    expect(auth.store, {'access': 'old', 'refresh': 'r1'});
    expect(signedOut, isFalse);
  });

  test('server error during refresh keeps the session', () async {
    final main = ScriptedAdapter({'/users/me': [401]});
    final refresh = ScriptedAdapter({'/auth/refresh': [503]});

    await expectLater(api(main, refresh).getMe(), throwsA(isA<DioException>()));
    expect(auth.store, {'access': 'old', 'refresh': 'r1'});
    expect(signedOut, isFalse);
  });

  test('rejected refresh token ends the session', () async {
    final main = ScriptedAdapter({'/users/me': [401]});
    final refresh = ScriptedAdapter({'/auth/refresh': [401]});

    await expectLater(
        api(main, refresh).getMe(),
        throwsA(isA<DioException>()
            .having((e) => e.response?.statusCode, 'status', 401)));
    expect(auth.store, isEmpty);
    expect(signedOut, isTrue);
  });

  test('missing refresh token ends the session without calling the server',
      () async {
    auth = FakeAuthService({'access': 'old'});
    final main = ScriptedAdapter({'/users/me': [401]});
    final refresh = ScriptedAdapter({'/auth/refresh': []});

    await expectLater(api(main, refresh).getMe(), throwsA(isA<DioException>()));
    expect(refresh.calls, isEmpty);
    expect(auth.store, isEmpty);
    expect(signedOut, isTrue);
  });
}
