import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import 'package:flutter_test/flutter_test.dart';
import 'package:mocktail/mocktail.dart';
import 'package:pocket_patient/config/constants.dart';
import 'package:pocket_patient/services/auth_service.dart';

class MockFlutterSecureStorage extends Mock implements FlutterSecureStorage {}

void main() {
  late MockFlutterSecureStorage mockStorage;
  late AuthService sut;

  setUp(() {
    mockStorage = MockFlutterSecureStorage();
    sut = AuthService(storage: mockStorage);
  });

  group('hasToken', () {
    test('returns false when no token in storage', () async {
      when(() => mockStorage.read(key: kTokenKey)).thenAnswer((_) async => null);

      expect(await sut.hasToken(), false);
    });

    test('returns true when token exists', () async {
      when(() => mockStorage.read(key: kTokenKey))
          .thenAnswer((_) async => 'some_token');

      expect(await sut.hasToken(), true);
    });
  });

  group('writeToken', () {
    test('writes value to secure storage under kTokenKey', () async {
      when(() => mockStorage.write(key: kTokenKey, value: 'test_token'))
          .thenAnswer((_) async {});

      await sut.writeToken('test_token');

      verify(() => mockStorage.write(key: kTokenKey, value: 'test_token')).called(1);
    });
  });

  group('clearToken', () {
    test('deletes token from secure storage', () async {
      when(() => mockStorage.delete(key: kTokenKey)).thenAnswer((_) async {});

      await sut.clearToken();

      verify(() => mockStorage.delete(key: kTokenKey)).called(1);
    });
  });
}
