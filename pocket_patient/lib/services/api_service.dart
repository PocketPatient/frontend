import 'dart:convert';
import 'package:dio/dio.dart';
import '../config/constants.dart';
import '../models/auth_response.dart';
import '../models/chat_session.dart';
import '../models/course.dart';
import '../models/diagnosis_result.dart';
import '../models/completed_session_item.dart';
import '../models/disease_document_preview.dart';
import '../models/enrolled_student.dart';
import '../models/unit.dart';
import '../models/user.dart';
import 'auth_service.dart';

class ApiService {
  final Dio _dio;

  ApiService({required AuthService authService, Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: kApiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            )) {
    _dio.interceptors.add(_AuthInterceptor(authService, _dio));
  }

  Future<AuthResponse> login(String firebaseIdToken) async {
    final resp = await _dio.post(
      '/auth/login',
      data: {'firebase_id_token': firebaseIdToken},
    );
    return AuthResponse.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<AppUser> getMe() async {
    final resp = await _dio.get('/users/me');
    return AppUser.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<AppUser> setRole(String role) async {
    final resp = await _dio.put('/users/me/role', data: {'role': role});
    return AppUser.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<AppUser> updateFcmToken(String token) async {
    final resp =
        await _dio.put('/users/me/fcm-token', data: {'fcm_token': token});
    return AppUser.fromJson(resp.data as Map<String, dynamic>);
  }

  // -------------------------------------------------------------------------
  // Courses
  // -------------------------------------------------------------------------

  Future<List<Course>> getCourses() async {
    final resp = await _dio.get('/courses');
    final list = resp.data as List<dynamic>;
    return list
        .map((e) => Course.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Course> createCourse(String title, String semester) async {
    final resp = await _dio.post('/courses', data: {
      'title': title,
      'semester': semester.isEmpty ? null : semester,
    });
    return Course.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Course> getCourse(String courseId) async {
    final resp = await _dio.get('/courses/$courseId');
    return Course.fromJson(resp.data as Map<String, dynamic>);
  }

  // -------------------------------------------------------------------------
  // Disease documents
  // -------------------------------------------------------------------------

  Future<DiseaseDocumentPreview> uploadDiseaseDocument(
    String courseId,
    List<int> fileBytes,
    String fileName,
  ) async {
    final formData = FormData.fromMap({
      'file': MultipartFile.fromBytes(fileBytes, filename: fileName),
    });
    final resp = await _dio.post(
      '/courses/$courseId/disease-document',
      data: formData,
    );
    return DiseaseDocumentPreview.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<DiseaseDocumentConfirmResult> confirmDiseaseDocument(
      String courseId) async {
    final resp =
        await _dio.post('/courses/$courseId/disease-document/confirm');
    return DiseaseDocumentConfirmResult.fromJson(
        resp.data as Map<String, dynamic>);
  }

  // -------------------------------------------------------------------------
  // Units
  // -------------------------------------------------------------------------

  Future<List<Unit>> getUnits(String courseId) async {
    final resp = await _dio.get('/courses/$courseId/units');
    return (resp.data as List)
        .map((e) => Unit.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<Unit> releaseUnit(String courseId, String unitId) async {
    final resp =
        await _dio.put('/courses/$courseId/units/$unitId/release');
    return Unit.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Unit> closeUnit(String courseId, String unitId) async {
    final resp =
        await _dio.put('/courses/$courseId/units/$unitId/close');
    return Unit.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Course> updateCourseSettings(
    String courseId, {
    String? msgWindowStart,
    String? msgWindowEnd,
    String? msgTimezone,
  }) async {
    final body = <String, dynamic>{};
    if (msgWindowStart != null) body['msg_window_start'] = msgWindowStart;
    if (msgWindowEnd != null) body['msg_window_end'] = msgWindowEnd;
    if (msgTimezone != null) body['msg_timezone'] = msgTimezone;
    final resp = await _dio.put('/courses/$courseId', data: body);
    return Course.fromJson(resp.data as Map<String, dynamic>);
  }

  // -------------------------------------------------------------------------
  // Sessions / chat
  // -------------------------------------------------------------------------

  /// Returns the active session for [courseId], or throws a 404 DioException
  /// if the student has no active session in that course.
  Future<ChatSession> getActiveSession(String courseId) async {
    final resp =
        await _dio.get('/sessions/active', queryParameters: {'course_id': courseId});
    return ChatSession.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<ChatSession> createSession(String courseId) async {
    final resp = await _dio.post('/sessions', data: {'course_id': courseId});
    return ChatSession.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<ChatSession> getSession(String sessionId) async {
    final resp = await _dio.get('/sessions/$sessionId');
    return ChatSession.fromJson(resp.data as Map<String, dynamic>);
  }

  /// [instant] skips the persona's reply-delay scheduling so the patient
  /// responds immediately — used by the debug "instant reply" button.
  Future<ChatMessage> sendMessage(String sessionId, String content,
      {bool instant = false}) async {
    final resp = await _dio.post(
      '/sessions/$sessionId/messages',
      data: {'content': content},
      queryParameters: instant ? {'instant': true} : null,
    );
    return ChatMessage.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<DiagnosisResult> submitDiagnosis(
    String sessionId,
    String primaryDx,
    List<String> differentials,
    String justification,
  ) async {
    // Incorrect submissions trigger two sequential LLM calls (grade + hint),
    // which can take 10–20 s. Override the default 10 s receive timeout.
    final resp = await _dio.post(
      '/sessions/$sessionId/diagnose',
      data: {
        'primary_dx': primaryDx,
        'differentials': differentials,
        'justification': justification,
      },
      options: Options(receiveTimeout: const Duration(seconds: 45)),
    );
    return DiagnosisResult.fromJson(resp.data as Map<String, dynamic>);
  }

  // -------------------------------------------------------------------------
  // Enrollments / students
  // -------------------------------------------------------------------------

  Future<List<EnrolledStudent>> getStudents(String courseId) async {
    final resp = await _dio.get('/courses/$courseId/students');
    return (resp.data as List)
        .map((e) => EnrolledStudent.fromJson(e as Map<String, dynamic>))
        .toList();
  }

  Future<void> removeStudent(String courseId, String userId) async {
    await _dio.delete('/courses/$courseId/students/$userId');
  }

  /// A student's sessions (active + completed) within a course, for the
  /// professor transcript viewer (Week 12).
  Future<PaginatedSessions> getStudentSessions(
    String courseId,
    String studentId, {
    int page = 1,
    int pageSize = 20,
  }) async {
    final resp = await _dio.get('/sessions', queryParameters: {
      'course_id': courseId,
      'student_id': studentId,
      'page': page,
      'page_size': pageSize,
    });
    return PaginatedSessions.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<Course> joinCourse(String classCode) async {
    final resp = await _dio.post(
      '/enrollments/join',
      data: {'class_code': classCode.toUpperCase()},
    );
    return Course.fromJson(resp.data as Map<String, dynamic>);
  }
}

class _AuthInterceptor extends Interceptor {
  final AuthService _authService;
  final Dio _dio;
  Future<AuthResponse>? _refreshFuture;

  _AuthInterceptor(this._authService, this._dio);

  @override
  void onRequest(
      RequestOptions options, RequestInterceptorHandler handler) async {
    final token = await _authService.readAccessToken();
    if (token != null) {
      options.headers['Authorization'] = 'Bearer $token';
    }
    handler.next(options);
  }

  @override
  void onError(DioException err, ErrorInterceptorHandler handler) async {
    if (err.response?.statusCode == 401) {
      try {
        final auth = await _refreshAccessToken();
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer ${auth.accessToken}';
        final retryResp = await _dio.fetch(opts);
        return handler.resolve(retryResp);
      } catch (_) {
        return handler.next(err);
      }
    }
    handler.next(err);
  }

  /// Refreshes the access token, coalescing concurrent 401s into a single
  /// `/auth/refresh` call.
  ///
  /// The backend's refresh token is single-use (Redis GETDEL). If several
  /// requests 401 at once on a stale cached access token — as happens at app
  /// startup — and each independently calls `/auth/refresh` with the same
  /// refresh token, only the first succeeds; the rest get a 401 from
  /// `/auth/refresh` itself and wipe the credentials the first call just
  /// wrote. Sharing one in-flight refresh future avoids that race.
  Future<AuthResponse> _refreshAccessToken() {
    return _refreshFuture ??=
        _doRefresh().whenComplete(() => _refreshFuture = null);
  }

  Future<AuthResponse> _doRefresh() async {
    final refreshToken = await _authService.readRefreshToken();
    if (refreshToken == null) {
      throw StateError('No refresh token stored');
    }
    try {
      // Use a fresh Dio with no interceptors to avoid infinite loops.
      final refreshDio = Dio(BaseOptions(baseUrl: kApiBaseUrl));
      final resp = await refreshDio.post(
        '/auth/refresh',
        data: {'refresh_token': refreshToken},
      );
      final auth = AuthResponse.fromJson(resp.data as Map<String, dynamic>);

      // Cross-account guard: if the refreshed token belongs to a different
      // user than the one who originally logged in, the credentials are
      // mixed (e.g. access token for user A, refresh token for user B).
      // Clear everything and let the router redirect to the login screen.
      final storedUserId = await _authService.readUserId();
      final refreshedUserId = _subFromJwt(auth.accessToken);
      if (storedUserId != null &&
          refreshedUserId != null &&
          storedUserId != refreshedUserId) {
        throw StateError('Refreshed token belongs to a different user');
      }

      await _authService.writeToken(auth.accessToken);
      await _authService.writeRefreshToken(auth.refreshToken);
      return auth;
    } catch (_) {
      await _authService.clearAll();
      rethrow;
    }
  }

  /// Decodes the JWT payload (without verifying the signature) and returns
  /// the `sub` claim, which is the backend user UUID.
  static String? _subFromJwt(String token) {
    try {
      final parts = token.split('.');
      if (parts.length != 3) return null;
      // Base64url → base64 (add padding)
      var payload = parts[1];
      payload += '=' * ((4 - payload.length % 4) % 4);
      final decoded = utf8.decode(base64Url.decode(payload));
      final map = jsonDecode(decoded) as Map<String, dynamic>;
      return map['sub'] as String?;
    } catch (_) {
      return null;
    }
  }
}
