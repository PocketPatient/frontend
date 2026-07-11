import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/student_summary.dart';
import 'auth_provider.dart';

/// Keyed by courseId. Backend caches this in Redis (5-min TTL, invalidated
/// on new score), so no local caching layer needed here — pull-to-refresh
/// just re-hits the endpoint.
final studentSummaryProvider =
    FutureProvider.family<StudentSummary, String>((ref, courseId) {
  return ref.read(apiServiceProvider).getStudentSummary(courseId);
});
