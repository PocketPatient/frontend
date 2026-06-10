import 'package:dio/dio.dart';
import '../config/constants.dart';
import '../models/auth_response.dart';
import '../models/chat_session.dart';
import '../models/course.dart';
import '../models/diagnosis_result.dart';
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

  Future<ChatMessage> sendMessage(String sessionId, String content) async {
    final resp = await _dio.post(
      '/sessions/$sessionId/messages',
      data: {'content': content},
    );
    return ChatMessage.fromJson(resp.data as Map<String, dynamic>);
  }

  Future<DiagnosisResult> submitDiagnosis(
    String sessionId,
    String primaryDx,
    List<String> differentials,
    String justification,
  ) async {
    final resp = await _dio.post('/sessions/$sessionId/diagnose', data: {
      'primary_dx': primaryDx,
      'differentials': differentials,
      'justification': justification,
    });
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
      final refreshToken = await _authService.readRefreshToken();
      if (refreshToken == null) return handler.next(err);
      try {
        // Use a fresh Dio with no interceptors to avoid infinite loops.
        final refreshDio = Dio(BaseOptions(baseUrl: kApiBaseUrl));
        final resp = await refreshDio.post(
          '/auth/refresh',
          data: {'refresh_token': refreshToken},
        );
        final auth = AuthResponse.fromJson(resp.data as Map<String, dynamic>);
        await _authService.writeToken(auth.accessToken);
        await _authService.writeRefreshToken(auth.refreshToken);
        final opts = err.requestOptions;
        opts.headers['Authorization'] = 'Bearer ${auth.accessToken}';
        final retryResp = await _dio.fetch(opts);
        return handler.resolve(retryResp);
      } catch (_) {
        await _authService.clearAll();
        return handler.next(err);
      }
    }
    handler.next(err);
  }
}
