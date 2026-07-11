import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/class_summary.dart';
import 'auth_provider.dart';

/// Keyed by courseId. Backend caches this in Redis (5-min TTL), so no local
/// caching layer needed here.
final classSummaryProvider =
    FutureProvider.family<ClassSummary, String>((ref, courseId) {
  return ref.read(apiServiceProvider).getClassSummary(courseId);
});
