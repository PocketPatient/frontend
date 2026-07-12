import 'dart:async';

import 'package:dio/dio.dart';
import 'package:firebase_auth/firebase_auth.dart';
import 'package:firebase_messaging/firebase_messaging.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:google_sign_in/google_sign_in.dart';
import '../models/completed_session_item.dart';
import '../models/diagnosis_result.dart';
import '../models/enrolled_student.dart';
import '../models/user.dart';
import '../screens/email_verification_screen.dart';
import '../screens/home_screen.dart';
import '../screens/login_screen.dart';
import '../screens/notification_settings_screen.dart';
import '../screens/professor/course_management_screen.dart';
import '../screens/professor/create_course_screen.dart';
import '../screens/professor/disease_upload_screen.dart';
import '../screens/professor/student_drilldown_screen.dart';
import '../screens/professor/student_sessions_screen.dart';
import '../screens/professor/students_screen.dart';
import '../screens/professor/transcript_viewer_screen.dart';
import '../screens/role_selection_screen.dart';
import '../screens/student/case_history_screen.dart';
import '../screens/student/chat_screen.dart';
import '../screens/student/diagnosis_result_screen.dart';
import '../screens/student/enroll_screen.dart';
import '../services/api_service.dart';
import '../services/auth_service.dart';

// ---------------------------------------------------------------------------
// Core service providers
// ---------------------------------------------------------------------------

final authServiceProvider = Provider<AuthService>((ref) => AuthService());

final apiServiceProvider = Provider<ApiService>((ref) {
  return ApiService(
    authService: ref.read(authServiceProvider),
    // Refresh token expired/revoked/mixed-account — reset auth state so
    // RouterNotifier's listener redirects to /login immediately, instead
    // of the user being stuck on a screen with dead requests until the
    // next cold start happens to re-check.
    onUnauthenticated: () =>
        ref.read(authNotifierProvider.notifier).forceSignedOut(),
  );
});

// True while we're waiting for the user to verify their email address.
// Set after register(), cleared after verification confirmed or sign-out.
final emailVerificationPendingProvider = StateProvider<bool>((ref) => false);

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
      final user = await ref.read(apiServiceProvider).getMe();
      unawaited(_registerFcmToken());
      return user;
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
      return _exchangeFirebaseToken(userCred.user!);
    });
  }

  Future<void> signInWithEmail(String email, String password) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userCred = await FirebaseAuth.instance.signInWithEmailAndPassword(
        email: email,
        password: password,
      );
      // If somehow they sign in before verifying, remind them.
      if (!userCred.user!.emailVerified) {
        await userCred.user!.sendEmailVerification();
        ref.read(emailVerificationPendingProvider.notifier).state = true;
        return null;
      }
      return _exchangeFirebaseToken(userCred.user!);
    });
  }

  Future<void> register(
      String email, String password, String displayName) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final userCred =
          await FirebaseAuth.instance.createUserWithEmailAndPassword(
        email: email,
        password: password,
      );
      // Persist display name to Firebase profile.
      if (displayName.trim().isNotEmpty) {
        await userCred.user!.updateDisplayName(displayName.trim());
      }
      // Send verification email — backend requires email_verified = true.
      await userCred.user!.sendEmailVerification();
      ref.read(emailVerificationPendingProvider.notifier).state = true;
      // Stay as null (unauthenticated) until they verify.
      return null;
    });
  }

  /// Called when the user taps "I've verified my email".
  /// Reloads the Firebase user and proceeds if email is now verified.
  Future<void> checkEmailVerification() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      final firebaseUser = FirebaseAuth.instance.currentUser;
      if (firebaseUser == null) throw Exception('No signed-in user found.');
      // Force reload from Firebase servers.
      await firebaseUser.reload();
      final refreshed = FirebaseAuth.instance.currentUser!;
      if (!refreshed.emailVerified) {
        throw Exception(
            'Email not verified yet. Please check your inbox and tap the link.');
      }
      ref.read(emailVerificationPendingProvider.notifier).state = false;
      return _exchangeFirebaseToken(refreshed);
    });
  }

  Future<void> resendVerificationEmail() async {
    final user = FirebaseAuth.instance.currentUser;
    if (user != null && !user.emailVerified) {
      await user.sendEmailVerification();
    }
  }

  Future<void> cancelVerification() async {
    await FirebaseAuth.instance.signOut();
    ref.read(emailVerificationPendingProvider.notifier).state = false;
    state = const AsyncData(null);
  }

  Future<void> sendPasswordReset(String email) async {
    await FirebaseAuth.instance.sendPasswordResetEmail(email: email);
  }

  /// Called from ApiService's interceptor when a refresh token turns out to
  /// be dead (expired/revoked/mixed-account) — tokens are already cleared by
  /// that point, this just resets in-memory state so RouterNotifier's
  /// listener redirects to /login right away.
  void forceSignedOut() {
    state = const AsyncData(null);
  }

  Future<void> setRole(String role) async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(() async {
      return await ref.read(apiServiceProvider).setRole(role);
    });
  }

  /// PUT .../notification-preferences only returns the three preference
  /// fields, not a full user, so state is updated via copyWith with what
  /// was just sent rather than re-parsed from the response.
  Future<void> updateNotificationPreferences({
    required bool pushEnabled,
    TimeOfDay? quietHoursStart,
    TimeOfDay? quietHoursEnd,
    bool clearQuietHours = false,
  }) async {
    final current = state.valueOrNull;
    if (current == null) return;
    await ref.read(apiServiceProvider).updateNotificationPreferences(
          pushEnabled: pushEnabled,
          quietHoursStart:
              clearQuietHours || quietHoursStart == null ? null : formatTimeOfDayForApi(quietHoursStart),
          quietHoursEnd:
              clearQuietHours || quietHoursEnd == null ? null : formatTimeOfDayForApi(quietHoursEnd),
        );
    state = AsyncData(current.copyWith(
      pushEnabled: pushEnabled,
      quietHoursStart: quietHoursStart,
      quietHoursEnd: quietHoursEnd,
      clearQuietHours: clearQuietHours,
    ));
  }

  Future<void> signOut() async {
    await ref.read(authServiceProvider).clearAll();
    await FirebaseAuth.instance.signOut();
    await GoogleSignIn().signOut();
    ref.read(emailVerificationPendingProvider.notifier).state = false;
    state = const AsyncData(null);
  }

  Future<AppUser> _exchangeFirebaseToken(User firebaseUser) async {
    // Clear any previously stored tokens first — prevents stale sessions
    // from a different account being used after switching logins.
    await ref.read(authServiceProvider).clearAll();
    // Force-refresh the token so email_verified is up to date.
    final idToken = await firebaseUser.getIdToken(true);
    final authResp = await ref.read(apiServiceProvider).login(idToken!);
    await ref.read(authServiceProvider).writeToken(authResp.accessToken);
    await ref.read(authServiceProvider).writeRefreshToken(authResp.refreshToken);
    final user = await ref.read(apiServiceProvider).getMe();
    // Persist the user ID so the refresh interceptor can detect cross-account
    // token mixing (e.g. access token for user A, refresh token for user B).
    await ref.read(authServiceProvider).writeUserId(user.id);
    unawaited(_registerFcmToken());
    return user;
  }

  /// Sends the device's current FCM token to the backend. Called after
  /// login/restore in case the app's startup registration (in
  /// [NotificationService]) ran before the user was authenticated.
  Future<void> _registerFcmToken() async {
    try {
      final token = await FirebaseMessaging.instance.getToken();
      if (token != null) {
        await ref.read(apiServiceProvider).updateFcmToken(token);
      }
    } catch (_) {
      // Best-effort — retried on next app start or token refresh.
    }
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
    _ref.listen(emailVerificationPendingProvider, (_, __) => notifyListeners());
  }

  String? redirect(BuildContext context, GoRouterState state) {
    final authState = _ref.read(authNotifierProvider);
    if (authState.isLoading) return null;

    final loc = state.matchedLocation;
    final verificationPending =
        _ref.read(emailVerificationPendingProvider);

    // Awaiting email verification — lock to that screen.
    if (verificationPending) {
      return loc == '/verify-email' ? null : '/verify-email';
    }

    final user = authState.valueOrNull;

    if (user == null) {
      return loc == '/login' ? null : '/login';
    }
    if (user.role == null) {
      return loc == '/role-selection' ? null : '/role-selection';
    }
    if (loc == '/login' ||
        loc == '/role-selection' ||
        loc == '/verify-email') {
      return '/home';
    }
    // Any other authenticated route is allowed through as-is.
    return null;
  }
}

/// Shared with [NotificationService] so it can navigate the app from
/// background/terminated notification taps, which happen outside the
/// widget tree.
final navigatorKeyProvider =
    Provider<GlobalKey<NavigatorState>>((ref) => GlobalKey<NavigatorState>());

final goRouterProvider = Provider<GoRouter>((ref) {
  final notifier = ref.watch(routerNotifierProvider);
  return GoRouter(
    navigatorKey: ref.watch(navigatorKeyProvider),
    initialLocation: '/login',
    refreshListenable: notifier,
    redirect: notifier.redirect,
    routes: [
      GoRoute(path: '/login', builder: (_, __) => const LoginScreen()),
      GoRoute(
          path: '/verify-email',
          builder: (_, __) => const EmailVerificationScreen()),
      GoRoute(
          path: '/role-selection',
          builder: (_, __) => const RoleSelectionScreen()),
      GoRoute(path: '/home', builder: (_, __) => const HomeScreen()),
      GoRoute(
          path: '/notification-settings',
          builder: (_, __) => const NotificationSettingsScreen()),
      GoRoute(path: '/enroll', builder: (_, __) => const EnrollScreen()),
      GoRoute(
          path: '/create-course',
          builder: (_, __) => const CreateCourseScreen()),
      GoRoute(
        path: '/chat/:courseId',
        builder: (_, state) {
          final course = state.extra as dynamic;
          return ChatScreen(course: course);
        },
      ),
      GoRoute(
        path: '/diagnosis-result/:courseId',
        builder: (_, state) {
          final result = state.extra as DiagnosisResult;
          final courseId = state.pathParameters['courseId']!;
          return DiagnosisResultScreen(result: result, courseId: courseId);
        },
      ),
      GoRoute(
        path: '/case-history/:courseId',
        builder: (_, state) {
          final course = state.extra as dynamic;
          return CaseHistoryScreen(course: course);
        },
        routes: [
          GoRoute(
            path: 'sessions/:sessionId',
            builder: (_, state) {
              final sessionItem = state.extra as CompletedSessionItem;
              return TranscriptViewerScreen(
                appBarTitle: sessionItem.diseaseName,
                headerLabel: 'You',
                sessionItem: sessionItem,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/class-analytics/:courseId/students/:studentId',
        builder: (_, state) {
          final courseId = state.pathParameters['courseId']!;
          final studentId = state.pathParameters['studentId']!;
          final email = state.uri.queryParameters['email'] ?? '';
          return StudentDrilldownScreen(
            courseId: courseId,
            studentId: studentId,
            studentLabel: email,
          );
        },
        routes: [
          GoRoute(
            path: 'sessions/:sessionId',
            builder: (_, state) {
              final extra = state.extra as Map<String, dynamic>;
              return TranscriptViewerScreen(
                appBarTitle: extra['headerLabel'] as String,
                headerLabel: extra['headerLabel'] as String,
                sessionItem: extra['sessionItem'] as CompletedSessionItem,
              );
            },
          ),
        ],
      ),
      GoRoute(
        path: '/course/:courseId',
        builder: (_, state) {
          final course = state.extra as dynamic;
          return CourseManagementScreen(course: course);
        },
        routes: [
          GoRoute(
            path: 'upload',
            builder: (_, state) {
              final course = state.extra as dynamic;
              return DiseaseUploadScreen(course: course);
            },
          ),
          GoRoute(
            path: 'students',
            builder: (_, state) {
              final course = state.extra as dynamic;
              return StudentsScreen(course: course);
            },
            routes: [
              GoRoute(
                path: ':studentId',
                builder: (_, state) {
                  final extra = state.extra as Map<String, dynamic>;
                  return StudentSessionsScreen(
                    course: extra['course'],
                    student: extra['student'],
                  );
                },
                routes: [
                  GoRoute(
                    path: 'sessions/:sessionId',
                    builder: (_, state) {
                      final extra = state.extra as Map<String, dynamic>;
                      final student = extra['student'] as EnrolledStudent;
                      return TranscriptViewerScreen(
                        appBarTitle: student.displayLabel,
                        headerLabel: student.displayLabel,
                        sessionItem: extra['sessionItem'],
                      );
                    },
                  ),
                ],
              ),
            ],
          ),
        ],
      ),
    ],
  );
});
