import 'package:firebase_auth/firebase_auth.dart';

/// Firebase owns the native Apple authorization flow, including nonce handling.
class AppleAuthService {
  final FirebaseAuth _auth;

  AppleAuthService(this._auth);

  Future<User> signIn() async {
    final provider = AppleAuthProvider()
      ..addScope('email')
      ..addScope('name');
    final result = await _auth.signInWithProvider(provider);
    final user = result.user;
    if (user == null) {
      throw FirebaseAuthException(code: 'apple-user-missing');
    }
    return user;
  }

  /// Apple authorization must be revoked before the backend deletes Firebase
  /// identity. Reauthentication supplies a fresh, short-lived authorization code.
  Future<void> revokeBeforeDeletion() async {
    final user = _auth.currentUser;
    if (user == null ||
        !user.providerData
            .any((provider) => provider.providerId == 'apple.com')) {
      return;
    }
    final result = await user.reauthenticateWithProvider(AppleAuthProvider());
    final code = result.additionalUserInfo?.authorizationCode;
    if (code == null || code.isEmpty) {
      throw FirebaseAuthException(code: 'apple-revocation-code-missing');
    }
    await _auth.revokeTokenWithAuthorizationCode(code);
  }
}

bool isAppleSignInCancelled(Object error) =>
    error is FirebaseAuthException &&
    const {
      'canceled',
      'cancelled',
      'user-cancelled',
      'web-context-canceled',
      'popup-closed-by-user',
    }.contains(error.code);
