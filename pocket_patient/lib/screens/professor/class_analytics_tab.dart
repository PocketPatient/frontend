import 'dart:io';

import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import 'package:path_provider/path_provider.dart';
import 'package:share_plus/share_plus.dart';
import '../../models/class_summary.dart';
import '../../models/completed_session_item.dart';
import '../../models/enrolled_student.dart';
import '../../providers/auth_provider.dart';
import '../../providers/class_summary_provider.dart';
import '../../providers/courses_provider.dart';
import '../../widgets/dashboard_animations.dart';

const _scarlet = Color(0xFFCC0033);

/// Week 14 — professor class analytics (overview stats, score distribution,
/// unit completion funnel, category heatmap, flagged students, CSV export).
/// Scoped per-course, so a course selector is shown when the professor
/// teaches more than one.
class ClassAnalyticsTab extends ConsumerStatefulWidget {
  const ClassAnalyticsTab({super.key});

  @override
  ConsumerState<ClassAnalyticsTab> createState() => _ClassAnalyticsTabState();
}

class _ClassAnalyticsTabState extends ConsumerState<ClassAnalyticsTab> {
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
                Text('Create a course to see class analytics.',
                    style: TextStyle(color: Colors.grey[500], fontSize: 16)),
              ],
            ),
          );
        }

        _selectedCourseId ??= courses.first.id;
        final courseId = _selectedCourseId!;
        final course = courses.firstWhere((c) => c.id == courseId);

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
              // Keyed so switching courses fully remounts and refetches.
              child: _ClassAnalyticsBody(key: ValueKey(courseId), courseId: courseId, courseTitle: course.title),
            ),
          ],
        );
      },
    );
  }
}

class _ClassAnalyticsBody extends ConsumerStatefulWidget {
  final String courseId;
  final String courseTitle;

  const _ClassAnalyticsBody({super.key, required this.courseId, required this.courseTitle});

  @override
  ConsumerState<_ClassAnalyticsBody> createState() => _ClassAnalyticsBodyState();
}

class _ClassAnalyticsBodyState extends ConsumerState<_ClassAnalyticsBody> {
  List<EnrolledStudent>? _students;
  bool _exporting = false;

  @override
  void initState() {
    super.initState();
    _loadStudents();
  }

  Future<void> _loadStudents() async {
    try {
      final students = await ref.read(apiServiceProvider).getStudents(widget.courseId);
      if (mounted) setState(() => _students = students);
    } catch (_) {
      // Heatmap/flagged-list drill-through just won't be tappable — the
      // summary itself doesn't depend on this.
    }
  }

  String? _userIdForEmail(String email) {
    if (_students == null) return null;
    for (final s in _students!) {
      if (s.email == email) return s.userId;
    }
    return null;
  }

  Future<void> _exportGrades() async {
    setState(() => _exporting = true);
    try {
      final bytes = await ref.read(apiServiceProvider).exportGradesCsv(widget.courseId);
      final dir = await getTemporaryDirectory();
      final file = File('${dir.path}/grades_${widget.courseId}.csv');
      await file.writeAsBytes(bytes);
      if (!mounted) return;
      await Share.shareXFiles(
        [XFile(file.path, mimeType: 'text/csv')],
        subject: 'Grades — ${widget.courseTitle}',
      );
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not export grades.')),
        );
      }
    } finally {
      if (mounted) setState(() => _exporting = false);
    }
  }

  void _openDrilldown(String email) {
    final userId = _userIdForEmail(email);
    if (userId == null) return;
    context.push('/class-analytics/${widget.courseId}/students/$userId?email=$email');
  }

  @override
  Widget build(BuildContext context) {
    final summaryAsync = ref.watch(classSummaryProvider(widget.courseId));

    return RefreshIndicator(
      onRefresh: () async => ref.invalidate(classSummaryProvider(widget.courseId)),
      child: summaryAsync.when(
        loading: () => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          children: const [SizedBox(height: 120), Center(child: CircularProgressIndicator())],
        ),
        error: (e, _) => ListView(
          physics: const AlwaysScrollableScrollPhysics(),
          padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
          children: [
            Center(
              child: Text('Could not load class analytics.',
                  style: TextStyle(color: Colors.grey[600])),
            ),
            const SizedBox(height: 12),
            Center(
              child: OutlinedButton(
                onPressed: () => ref.invalidate(classSummaryProvider(widget.courseId)),
                child: const Text('Retry'),
              ),
            ),
          ],
        ),
        data: (summary) {
          if (summary.totalCompletedCases == 0) {
            return ListView(
              physics: const AlwaysScrollableScrollPhysics(),
              padding: const EdgeInsets.symmetric(horizontal: 32, vertical: 80),
              children: [
                Icon(Icons.query_stats_rounded, size: 64, color: Colors.grey[300]),
                const SizedBox(height: 16),
                Center(
                  child: Text('No completed cases yet.',
                      textAlign: TextAlign.center,
                      style: TextStyle(color: Colors.grey[500], fontSize: 16)),
                ),
              ],
            );
          }

          final cards = [
            _ClassOverviewStats(summary: summary),
            _ScoreDistributionCard(summary: summary),
            _UnitCompletionCard(summary: summary),
            _CategoryHeatmapCard(
              summary: summary,
              courseId: widget.courseId,
              onRowTap: _openDrilldown,
            ),
            if (summary.flaggedStudents.isNotEmpty)
              _FlaggedStudentsCard(summary: summary, onTap: _openDrilldown),
          ];

          return ListView(
            physics: const AlwaysScrollableScrollPhysics(),
            padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
            children: [
              SizedBox(
                width: double.infinity,
                child: OutlinedButton.icon(
                  onPressed: _exporting ? null : _exportGrades,
                  icon: _exporting
                      ? const SizedBox(
                          width: 16, height: 16, child: CircularProgressIndicator(strokeWidth: 2))
                      : const Icon(Icons.download_rounded, size: 18),
                  label: const Text('Export Grades (CSV)'),
                ),
              ),
              const SizedBox(height: 16),
              for (var i = 0; i < cards.length; i++) ...[
                if (i > 0) const SizedBox(height: 16),
                FadeSlideIn(index: i, child: cards[i]),
              ],
            ],
          );
        },
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Overview stats
// ---------------------------------------------------------------------------

class _ClassOverviewStats extends StatelessWidget {
  final ClassSummary summary;

  const _ClassOverviewStats({required this.summary});

  double? get _completionRate {
    final started = summary.completionByUnit.fold<int>(0, (a, u) => a + u.totalCasesStarted);
    final diagnosed = summary.completionByUnit.fold<int>(0, (a, u) => a + u.totalDiagnosed);
    if (started == 0) return null;
    return diagnosed / started * 100;
  }

  @override
  Widget build(BuildContext context) {
    final rate = _completionRate;
    return GridView.count(
      crossAxisCount: 2,
      shrinkWrap: true,
      physics: const NeverScrollableScrollPhysics(),
      mainAxisSpacing: 12,
      crossAxisSpacing: 12,
      childAspectRatio: 2.2,
      children: [
        _StatTile(
          label: 'Enrolled students',
          numericValue: summary.enrolledStudents.toDouble(),
          format: (v) => '${v.round()}',
          icon: Icons.people_outline,
        ),
        _StatTile(
          label: 'Average score',
          numericValue: summary.avgClassScore,
          format: (v) => '${v.round()}%',
          icon: Icons.grade_outlined,
        ),
        _StatTile(
          label: 'Completion rate',
          numericValue: rate,
          format: (v) => '${v.round()}%',
          icon: Icons.task_alt_outlined,
        ),
        _StatTile(
          label: 'Active right now',
          numericValue: summary.studentsWithActiveCase.toDouble(),
          format: (v) => '${v.round()}',
          icon: Icons.chat_bubble_outline,
        ),
      ],
    );
  }
}

class _StatTile extends StatelessWidget {
  final String label;
  final double? numericValue;
  final String Function(double) format;
  final IconData icon;

  const _StatTile({
    required this.label,
    required this.numericValue,
    required this.format,
    required this.icon,
  });

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.all(14),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(14),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Row(
        crossAxisAlignment: CrossAxisAlignment.center,
        children: [
          Icon(icon, color: _scarlet, size: 22),
          const SizedBox(width: 10),
          Expanded(
            child: Column(
              crossAxisAlignment: CrossAxisAlignment.start,
              mainAxisAlignment: MainAxisAlignment.center,
              children: [
                numericValue != null
                    ? AnimatedCountUp(
                        value: numericValue!,
                        format: format,
                        style: const TextStyle(fontSize: 18, fontWeight: FontWeight.bold),
                      )
                    : const Text('—',
                        style: TextStyle(fontSize: 18, fontWeight: FontWeight.bold)),
                Text(label,
                    style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                    maxLines: 1,
                    overflow: TextOverflow.ellipsis),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Score distribution histogram
// ---------------------------------------------------------------------------

class _ScoreDistributionCard extends StatelessWidget {
  final ClassSummary summary;

  const _ScoreDistributionCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    final buckets = summary.scoreDistribution;
    final maxCount = buckets.isEmpty
        ? 1
        : buckets.map((b) => b.count).reduce((a, b) => a > b ? a : b).clamp(1, 1 << 30);

    return _ChartCard(
      title: 'Score distribution',
      child: buckets.isEmpty
          ? const _EmptyChartMessage()
          : Column(
              children: buckets.map((b) {
                final frac = b.count / maxCount;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 8),
                  child: Row(
                    children: [
                      SizedBox(
                        width: 52,
                        child: Text(b.range,
                            style: TextStyle(fontSize: 11, color: Colors.grey[600])),
                      ),
                      Expanded(
                        child: ClipRRect(
                          borderRadius: BorderRadius.circular(4),
                          child: LinearProgressIndicator(
                            value: frac.toDouble(),
                            minHeight: 16,
                            backgroundColor: Colors.grey[100],
                            valueColor: const AlwaysStoppedAnimation(_scarlet),
                          ),
                        ),
                      ),
                      const SizedBox(width: 8),
                      SizedBox(
                        width: 24,
                        child: Text('${b.count}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[700])),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Unit completion funnel
// ---------------------------------------------------------------------------

class _UnitCompletionCard extends StatelessWidget {
  final ClassSummary summary;

  const _UnitCompletionCard({required this.summary});

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Unit completion',
      child: summary.completionByUnit.isEmpty
          ? const _EmptyChartMessage()
          : Column(
              children: summary.completionByUnit.map((u) {
                final frac = u.totalCasesStarted == 0
                    ? 0.0
                    : u.totalDiagnosed / u.totalCasesStarted;
                return Padding(
                  padding: const EdgeInsets.only(bottom: 12),
                  child: Column(
                    crossAxisAlignment: CrossAxisAlignment.start,
                    children: [
                      Row(
                        mainAxisAlignment: MainAxisAlignment.spaceBetween,
                        children: [
                          Text(u.unitLabel, style: const TextStyle(fontSize: 13)),
                          Text(
                            '${u.totalDiagnosed}/${u.totalCasesStarted} diagnosed'
                            '${u.avgScore != null ? ' • avg ${u.avgScore!.round()}%' : ''}',
                            style: TextStyle(fontSize: 11, color: Colors.grey[600]),
                          ),
                        ],
                      ),
                      const SizedBox(height: 4),
                      ClipRRect(
                        borderRadius: BorderRadius.circular(4),
                        child: LinearProgressIndicator(
                          value: frac,
                          minHeight: 8,
                          backgroundColor: Colors.grey[200],
                          valueColor: const AlwaysStoppedAnimation(_scarlet),
                        ),
                      ),
                    ],
                  ),
                );
              }).toList(),
            ),
    );
  }
}

// ---------------------------------------------------------------------------
// Category heatmap
// ---------------------------------------------------------------------------

class _CategoryHeatmapCard extends StatelessWidget {
  final ClassSummary summary;
  final String courseId;
  final void Function(String email) onRowTap;

  const _CategoryHeatmapCard({
    required this.summary,
    required this.courseId,
    required this.onRowTap,
  });

  static Color _cellColor(double? score) {
    if (score == null) return Colors.grey[100]!;
    if (score >= 70) return Colors.green[400]!;
    if (score >= 50) return Colors.amber[400]!;
    return Colors.red[300]!;
  }

  void _showCategoryCases(BuildContext context, String email, String category) {
    showModalBottomSheet(
      context: context,
      isScrollControlled: true,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (_) => _StudentCategorySheet(
        courseId: courseId,
        email: email,
        category: category,
        onRowTap: onRowTap,
      ),
    );
  }

  @override
  Widget build(BuildContext context) {
    final heatmap = summary.categoryHeatmap;
    if (heatmap.students.isEmpty || heatmap.categories.isEmpty) {
      return const _ChartCard(
        title: 'Performance heatmap',
        child: _EmptyChartMessage(
          text: 'Analytics will appear once students begin diagnosing.',
        ),
      );
    }

    const cellSize = 56.0;
    const labelWidth = 140.0;

    return _ChartCard(
      title: 'Performance heatmap',
      child: SingleChildScrollView(
        scrollDirection: Axis.horizontal,
        child: Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                const SizedBox(width: labelWidth),
                for (final cat in heatmap.categories)
                  SizedBox(
                    width: cellSize,
                    child: Text(cat,
                        textAlign: TextAlign.center,
                        maxLines: 2,
                        overflow: TextOverflow.ellipsis,
                        style: TextStyle(fontSize: 9, color: Colors.grey[600])),
                  ),
              ],
            ),
            const SizedBox(height: 4),
            for (var r = 0; r < heatmap.students.length; r++)
              Row(
                children: [
                  SizedBox(
                    width: labelWidth,
                    child: GestureDetector(
                      onTap: () => onRowTap(heatmap.students[r]),
                      child: Text(heatmap.students[r],
                          maxLines: 1,
                          overflow: TextOverflow.ellipsis,
                          style: const TextStyle(
                              fontSize: 12, decoration: TextDecoration.underline)),
                    ),
                  ),
                  for (var c = 0; c < heatmap.categories.length; c++)
                    GestureDetector(
                      onTap: () => _showCategoryCases(
                          context, heatmap.students[r], heatmap.categories[c]),
                      child: Container(
                        width: cellSize,
                        height: cellSize,
                        margin: const EdgeInsets.all(1),
                        decoration: BoxDecoration(
                          color: _cellColor(heatmap.scores[r][c]),
                          borderRadius: BorderRadius.circular(4),
                        ),
                        alignment: Alignment.center,
                        child: Text(
                          heatmap.scores[r][c] != null ? '${heatmap.scores[r][c]!.round()}' : '—',
                          style: const TextStyle(fontSize: 11, color: Colors.black87),
                        ),
                      ),
                    ),
                ],
              ),
          ],
        ),
      ),
    );
  }
}

class _StudentCategorySheet extends ConsumerStatefulWidget {
  final String courseId;
  final String email;
  final String category;
  final void Function(String email) onRowTap;

  const _StudentCategorySheet({
    required this.courseId,
    required this.email,
    required this.category,
    required this.onRowTap,
  });

  @override
  ConsumerState<_StudentCategorySheet> createState() => _StudentCategorySheetState();
}

class _StudentCategorySheetState extends ConsumerState<_StudentCategorySheet> {
  List<CompletedSessionItem>? _cases;
  String? _userId;
  bool _loading = true;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    try {
      final api = ref.read(apiServiceProvider);
      final students = await api.getStudents(widget.courseId);
      final match = students.where((s) => s.email == widget.email).toList();
      if (match.isEmpty) {
        if (mounted) setState(() => _loading = false);
        return;
      }
      _userId = match.first.userId;
      final result = await api.getStudentSessions(widget.courseId, _userId!);
      final filtered =
          result.items.where((s) => s.category == widget.category).toList();
      if (mounted) setState(() => _cases = filtered);
    } catch (_) {
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.fromLTRB(20, 20, 20, 32),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text('${widget.email} — ${widget.category}',
              style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15)),
          const SizedBox(height: 16),
          if (_loading)
            const Center(child: Padding(
              padding: EdgeInsets.symmetric(vertical: 24),
              child: CircularProgressIndicator(),
            ))
          else if (_cases == null || _cases!.isEmpty)
            Padding(
              padding: const EdgeInsets.symmetric(vertical: 12),
              child: Text('No cases in this category.',
                  style: TextStyle(color: Colors.grey[500])),
            )
          else
            ..._cases!.map((c) => ListTile(
                  contentPadding: EdgeInsets.zero,
                  title: Text(c.diseaseName),
                  subtitle: Text('${c.turnCount} turns'),
                  trailing: c.score != null
                      ? Text('${c.score!.round()}%',
                          style: const TextStyle(fontWeight: FontWeight.bold))
                      : null,
                )),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Flagged students
// ---------------------------------------------------------------------------

class _FlaggedStudentsCard extends StatelessWidget {
  final ClassSummary summary;
  final void Function(String email) onTap;

  const _FlaggedStudentsCard({required this.summary, required this.onTap});

  @override
  Widget build(BuildContext context) {
    return _ChartCard(
      title: 'Flagged students',
      child: Column(
        children: summary.flaggedStudents.map((s) {
          return Padding(
            padding: const EdgeInsets.only(bottom: 6),
            child: GestureDetector(
              onTap: () => onTap(s.email),
              child: Container(
                padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 8),
                decoration: BoxDecoration(
                  color: Colors.red[50],
                  borderRadius: BorderRadius.circular(10),
                  border: Border.all(color: Colors.red[100]!),
                ),
                child: Row(
                  children: [
                    Icon(Icons.warning_amber_rounded, size: 16, color: Colors.red[700]),
                    const SizedBox(width: 8),
                    Expanded(
                      child: Text(s.email,
                          overflow: TextOverflow.ellipsis,
                          style: TextStyle(fontSize: 13, color: Colors.red[900])),
                    ),
                    Text('${s.avgScore.round()}% • ${s.completedCases} cases',
                        style: TextStyle(
                            fontSize: 12, fontWeight: FontWeight.bold, color: Colors.red[700])),
                  ],
                ),
              ),
            ),
          );
        }).toList(),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Shared card chrome
// ---------------------------------------------------------------------------

class _ChartCard extends StatelessWidget {
  final String title;
  final Widget child;

  const _ChartCard({required this.title, required this.child});

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.all(16),
      decoration: BoxDecoration(
        color: Colors.white,
        borderRadius: BorderRadius.circular(16),
        border: Border.all(color: Colors.grey[200]!),
      ),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(title, style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
          const SizedBox(height: 12),
          child,
        ],
      ),
    );
  }
}

class _EmptyChartMessage extends StatelessWidget {
  final String text;

  const _EmptyChartMessage({this.text = 'Not enough data yet.'});

  @override
  Widget build(BuildContext context) {
    return SizedBox(
      height: 60,
      child: Center(
        child: Text(text,
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[500], fontSize: 12)),
      ),
    );
  }
}
