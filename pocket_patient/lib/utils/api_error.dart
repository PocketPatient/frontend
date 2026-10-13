import 'package:dio/dio.dart';

bool isAiConsentRequired(Object error) {
  if (error is! DioException || error.response?.statusCode != 403) return false;
  final data = error.response?.data;
  if (data is! Map) return false;
  final detail = data['detail'];
  return data['code'] == 'AI_CONSENT_REQUIRED' ||
      (detail is Map && detail['code'] == 'AI_CONSENT_REQUIRED');
}

/// Maps an error from an API call to a user-facing message, consistent
/// across every screen (Week 17 Task 1 — error state audit).
///
/// 401 isn't handled here: ApiService's interceptor already retries once
/// via refresh, and if that fails too, resets auth state so the router
/// redirects to login directly — by the time a screen's error branch would
/// see it, the user is already on their way out. This is the fallback for
/// everything else.
String friendlyErrorMessage(Object error) {
  if (isAiConsentRequired(error)) {
    return 'Review and accept AI data-sharing consent to use virtual patients.';
  }
  if (error is DioException) {
    final status = error.response?.statusCode;
    switch (status) {
      case 401:
        return 'Your session expired. Please sign in again.';
      case 403:
        return "You don't have permission to view this.";
      case 404:
        return 'Not found — it may have been removed.';
      case 409:
        return 'That no longer matches the current state. Try refreshing.';
      case 422:
        return 'Something about that request wasn\'t valid.';
      case 429:
        return 'Too many requests — wait a moment and try again.';
    }
    if (status != null && status >= 500) {
      return 'Something went wrong on our end. Please try again.';
    }
    switch (error.type) {
      case DioExceptionType.connectionTimeout:
      case DioExceptionType.sendTimeout:
      case DioExceptionType.receiveTimeout:
      case DioExceptionType.connectionError:
        return 'Cannot reach the server. Check your connection and try again.';
      default:
        return 'Something went wrong. Please try again.';
    }
  }
  return 'Something went wrong. Please try again.';
}
