import 'package:dio/dio.dart';
import '../config/constants.dart';
import '../models/auth_response.dart';
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
