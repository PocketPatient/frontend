import 'dart:convert';

import 'package:flutter_secure_storage/flutter_secure_storage.dart';
import '../config/constants.dart';
import '../models/user.dart';

class AuthService {
  final FlutterSecureStorage _storage;

  AuthService({FlutterSecureStorage? storage})
      : _storage = storage ??
            const FlutterSecureStorage(
              aOptions: AndroidOptions(encryptedSharedPreferences: true),
              // Readable after the first unlock since boot, not only while
              // unlocked: iOS launches/prewarms the app in the background
              // (e.g. for a push), and a failed keychain read there must not
              // look like "signed out".
              iOptions: IOSOptions(
                  accessibility: KeychainAccessibility.first_unlock),
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

  /// The backend user UUID stored alongside the tokens so the refresh
  /// interceptor can detect cross-account token mixing.
  Future<String?> readUserId() => _storage.read(key: kUserIdKey);

  Future<void> writeUserId(String userId) =>
      _storage.write(key: kUserIdKey, value: userId);

  /// Last known profile of the signed-in user, so a cold start can open
  /// straight to home instead of waiting on the network.
  Future<AppUser?> readCachedUser() async {
    final raw = await _storage.read(key: kCachedUserKey);
    if (raw == null) return null;
    try {
      return AppUser.fromJson(jsonDecode(raw) as Map<String, dynamic>);
    } catch (_) {
      return null; // unreadable (e.g. older format): fall back to the network
    }
  }

  Future<void> writeCachedUser(AppUser user) =>
      _storage.write(key: kCachedUserKey, value: jsonEncode(user.toJson()));

  Future<void> clearAll() async {
    await _storage.delete(key: kTokenKey);
    await _storage.delete(key: kRefreshTokenKey);
    await _storage.delete(key: kUserIdKey);
    await _storage.delete(key: kCachedUserKey);
  }
}
