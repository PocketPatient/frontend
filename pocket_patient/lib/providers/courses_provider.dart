import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/course.dart';
import 'auth_provider.dart';

final coursesProvider =
    AsyncNotifierProvider<CoursesNotifier, List<Course>>(CoursesNotifier.new);

class CoursesNotifier extends AsyncNotifier<List<Course>> {
  @override
  Future<List<Course>> build() async {
    return await ref.read(apiServiceProvider).getCourses();
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
        () => ref.read(apiServiceProvider).getCourses());
  }

  /// Professor: create a new course. Returns the created course (contains
  /// the auto-generated class code).
  Future<Course> createCourse(String title, String semester) async {
    final course =
        await ref.read(apiServiceProvider).createCourse(title, semester);
    state = AsyncData([...state.valueOrNull ?? [], course]);
    return course;
  }

  /// Student: join a course by class code.
  Future<Course> joinCourse(String classCode) async {
    final course = await ref.read(apiServiceProvider).joinCourse(classCode);
    state = AsyncData([...state.valueOrNull ?? [], course]);
    return course;
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
