import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/course.dart';
import '../../models/enrolled_student.dart';
import '../../providers/auth_provider.dart';
import '../../providers/courses_provider.dart';

class StudentsScreen extends ConsumerStatefulWidget {
  final Course course;

  const StudentsScreen({super.key, required this.course});

  @override
  ConsumerState<StudentsScreen> createState() => _StudentsScreenState();
}

class _StudentsScreenState extends ConsumerState<StudentsScreen> {
  List<EnrolledStudent>? _students;
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
      final students =
          await ref.read(apiServiceProvider).getStudents(widget.course.id);
      if (mounted) setState(() => _students = students);
    } catch (e) {
      if (mounted) setState(() => _error = 'Could not load students.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  Future<void> _removeStudent(EnrolledStudent student) async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Remove student?'),
        content: Text(
          'Remove ${student.displayLabel} from "${widget.course.title}"? '
          'They will need to re-enroll using the class code.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red[700]),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Remove'),
          ),
        ],
      ),
    );
    if (confirmed != true || !mounted) return;

    try {
      await ref
          .read(apiServiceProvider)
          .removeStudent(widget.course.id, student.userId);
      // Optimistically remove from local list and update course student count.
      setState(() => _students?.removeWhere((s) => s.userId == student.userId));
      // Invalidate courses so the student count refreshes on the home screen.
      await ref.read(coursesProvider.notifier).refresh();
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          SnackBar(content: Text('${student.displayLabel} removed.')),
        );
      }
    } catch (e) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Failed to remove student.')),
        );
      }
    }
  }

  @override
  Widget build(BuildContext context) {
    final studentCount = _students?.length ?? widget.course.studentCount;

    return Scaffold(
      appBar: AppBar(
        title: Text('Students (${_loading ? '…' : studentCount})'),
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
            Text(_error!,
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            OutlinedButton(
              onPressed: _load,
              child: const Text('Retry'),
            ),
          ],
        ),
      );
    }

    final students = _students ?? [];

    if (students.isEmpty) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.people_outline, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text(
              'No students enrolled yet.',
              style: TextStyle(color: Colors.grey[500], fontSize: 16),
            ),
            const SizedBox(height: 8),
            Text(
              'Share the class code ${widget.course.classCode} with your students.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[400], fontSize: 14),
            ),
          ],
        ),
      );
    }

    return RefreshIndicator(
      onRefresh: _load,
      child: ListView.separated(
        padding: const EdgeInsets.symmetric(vertical: 8),
        itemCount: students.length,
        separatorBuilder: (_, __) => const Divider(height: 1, indent: 72),
        itemBuilder: (context, index) {
          final student = students[index];
          return ListTile(
            leading: CircleAvatar(
              backgroundColor:
                  Theme.of(context).colorScheme.primaryContainer,
              child: Text(
                _initials(student.displayLabel),
                style: TextStyle(
                  color: Theme.of(context).colorScheme.primary,
                  fontWeight: FontWeight.bold,
                  fontSize: 14,
                ),
              ),
            ),
            title: Text(
              student.displayLabel,
              style: const TextStyle(fontWeight: FontWeight.w500),
            ),
            subtitle: student.displayName != null
                ? Text(student.email,
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 12))
                : Text(
                    'Enrolled ${_fmtDate(student.enrolledAt)}',
                    style: TextStyle(
                        color: Colors.grey[500], fontSize: 12),
                  ),
            trailing: IconButton(
              icon: const Icon(Icons.person_remove_outlined),
              color: Colors.grey[500],
              tooltip: 'Remove student',
              onPressed: () => _removeStudent(student),
            ),
          );
        },
      ),
    );
  }

  String _initials(String name) {
    final parts = name.trim().split(RegExp(r'\s+'));
    if (parts.length >= 2) {
      return '${parts.first[0]}${parts.last[0]}'.toUpperCase();
    }
    return name.isNotEmpty ? name[0].toUpperCase() : '?';
  }

  String _fmtDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';
}
