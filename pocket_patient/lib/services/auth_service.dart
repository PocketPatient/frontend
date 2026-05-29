import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

class AuthService {
  final FlutterSecureStorage _storage;

  AuthService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
            );

  Future<bool> hasToken() async {
    final value = await _storage.read(key: kTokenKey);
    return value != null;
  }

  Future<String?> readAccessToken() => _storage.read(key: kTokenKey);

  Future<void> writeToken(String token) =>
      _storage.write(key: kTokenKey, value: token);

  Future<void> clearToken() => _storage.delete(key: kTokenKey);

  Future<String?> readRefreshToken() => _storage.read(key: kRefreshTokenKey);

  Future<void> writeRefreshToken(String token) =>
      _storage.write(key: kRefreshTokenKey, value: token);

  Future<void> clearAll() async {
    await _storage.delete(key: kTokenKey);
    await _storage.delete(key: kRefreshTokenKey);
  }
}
