import 'package:flutter_test/flutter_test.dart';
import 'package:pocket_patient/models/course.dart';
import 'package:pocket_patient/providers/courses_provider.dart';

Course _course(String id, {int students = 0, String title = 'Psychiatry 101'}) =>
    Course(
      id: id,
      title: title,
      classCode: '3GF3EG',
      professorId: 'prof-1',
      isActive: true,
      studentCount: students,
      msgTimezone: 'America/New_York',
      createdAt: DateTime.utc(2026, 10, 17),
    );

void main() {
  group('upsertCourse', () {
    test('appends a course that is not in the list', () {
      final result = upsertCourse([_course('a')], _course('b'));
      expect(result.map((c) => c.id), ['a', 'b']);
    });

    test('replaces (does not duplicate) a course already fetched by a refresh', () {
      // Regression: a refresh landed before the create/join response, so the
      // course was already present; appending showed it twice (one copy with a
      // stale student count).
      final fetched = [_course('x', students: 1), _course('a')];
      final result = upsertCourse(fetched, _course('a', title: 'Renamed'));
      expect(result.map((c) => c.id), ['x', 'a']);
      expect(result.last.title, 'Renamed');
    });

    test('does not mutate the input list', () {
      final original = [_course('a')];
      upsertCourse(original, _course('a', students: 5));
      expect(original.single.studentCount, 0);
    });
  });
}
