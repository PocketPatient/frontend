import 'dart:convert';
import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/course.dart';
import 'auth_provider.dart';

const _kCacheKey = 'cached_courses_v1';

final coursesProvider =
    AsyncNotifierProvider<CoursesNotifier, List<Course>>(CoursesNotifier.new);

class CoursesNotifier extends AsyncNotifier<List<Course>> {
  // ------------------------------------------------------------------
  // Cache helpers
  // ------------------------------------------------------------------

  Future<List<Course>> _readCache() async {
    final prefs = await SharedPreferences.getInstance();
    final raw = prefs.getString(_kCacheKey);
    if (raw == null) return [];
    try {
      final list = jsonDecode(raw) as List<dynamic>;
      return list
          .map((e) => Course.fromJson(e as Map<String, dynamic>))
          .toList();
    } catch (_) {
      return [];
    }
  }

  Future<void> _writeCache(List<Course> courses) async {
    final prefs = await SharedPreferences.getInstance();
    // Re-serialise via the same fields used in fromJson.
    final list = courses
        .map((c) => {
              'id': c.id,
              'title': c.title,
              'semester': c.semester,
              'class_code': c.classCode,
              'professor_id': c.professorId,
              'is_active': c.isActive,
              'student_count': c.studentCount,
              'msg_window_start': c.msgWindowStart,
              'msg_window_end': c.msgWindowEnd,
              'msg_timezone': c.msgTimezone,
              'created_at': c.createdAt.toIso8601String(),
            })
        .toList();
    await prefs.setString(_kCacheKey, jsonEncode(list));
  }

  // ------------------------------------------------------------------
  // Provider lifecycle
  // ------------------------------------------------------------------

  @override
  Future<List<Course>> build() async {
    try {
      final courses = await ref.read(apiServiceProvider).getCourses();
      await _writeCache(courses);
      return courses;
    } catch (_) {
      // Network unavailable — fall back to cached data silently.
      final cached = await _readCache();
      if (cached.isNotEmpty) return cached;
      rethrow; // No cache either — propagate so the error state shows.
    }
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    try {
      final courses = await ref.read(apiServiceProvider).getCourses();
      await _writeCache(courses);
      state = AsyncData(courses);
    } catch (_) {
      final cached = await _readCache();
      if (cached.isNotEmpty) {
        state = AsyncData(cached);
      } else {
        state = await AsyncValue.guard(
            () => ref.read(apiServiceProvider).getCourses());
      }
    }
  }

  /// Professor: create a new course. Returns the created course (contains
  /// the auto-generated class code).
  Future<Course> createCourse(String title, String semester) async {
    final course =
        await ref.read(apiServiceProvider).createCourse(title, semester);
    await _upsert(course);
    return course;
  }

  /// Student: join a course by class code.
  Future<Course> joinCourse(String classCode) async {
    final course = await ref.read(apiServiceProvider).joinCourse(classCode);
    await _upsert(course);
    return course;
  }

  /// Insert [course], or replace the entry with the same id. A refresh can
  /// land between the API call and this update (the list may already contain
  /// the course), so a blind append would show it twice.
  Future<void> _upsert(Course course) async {
    final next = upsertCourse(state.valueOrNull ?? const [], course);
    state = AsyncData(next);
    await _writeCache(next);
  }

  /// Extract a user-friendly message from a DioException for course operations.
  static String friendlyError(Object error) {
    if (error is DioException) {
      final status = error.response?.statusCode;
      final detail = error.response?.data?['detail'] as String?;
      if (status == 404 || (detail != null && detail.contains('not found'))) {
        return 'Invalid class code. Double-check and try again.';
      }
      if (status == 410) return 'That course is no longer active.';
      if (status == 409) return 'You are already enrolled in this course.';
      if (status == 403) return 'You do not have permission to do that.';
      if (detail != null) return detail;
    }
    return 'Something went wrong. Please try again.';
  }
}

/// Returns [courses] with [course] added, or replacing the entry that has the
/// same id (keeps its position).
List<Course> upsertCourse(List<Course> courses, Course course) {
  final i = courses.indexWhere((c) => c.id == course.id);
  if (i == -1) return [...courses, course];
  return [...courses]..[i] = course;
}
