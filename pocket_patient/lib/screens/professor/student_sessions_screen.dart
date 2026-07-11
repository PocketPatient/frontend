import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/completed_session_item.dart';
import '../../models/course.dart';
import '../../models/enrolled_student.dart';
import '../../providers/auth_provider.dart';

/// Lists a single student's sessions (active + completed) within a course.
/// Tapping a row opens the read-only transcript viewer (Week 12 Task 2).
class StudentSessionsScreen extends ConsumerStatefulWidget {
  final Course course;
  final EnrolledStudent student;

  const StudentSessionsScreen({
    super.key,
    required this.course,
    required this.student,
  });

  @override
  ConsumerState<StudentSessionsScreen> createState() =>
      _StudentSessionsScreenState();
}

class _StudentSessionsScreenState extends ConsumerState<StudentSessionsScreen> {
  List<CompletedSessionItem>? _sessions;
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
          .getStudentSessions(widget.course.id, widget.student.userId);
      if (mounted) setState(() => _sessions = result.items);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load sessions.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(widget.student.displayLabel),
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
    if (_error != null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error!, style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final sessions = _sessions ?? [];
    if (sessions.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.forum_outlined, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No cases yet.', style: TextStyle(color: Colors.grey[500], fontSize: 16)),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: sessions.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 16),
        itemBuilder: (context, index) => _SessionRow(
          item: sessions[index],
          onTap: () => context.push(
            '/course/${widget.course.id}/students/${widget.student.userId}/sessions/${sessions[index].sessionId}',
            extra: {'student': widget.student, 'sessionItem': sessions[index]},
          ),
        ),
      ),
    );
  }
}

class _SessionRow extends StatelessWidget {
  final CompletedSessionItem item;
  final VoidCallback onTap;

  const _SessionRow({required this.item, required this.onTap});

  @override
  Widget build(BuildContext context) {
    final statusChip = item.isActive
        ? const _Chip(label: 'In progress', color: Colors.orange)
        : _Chip(
            label: item.score != null ? '${item.score!.round()}%' : 'Diagnosed',
            color: Colors.green,
          );

    return ListTile(
      title: Text(item.diseaseName, style: const TextStyle(fontWeight: FontWeight.w500)),
      subtitle: Text(
        '${item.category} • ${item.turnCount} turns • ${_fmtDate(item.startedAt)}',
        style: TextStyle(color: Colors.grey[500], fontSize: 12),
      ),
      trailing: statusChip,
      onTap: onTap,
    );
  }

  String _fmtDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';
}

class _Chip extends StatelessWidget {
  final String label;
  final Color color;

  const _Chip({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text(
        label,
        style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600),
      ),
    );
  }
}
