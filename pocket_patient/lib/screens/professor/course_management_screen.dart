import 'dart:math';
import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter/services.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/course.dart';
import '../../models/unit.dart';
import '../../providers/auth_provider.dart';
import '../../providers/units_provider.dart';

class CourseManagementScreen extends ConsumerStatefulWidget {
  final Course course;

  const CourseManagementScreen({super.key, required this.course});

  @override
  ConsumerState<CourseManagementScreen> createState() =>
      _CourseManagementScreenState();
}

class _CourseManagementScreenState
    extends ConsumerState<CourseManagementScreen> {
  // Messaging window local state
  late TimeOfDay _windowStart;
  late TimeOfDay _windowEnd;
  late String _timezone;
  bool _savingSettings = false;

  static const _timezones = [
    'America/New_York',
    'America/Chicago',
    'America/Denver',
    'America/Los_Angeles',
  ];

  static const _timezoneLabels = {
    'America/New_York': 'Eastern (ET)',
    'America/Chicago': 'Central (CT)',
    'America/Denver': 'Mountain (MT)',
    'America/Los_Angeles': 'Pacific (PT)',
  };

  @override
  void initState() {
    super.initState();
    _windowStart = _parseTime(widget.course.msgWindowStart ?? '08:00:00');
    _windowEnd = _parseTime(widget.course.msgWindowEnd ?? '22:00:00');
    _timezone = _timezones.contains(widget.course.msgTimezone)
        ? widget.course.msgTimezone
        : 'America/New_York';
  }

  TimeOfDay _parseTime(String hhmm) {
    final parts = hhmm.split(':');
    return TimeOfDay(
      hour: int.tryParse(parts[0]) ?? 8,
      minute: int.tryParse(parts[1]) ?? 0,
    );
  }

  String _formatTime(TimeOfDay t) =>
      '${t.hour.toString().padLeft(2, '0')}:${t.minute.toString().padLeft(2, '0')}:00';

  Future<void> _pickTime({required bool isStart}) async {
    final picked = await showTimePicker(
      context: context,
      initialTime: isStart ? _windowStart : _windowEnd,
    );
    if (picked == null) return;
    setState(() => isStart ? _windowStart = picked : _windowEnd = picked);
  }

  Future<void> _saveSettings() async {
    setState(() => _savingSettings = true);
    try {
      await ref.read(apiServiceProvider).updateCourseSettings(
            widget.course.id,
            msgWindowStart: _formatTime(_windowStart),
            msgWindowEnd: _formatTime(_windowEnd),
            msgTimezone: _timezone,
          );
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(const SnackBar(content: Text('Settings saved')));
    } on DioException catch (e) {
      final detail = e.response?.data?['detail'] as String?;
      if (!mounted) return;
      ScaffoldMessenger.of(context).showSnackBar(
        SnackBar(content: Text(detail ?? 'Failed to save settings')),
      );
    } finally {
      if (mounted) setState(() => _savingSettings = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unitsAsync = ref.watch(unitsProvider(widget.course.id));

    return Scaffold(
      appBar: AppBar(
        title: Text(widget.course.title),
        backgroundColor: const Color(0xFFCC0033),
        foregroundColor: Colors.white,
      ),
      body: RefreshIndicator(
        onRefresh: () =>
            ref.read(unitsProvider(widget.course.id).notifier).refresh(),
        child: ListView(
          padding: const EdgeInsets.all(16),
          children: [
            // ── Course info ────────────────────────────────────────────────
            _SectionCard(children: [
              _InfoRow(
                icon: Icons.tag,
                label: 'Class code',
                value: widget.course.classCode,
                trailingIcon: Icons.copy_outlined,
                onTap: () {
                  Clipboard.setData(
                      ClipboardData(text: widget.course.classCode));
                  ScaffoldMessenger.of(context).showSnackBar(SnackBar(
                      content: Text(
                          '${widget.course.classCode} copied to clipboard')));
                },
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.people_outline,
                label: 'Enrolled students',
                value: '${widget.course.studentCount}',
              ),
              if (widget.course.semester != null) ...[
                const Divider(height: 1),
                _InfoRow(
                  icon: Icons.calendar_today_outlined,
                  label: 'Semester',
                  value: widget.course.semester!,
                ),
              ],
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.circle,
                label: 'Status',
                value: widget.course.isActive ? 'Active' : 'Inactive',
                valueColor: widget.course.isActive
                    ? Colors.green[700]
                    : Colors.grey[600],
              ),
            ]),

            const SizedBox(height: 20),

            // ── Simulation settings ────────────────────────────────────────
            const _SectionLabel('SIMULATION SETTINGS'),
            const SizedBox(height: 8),
            _SectionCard(children: [
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 16, 16, 8),
                child: _MessagingWindowClock(
                  start: _windowStart,
                  end: _windowEnd,
                ),
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.schedule_outlined,
                label: 'Window start',
                value: _windowStart.format(context),
                trailingIcon: Icons.edit_outlined,
                onTap: () => _pickTime(isStart: true),
              ),
              const Divider(height: 1),
              _InfoRow(
                icon: Icons.schedule_outlined,
                label: 'Window end',
                value: _windowEnd.format(context),
                trailingIcon: Icons.edit_outlined,
                onTap: () => _pickTime(isStart: false),
              ),
              const Divider(height: 1),
              Padding(
                padding:
                    const EdgeInsets.symmetric(horizontal: 16, vertical: 8),
                child: Row(
                  children: [
                    Icon(Icons.public_outlined,
                        size: 18, color: Colors.grey[500]),
                    const SizedBox(width: 12),
                    Expanded(
                      child: Text('Timezone',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 14)),
                    ),
                    DropdownButtonHideUnderline(
                      child: DropdownButton<String>(
                        value: _timezone,
                        isDense: true,
                        items: _timezones
                            .map((tz) => DropdownMenuItem(
                                  value: tz,
                                  child: Text(
                                    _timezoneLabels[tz] ?? tz,
                                    style: const TextStyle(
                                        fontSize: 14,
                                        fontWeight: FontWeight.w600),
                                  ),
                                ))
                            .toList(),
                        onChanged: (v) {
                          if (v != null) setState(() => _timezone = v);
                        },
                      ),
                    ),
                  ],
                ),
              ),
              const Divider(height: 1),
              Padding(
                padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
                child: SizedBox(
                  width: double.infinity,
                  child: FilledButton.icon(
                    onPressed: _savingSettings ? null : _saveSettings,
                    icon: _savingSettings
                        ? const SizedBox(
                            width: 16,
                            height: 16,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.save_outlined, size: 18),
                    label: Text(_savingSettings ? 'Saving…' : 'Save settings'),
                    style: FilledButton.styleFrom(
                        backgroundColor: const Color(0xFFCC0033)),
                  ),
                ),
              ),
            ]),

            const SizedBox(height: 20),

            // ── Content / Units ────────────────────────────────────────────
            const _SectionLabel('CONTENT'),
            const SizedBox(height: 8),

            // Upload tile
            _SectionCard(children: [
              ListTile(
                leading: const Icon(Icons.upload_file_outlined,
                    color: Color(0xFFCC0033)),
                title: const Text('Upload Disease Document'),
                subtitle:
                    const Text('CSV or JSON — defines units & diseases'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                    '/course/${widget.course.id}/upload',
                    extra: widget.course),
              ),
            ]),

            const SizedBox(height: 12),

            // Unit list
            unitsAsync.when(
              loading: () => const Padding(
                padding: EdgeInsets.symmetric(vertical: 24),
                child: Center(child: CircularProgressIndicator()),
              ),
              error: (e, _) => Padding(
                padding: const EdgeInsets.symmetric(vertical: 8),
                child: Text('Could not load units',
                    style: TextStyle(color: Colors.grey[500])),
              ),
              data: (units) => units.isEmpty
                  ? Padding(
                      padding: const EdgeInsets.symmetric(vertical: 12),
                      child: Text(
                        'No units yet — upload a disease document to create units.',
                        textAlign: TextAlign.center,
                        style:
                            TextStyle(color: Colors.grey[500], fontSize: 13),
                      ),
                    )
                  : Column(
                      children: units
                          .map((u) => _UnitCard(
                              unit: u, courseId: widget.course.id))
                          .toList(),
                    ),
            ),

            const SizedBox(height: 20),

            // ── Students ───────────────────────────────────────────────────
            const _SectionLabel('STUDENTS'),
            const SizedBox(height: 8),
            _SectionCard(children: [
              ListTile(
                leading: const Icon(Icons.people_outline,
                    color: Color(0xFFCC0033)),
                title: const Text('Manage Students'),
                subtitle: Text('${widget.course.studentCount} enrolled'),
                trailing: const Icon(Icons.chevron_right),
                onTap: () => context.push(
                    '/course/${widget.course.id}/students',
                    extra: widget.course),
              ),
            ]),

            const SizedBox(height: 32),
          ],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Unit card — release / close / expandable disease list
// ────────────────────────────────────────────────────────────────────────────

class _UnitCard extends ConsumerStatefulWidget {
  final Unit unit;
  final String courseId;

  const _UnitCard({required this.unit, required this.courseId});

  @override
  ConsumerState<_UnitCard> createState() => _UnitCardState();
}

class _UnitCardState extends ConsumerState<_UnitCard> {
  bool _expanded = false;
  bool _busy = false;

  Color get _statusColor => switch (widget.unit.status) {
        'released' => Colors.green,
        'closed' => Colors.grey,
        _ => Colors.orange,
      };

  String get _statusLabel => switch (widget.unit.status) {
        'released' => 'Released',
        'closed' => 'Closed',
        _ => 'Draft',
      };

  Future<void> _release() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Release unit?'),
        content: Text(
            'Students will be able to see "${widget.unit.label}" is active.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0033)),
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Release')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(unitsProvider(widget.courseId).notifier)
          .releaseUnit(widget.unit.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  Future<void> _close() async {
    final confirm = await showDialog<bool>(
      context: context,
      builder: (_) => AlertDialog(
        title: const Text('Close unit?'),
        content: Text(
            'Active cases in "${widget.unit.label}" will continue, but no new cases will be assigned.'),
        actions: [
          TextButton(
              onPressed: () => Navigator.pop(context, false),
              child: const Text('Cancel')),
          FilledButton(
              onPressed: () => Navigator.pop(context, true),
              child: const Text('Close unit')),
        ],
      ),
    );
    if (confirm != true || !mounted) return;
    setState(() => _busy = true);
    try {
      await ref
          .read(unitsProvider(widget.courseId).notifier)
          .closeUnit(widget.unit.id);
    } catch (e) {
      if (!mounted) return;
      ScaffoldMessenger.of(context)
          .showSnackBar(SnackBar(content: Text('Error: $e')));
    } finally {
      if (mounted) setState(() => _busy = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final unit = widget.unit;

    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side:
            BorderSide(color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          // Header row
          InkWell(
            borderRadius: const BorderRadius.vertical(top: Radius.circular(12)),
            onTap: unit.diseases.isNotEmpty
                ? () => setState(() => _expanded = !_expanded)
                : null,
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Row(
                children: [
                  Expanded(
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Text(unit.label,
                            style: const TextStyle(
                                fontWeight: FontWeight.w600, fontSize: 15)),
                        const SizedBox(height: 4),
                        Text(
                          '${unit.diseaseCount} disease${unit.diseaseCount == 1 ? '' : 's'}',
                          style: TextStyle(
                              color: Colors.grey[600], fontSize: 13),
                        ),
                        if (unit.releaseDate != null) ...[
                          const SizedBox(height: 2),
                          Text(
                            'Released ${_fmtDate(unit.releaseDate!)}',
                            style: TextStyle(
                                color: Colors.grey[500], fontSize: 12),
                          ),
                        ],
                      ],
                    ),
                  ),
                  const SizedBox(width: 8),
                  _StatusBadge(
                      label: _statusLabel, color: _statusColor),
                  if (unit.diseases.isNotEmpty) ...[
                    const SizedBox(width: 4),
                    Icon(
                      _expanded
                          ? Icons.expand_less
                          : Icons.expand_more,
                      color: Colors.grey[400],
                    ),
                  ],
                ],
              ),
            ),
          ),

          // Expandable disease list
          if (_expanded && unit.diseases.isNotEmpty) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                children: unit.diseases.map((d) => _DiseaseRow(d)).toList(),
              ),
            ),
          ],

          // Action buttons
          if (!unit.isClosed && !_busy) ...[
            const Divider(height: 1),
            Padding(
              padding:
                  const EdgeInsets.symmetric(horizontal: 16, vertical: 10),
              child: Row(
                mainAxisAlignment: MainAxisAlignment.end,
                children: [
                  if (unit.isDraft)
                    FilledButton.icon(
                      onPressed: _release,
                      icon: const Icon(Icons.play_arrow_outlined, size: 16),
                      label: const Text('Release'),
                      style: FilledButton.styleFrom(
                        backgroundColor: Colors.green[700],
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                  if (unit.isReleased)
                    OutlinedButton.icon(
                      onPressed: _close,
                      icon: const Icon(Icons.stop_outlined, size: 16),
                      label: const Text('Close unit'),
                      style: OutlinedButton.styleFrom(
                        padding: const EdgeInsets.symmetric(
                            horizontal: 14, vertical: 8),
                        textStyle: const TextStyle(fontSize: 13),
                      ),
                    ),
                ],
              ),
            ),
          ],

          if (_busy)
            const Padding(
              padding: EdgeInsets.all(12),
              child: Center(
                  child: SizedBox(
                      width: 20,
                      height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2))),
            ),
        ],
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';
}

class _DiseaseRow extends StatelessWidget {
  final DiseaseSummary disease;
  const _DiseaseRow(this.disease);

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        children: [
          Icon(Icons.circle, size: 5, color: Colors.grey[400]),
          const SizedBox(width: 10),
          Expanded(
            child: Text(disease.name,
                style: const TextStyle(fontSize: 13)),
          ),
          const SizedBox(width: 8),
          _DifficultyDots(tier: disease.difficultyTier),
        ],
      ),
    );
  }
}

class _DifficultyDots extends StatelessWidget {
  final int tier;
  const _DifficultyDots({required this.tier});

  @override
  Widget build(BuildContext context) {
    return Row(
      mainAxisSize: MainAxisSize.min,
      children: List.generate(
        5,
        (i) => Icon(
          Icons.circle,
          size: 6,
          color: i < tier
              ? const Color(0xFFCC0033)
              : Colors.grey[300],
        ),
      ),
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Shared helpers
// ────────────────────────────────────────────────────────────────────────────

class _SectionLabel extends StatelessWidget {
  final String text;
  const _SectionLabel(this.text);

  @override
  Widget build(BuildContext context) {
    return Text(
      text,
      style: TextStyle(
        color: Colors.grey[500],
        fontSize: 11,
        fontWeight: FontWeight.w600,
        letterSpacing: 0.8,
      ),
    );
  }
}

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
                      TextStyle(color: Colors.grey[600], fontSize: 14))),
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
    return onTap != null ? InkWell(onTap: onTap, child: row) : row;
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Messaging window clock visual
// ────────────────────────────────────────────────────────────────────────────

class _MessagingWindowClock extends StatelessWidget {
  final TimeOfDay start;
  final TimeOfDay end;

  const _MessagingWindowClock({required this.start, required this.end});

  @override
  Widget build(BuildContext context) {
    final startLabel =
        '${start.hourOfPeriod == 0 ? 12 : start.hourOfPeriod}:${start.minute.toString().padLeft(2, '0')} ${start.period.name.toUpperCase()}';
    final endLabel =
        '${end.hourOfPeriod == 0 ? 12 : end.hourOfPeriod}:${end.minute.toString().padLeft(2, '0')} ${end.period.name.toUpperCase()}';

    // Compute window duration for the subtitle label.
    final startMins = start.hour * 60 + start.minute;
    final endMins = end.hour * 60 + end.minute;
    final durationMins =
        endMins > startMins ? endMins - startMins : (24 * 60 - startMins + endMins);
    final hours = durationMins ~/ 60;
    final mins = durationMins % 60;
    final durationLabel = mins == 0 ? '${hours}h window' : '${hours}h ${mins}m window';

    return Row(
      children: [
        SizedBox(
          width: 80,
          height: 80,
          child: CustomPaint(
            painter: _ClockPainter(
              start: start,
              end: end,
              activeColor: const Color(0xFFCC0033),
              trackColor: Colors.grey.shade200,
            ),
          ),
        ),
        const SizedBox(width: 20),
        Column(
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Row(
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: const BoxDecoration(
                        color: Color(0xFFCC0033), shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(startLabel,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 4),
            Row(
              children: [
                Container(
                    width: 10,
                    height: 10,
                    decoration: BoxDecoration(
                        color: Colors.grey.shade400, shape: BoxShape.circle)),
                const SizedBox(width: 6),
                Text(endLabel,
                    style: const TextStyle(
                        fontSize: 13, fontWeight: FontWeight.w600)),
              ],
            ),
            const SizedBox(height: 6),
            Text(
              durationLabel,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],
        ),
      ],
    );
  }
}

class _ClockPainter extends CustomPainter {
  final TimeOfDay start;
  final TimeOfDay end;
  final Color activeColor;
  final Color trackColor;

  const _ClockPainter({
    required this.start,
    required this.end,
    required this.activeColor,
    required this.trackColor,
  });

  /// Convert a TimeOfDay to an angle in radians on a 24-hour clock face.
  /// 12:00 AM (midnight) = top (−π/2), going clockwise.
  double _timeToAngle(TimeOfDay t) {
    final fraction = (t.hour * 60 + t.minute) / (24 * 60);
    return -pi / 2 + fraction * 2 * pi;
  }

  @override
  void paint(Canvas canvas, Size size) {
    final center = Offset(size.width / 2, size.height / 2);
    final radius = size.width / 2 - 6;
    const strokeWidth = 8.0;

    final trackPaint = Paint()
      ..color = trackColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final activePaint = Paint()
      ..color = activeColor
      ..style = PaintingStyle.stroke
      ..strokeWidth = strokeWidth
      ..strokeCap = StrokeCap.round;

    final rect = Rect.fromCircle(center: center, radius: radius);

    // Full 24-hour track.
    canvas.drawArc(rect, 0, 2 * pi, false, trackPaint);

    final startAngle = _timeToAngle(start);
    final endAngle = _timeToAngle(end);
    double sweepAngle = endAngle - startAngle;
    if (sweepAngle <= 0) sweepAngle += 2 * pi;

    // Active window arc.
    canvas.drawArc(rect, startAngle, sweepAngle, false, activePaint);

    // Hour ticks at 12, 3, 6, 9 (midnight, 6am, noon, 6pm on 24h clock).
    final tickPaint = Paint()
      ..color = Colors.grey.shade400
      ..strokeWidth = 1.5;
    for (int h in [0, 6, 12, 18]) {
      final angle = -pi / 2 + (h / 24) * 2 * pi;
      final inner = center + Offset(cos(angle), sin(angle)) * (radius - 8);
      final outer = center + Offset(cos(angle), sin(angle)) * (radius + 2);
      canvas.drawLine(inner, outer, tickPaint);
    }

    // Center dot.
    canvas.drawCircle(center, 3, Paint()..color = Colors.grey.shade400);
  }

  @override
  bool shouldRepaint(_ClockPainter old) =>
      old.start != start || old.end != end;
}

class _StatusBadge extends StatelessWidget {
  final String label;
  final Color color;
  const _StatusBadge({required this.label, required this.color});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 3),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: TextStyle(
              fontSize: 11,
              color: color,
              fontWeight: FontWeight.w600)),
    );
  }
}
