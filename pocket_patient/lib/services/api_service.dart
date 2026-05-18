import 'package:dio/dio.dart';
import '../config/constants.dart';

class ApiService {
  final Dio _dio;

  ApiService({Dio? dio})
      : _dio = dio ??
            Dio(BaseOptions(
              baseUrl: kApiBaseUrl,
              connectTimeout: const Duration(seconds: 10),
              receiveTimeout: const Duration(seconds: 10),
            ));
}
