import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/user.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/role_selection_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// ---------------------------------------------------------------------------
// Core service providers
// ---------------------------------------------------------------------------

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(authService: ref.read(authServiceProvider));
});

// ---------------------------------------------------------------------------
// Auth state notifier
// ---------------------------------------------------------------------------

final authNotifierProvider =
    AsyncNotifierProvider<AuthNotifier, AppUser?>(AuthNotifier.new);

class AuthNotifier extends AsyncNotifier<AppUser?> {
  @override
  Future<AppUser?> build() async {
    final hasToken = await ref.read(authServiceProvider).hasToken();
    if (!hasToken) return null;
    try {
      return await ref.read(apiServiceProvider).getMe();
    } on DioException catch (e) {
      if (e.response?.statusCode == 401) {
        await ref.read(authServiceProvider).clearAll();
      }
      return null;
    }
  }

  Future<void> signInWithGoogle() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final googleUser = await GoogleSignIn().signIn();
      if (googleUser == null) throw Exception('Sign-in cancelled');
      final googleAuth = await googleUser.authentication;
      final credential = GoogleAuthProvider.credential(
        accessToken: googleAuth.accessToken,
        idToken: googleAuth.idToken,
      );
      final userCred =
          await FirebaseAuth.instance.signInWithCredential(credential);
      return _exchangeFirebaseToken(userCred);
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _exchangeFirebaseToken(userCred);
    });
  }

  Future<void> register(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userCred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      return _exchangeFirebaseToken(userCred);
    });
  }

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  Future<void> setRole(String role) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await ref.read(apiServiceProvider).setRole(role);
    });
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).clearAll();
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    state = const AsyncData(null);
  }

  Future<AppUser> _exchangeFirebaseToken(UserCredential cred) async {
    final idToken = await cred.user!.getIdToken();
    final authResp =
        await ref.read(apiServiceProvider).login(idToken!);
    await ref.read(authServiceProvider).writeToken(authResp.accessToken);
    await ref.read(authServiceProvider).writeRefreshToken(authResp.refreshToken);
    return await ref.read(apiServiceProvider).getMe();
  }
}

// ---------------------------------------------------------------------------
// Router
// ---------------------------------------------------------------------------

final routerNotifierProvider =
    ChangeNotifierProvider<RouterNotifier>((ref) => RouterNotifier(ref));

class RouterNotifier extends ChangeNotifier {
  final Ref _ref;

  RouterNotifier(this._ref) {
    _ref.listen(authNotifierProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authNotifierProvider);
    if (authState.isLoading) return null;

    final user = authState.valueOrNull;
    final loc = state.matchedLocation;

    if (user == null) {
      return loc == '/login' ? null : '/login';
    }
    if (user.role == null) {
      return loc == '/role-selection' ? null : '/role-selection';
    }
    if (loc == '/login' || loc == '/role-selection') return '/home';
    return null;
  }
}

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);
  return GoRouter(
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/role-selection',
          builder: (_, __) => const RoleSelectionScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
    ],
  );
});
