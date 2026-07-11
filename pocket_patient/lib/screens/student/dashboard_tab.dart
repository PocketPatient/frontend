import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../providers/courses_provider.dart';
import '../../providers/student_summary_provider.dart';
import '../../widgets/student_summary_charts.dart';

/// Week 13 — student analytics dashboard (score trend, category radar,
/// response-time trend). Scoped per-course, so a course selector is shown
/// when the student is enrolled in more than one.
class StudentDashboardTab extends ConsumerStatefulWidget {
  const StudentDashboardTab({super.key});

  @override
  ConsumerState<StudentDashboardTab> createState() => _StudentDashboardTabState();
}

class _StudentDashboardTabState extends ConsumerState<StudentDashboardTab> {
  String? _selectedCourseId;

  @override
  Widget build(BuildContext context) {
    final coursesAsync = ref.watch(coursesProvider);

    return coursesAsync.when(
      loading: () => const Center(child: CircularProgressIndicator()),
      error: (e, _) => Center(
        child: Text('Could not load courses', style: TextStyle(color: Colors.grey[600])),
      ),
      data: (courses) {
        if (courses.isEmpty) {
          return Center(
            child: Column(
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                Icon(Icons.bar_chart_rounded, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Text('Enroll in a course to see your analytics.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ],
            ),
          );
        }

        _selectedCourseId ??= courses.first.id;
        final courseId = _selectedCourseId!;

        return Column(
          children: [
            if (courses.length > 1)
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 12, 16, 0),
                child: Row(
                  children: [
                    Text('Course:', style: TextStyle(color: Colors.grey[600], fontSize: 13)),
                    const SizedBox(width: 8),
                    Expanded(
                      child: DropdownButton<String>(
                        value: courseId,
                        isExpanded: true,
                        underline: const SizedBox.shrink(),
                        items: courses
                            .map((c) => DropdownMenuItem(value: c.id, child: Text(c.title)))
                            .toList(),
                        onChanged: (v) => setState(() => _selectedCourseId = v),
                      ),
                    ),
                  ],
                ),
              ),
            Expanded(
              child: _DashboardBody(courseId: courseId),
            ),
          ],
        );
      },
    );
  }
}

class _DashboardBody extends ConsumerWidget {
  final String courseId;

  const _DashboardBody({required this.courseId});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final summaryAsync = ref.watch(studentSummaryProvider(courseId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(studentSummaryProvider(courseId)),
      child: summaryAsync.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [
            SizedBox(height: 120),
            Center(child: CircularProgressIndicator()),
          ],
        ),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
          children: [
            Center(
              child: Text('Could not load your analytics.',
                  style: TextStyle(color: Colors.grey[600])),
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton(
                onPressed: () => ref.invalidate(studentSummaryProvider(courseId)),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
        data: (summary) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
          children: [StudentSummaryCharts(summary: summary)],
        ),
      ),
    );
  }
}
