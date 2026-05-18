import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';

class AuthService {
  final FlutterSecureStorage _storage;

  AuthService({FlutterSecureStorage? storage})
      : _storage = storage ?? const FlutterSecureStorage();

  Future<bool> hasToken() async {
    final value = await _storage.read(key: kTokenKey);
    return value != null;
  }

  Future<void> writeToken(String token) async {
    await _storage.write(key: kTokenKey, value: token);
  }

  Future<void> clearToken() async {
    await _storage.delete(key: kTokenKey);
  }
}
