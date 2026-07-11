import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/student_drilldown.dart';
import '../../providers/auth_provider.dart';
import '../../widgets/student_summary_charts.dart';

/// Week 14 Task 3 — per-student drill-down for professors. Same charts as
/// the student's own dashboard (StudentSummaryCharts, shared), plus a case
/// list with transcript links.
class StudentDrilldownScreen extends ConsumerStatefulWidget {
  final String courseId;
  final String studentId;
  final String studentLabel;

  const StudentDrilldownScreen({
    super.key,
    required this.courseId,
    required this.studentId,
    required this.studentLabel,
  });

  @override
  ConsumerState<StudentDrilldownScreen> createState() => _StudentDrilldownScreenState();
}

class _StudentDrilldownScreenState extends ConsumerState<StudentDrilldownScreen> {
  StudentDrilldown? _drilldown;
  bool _loading = true;
  String? _error;

  @override
  void initState() {
    super.initState();
    _load();
  }

  Future<void> _load() async {
    setState(() {
      _loading = true;
      _error = null;
    });
    try {
      final result = await ref
          .read(apiServiceProvider)
          .getStudentDrilldown(widget.courseId, widget.studentId);
      if (mounted) setState(() => _drilldown = result);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load this student\'s analytics.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.studentLabel),
        backgroundColor: const Color(0xFFCC0033),
        foregroundColor: Colors.white,
      ),
      body: _buildBody(),
    );
  }

  Widget _buildBody() {
    if (_loading) {
      return const Center(child: CircularProgressIndicator());
    }
    if (_error != null || _drilldown == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error ?? 'Could not load this student\'s analytics.',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final drilldown = _drilldown!;

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView(
        physics: const AlwaysScrollableScrollPhysics(),
        padding: const EdgeInsets.fromLTRB(16, 16, 16, 24),
        children: [
          StudentSummaryCharts(summary: drilldown.summary),
          if (drilldown.sessions.isNotEmpty) ...[
            const SizedBox(height: 16),
            Container(
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
                  const Text('Cases',
                      style: TextStyle(fontWeight: FontWeight.bold, fontSize: 14)),
                  const SizedBox(height: 8),
                  ...drilldown.sessions.map((item) => ListTile(
                        contentPadding: EdgeInsets.zero,
                        title: Text(item.diseaseName),
                        subtitle: Text('${item.category} • ${item.turnCount} turns'),
                        trailing: TextButton(
                          onPressed: () => context.push(
                            '/class-analytics/${widget.courseId}/students/${widget.studentId}/sessions/${item.sessionId}',
                            extra: {'headerLabel': widget.studentLabel, 'sessionItem': item},
                          ),
                          child: const Text('View Transcript'),
                        ),
                      )),
                ],
              ),
            ),
          ],
        ],
      ),
    );
  }
}
