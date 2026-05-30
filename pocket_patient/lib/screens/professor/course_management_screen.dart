import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:go_router/go_router.dart';
import '../../models/course.dart';

class CourseManagementScreen extends StatelessWidget {
  final Course course;

  const CourseManagementScreen({super.key, required this.course});

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(course.title),
        backgroundColor: const Color(0xFFCC0033),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          // ── Course info card ───────────────────────────────────────────────
          _SectionCard(
            children: [
              _InfoRow(
                icon: Icons.tag,
                label: 'Class code',
                value: course.classCode,
                onTap: () {
                  Clipboard.setData(ClipboardData(text: course.classCode));
                  ScaffoldMessenger.of(context).showSnackBar(
                    SnackBar(
                        content: Text(
                            '${course.classCode} copied to clipboard')),
                  );
                },
                trailingIcon: Icons.copy_outlined,
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.people_outline,
                label: 'Enrolled students',
                value: '${course.studentCount}',
              ),
              if (course.semester != null) ...[
                const Divider(height: 1),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Semester',
                  value: course.semester!,
                ),
              ],
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.circle,
                label: 'Status',
                value: course.isActive ? 'Active' : 'Inactive',
                valueColor:
                    course.isActive ? Colors.green[700] : Colors.grey[600],
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Content section ────────────────────────────────────────────────
          Text(
            'Content',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.grey[600], letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          _SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.upload_file_outlined,
                    color: Color(0xFFCC0033)),
                title: const Text('Upload Disease Document'),
                subtitle: const Text('CSV or JSON — defines units & diseases'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () =>
                    context.push('/course/${course.id}/upload', extra: course),
              ),
              const Divider(height: 1),
              ListTile(
                leading: Icon(Icons.view_list_outlined, color: Colors.grey[400]),
                title: Text('Units',
                    style: TextStyle(color: Colors.grey[600])),
                subtitle: Text('Available after disease doc upload',
                    style: TextStyle(color: Colors.grey[400], fontSize: 12)),
                trailing: Icon(Icons.chevron_right, color: Colors.grey[300]),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Unit management coming in Week 5')),
                  );
                },
              ),
            ],
          ),

          const SizedBox(height: 20),

          // ── Students section ───────────────────────────────────────────────
          Text(
            'Students',
            style: Theme.of(context)
                .textTheme
                .titleSmall
                ?.copyWith(color: Colors.grey[600], letterSpacing: 0.8),
          ),
          const SizedBox(height: 8),
          _SectionCard(
            children: [
              ListTile(
                leading: const Icon(Icons.people_outline,
                    color: Color(0xFFCC0033)),
                title: const Text('Manage Students'),
                subtitle:
                    Text('${course.studentCount} enrolled'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () {
                  ScaffoldMessenger.of(context).showSnackBar(
                    const SnackBar(
                        content: Text('Student management coming soon')),
                  );
                },
              ),
            ],
          ),
        ],
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

class _SectionCard extends StatelessWidget {
  final List<Widget> children;

  const _SectionCard({required this.children});

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(children: children),
    );
  }
}

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;
  final Color? valueColor;
  final IconData? trailingIcon;
  final VoidCallback? onTap;

  const _InfoRow({
    required this.icon,
    required this.label,
    required this.value,
    this.valueColor,
    this.trailingIcon,
    this.onTap,
  });

  @override
  Widget build(BuildContext context) {
    final row = Padding(
      padding: const EdgeInsets.symmetric(horizontal: 16, vertical: 14),
      child: Row(
        children: [
          Icon(icon, size: 18, color: Colors.grey[500]),
          const SizedBox(width: 12),
          Expanded(
            child: Text(label,
                style:
                    TextStyle(color: Colors.grey[600], fontSize: 14)),
          ),
          Text(
            value,
            style: TextStyle(
              fontWeight: FontWeight.w600,
              fontSize: 14,
              color: valueColor ?? Theme.of(context).colorScheme.onSurface,
            ),
          ),
          if (trailingIcon != null) ...[
            const SizedBox(width: 6),
            Icon(trailingIcon, size: 16, color: Colors.grey[400]),
          ],
        ],
      ),
    );

    if (onTap != null) {
      return InkWell(onTap: onTap, child: row);
    }
    return row;
  }
}
