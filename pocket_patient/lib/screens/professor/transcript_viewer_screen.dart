import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/chat_session.dart';
import '../../models/completed_session_item.dart';
import '../../providers/auth_provider.dart';
import '../../utils/api_error.dart';

/// Read-only transcript view — same bubble layout as the student chat
/// screen, but no input bar and a header showing case metadata instead of
/// the patient-identity card. Shared by the professor's per-student browser
/// (Week 12) and the student's own case history (Week 13) — [headerLabel]
/// is the student's name for the former, "You" for the latter.
class TranscriptViewerScreen extends ConsumerStatefulWidget {
  final String appBarTitle;
  final String headerLabel;
  final CompletedSessionItem sessionItem;

  const TranscriptViewerScreen({
    super.key,
    required this.appBarTitle,
    required this.headerLabel,
    required this.sessionItem,
  });

  @override
  ConsumerState<TranscriptViewerScreen> createState() =>
      _TranscriptViewerScreenState();
}

class _TranscriptViewerScreenState extends ConsumerState<TranscriptViewerScreen> {
  ChatSession? _session;
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
      final session = await ref
          .read(apiServiceProvider)
          .getSession(widget.sessionItem.sessionId);
      if (mounted) setState(() => _session = session);
    } catch (e) {
      if (mounted) setState(() => _error = friendlyErrorMessage(e));
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      backgroundColor: Colors.grey[50],
      appBar: AppBar(
        title: Text(widget.appBarTitle),
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
    if (_error != null || _session == null) {
      return Center(
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Text(_error ?? 'Could not load transcript.',
                style: TextStyle(color: Colors.grey[600])),
            const SizedBox(height: 12),
            OutlinedButton(onPressed: _load, child: const Text('Retry')),
          ],
        ),
      );
    }

    final session = _session!;
    final items = <Widget>[];
    DateTime? lastDay;
    for (final message in session.messages) {
      final day = DateTime(message.sentAt.year, message.sentAt.month, message.sentAt.day);
      if (lastDay == null || day != lastDay) {
        items.add(_ReadOnlyDateSeparator(date: day));
        lastDay = day;
      }
      items.add(_ReadOnlyBubble(message: message));
    }

    return Column(
      children: [
        _TranscriptHeader(studentLabel: widget.headerLabel, item: widget.sessionItem),
        Expanded(
          child: items.isEmpty
              ? Center(
                  child: Text('No messages yet.',
                      style: TextStyle(color: Colors.grey[600])),
                )
              : ListView(
                  padding: const EdgeInsets.fromLTRB(12, 16, 12, 16),
                  children: items,
                ),
        ),
      ],
    );
  }
}

class _TranscriptHeader extends StatelessWidget {
  final String studentLabel;
  final CompletedSessionItem item;

  const _TranscriptHeader({required this.studentLabel, required this.item});

  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  String _fmt(DateTime dt) => '${_months[dt.month - 1]} ${dt.day}';

  String get _durationLabel {
    final completed = item.completedAt;
    if (completed == null) return 'In progress';
    final d = completed.difference(item.startedAt);
    if (d.inMinutes < 60) return '${d.inMinutes} min';
    final hours = d.inHours;
    final mins = d.inMinutes % 60;
    return mins == 0 ? '${hours}h' : '${hours}h ${mins}m';
  }

  @override
  Widget build(BuildContext context) {
    return Container(
      width: double.infinity,
      decoration: BoxDecoration(
        color: Colors.white,
        border: Border(bottom: BorderSide(color: Colors.grey[200]!)),
      ),
      padding: const EdgeInsets.fromLTRB(16, 12, 16, 12),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.start,
        children: [
          Text(
            item.diseaseName,
            style: const TextStyle(fontWeight: FontWeight.bold, fontSize: 15),
          ),
          const SizedBox(height: 4),
          Text(
            [
              studentLabel,
              _fmt(item.startedAt),
              _durationLabel,
              if (item.score != null) 'Score: ${item.score!.round()}%',
            ].join(' • '),
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
        ],
      ),
    );
  }
}

class _ReadOnlyDateSeparator extends StatelessWidget {
  final DateTime date;

  const _ReadOnlyDateSeparator({required this.date});

  static const _weekdays = [
    'Monday', 'Tuesday', 'Wednesday', 'Thursday', 'Friday', 'Saturday', 'Sunday'
  ];
  static const _months = [
    'Jan', 'Feb', 'Mar', 'Apr', 'May', 'Jun', 'Jul', 'Aug', 'Sep', 'Oct', 'Nov', 'Dec'
  ];

  @override
  Widget build(BuildContext context) {
    final label =
        '${_weekdays[date.weekday - 1]}, ${_months[date.month - 1]} ${date.day}';
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
      child: Center(
        child: Container(
          padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
          decoration: BoxDecoration(
            color: Colors.grey[200],
            borderRadius: BorderRadius.circular(12),
          ),
          child: Text(
            label,
            style: TextStyle(
                color: Colors.grey[600], fontSize: 11, fontWeight: FontWeight.w600),
          ),
        ),
      ),
    );
  }
}

class _ReadOnlyBubble extends StatelessWidget {
  final ChatMessage message;

  const _ReadOnlyBubble({required this.message});

  @override
  Widget build(BuildContext context) {
    const scarlet = Color(0xFFCC0033);
    final isPatient = message.isPatient;

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment: isPatient ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isPatient) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person_outline, size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Column(
              crossAxisAlignment:
                  isPatient ? CrossAxisAlignment.start : CrossAxisAlignment.end,
              children: [
                Container(
                  padding: const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: isPatient ? Colors.grey[200] : scarlet,
                    borderRadius: BorderRadius.only(
                      topLeft: const Radius.circular(18),
                      topRight: const Radius.circular(18),
                      bottomLeft: Radius.circular(isPatient ? 4 : 18),
                      bottomRight: Radius.circular(isPatient ? 18 : 4),
                    ),
                  ),
                  child: Text(
                    message.content,
                    style: TextStyle(
                      color: isPatient ? Colors.black87 : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  _relativeTime(message.sentAt),
                  style: TextStyle(color: Colors.grey[600], fontSize: 11),
                ),
              ],
            ),
          ),
          if (!isPatient) const SizedBox(width: 8),
        ],
      ),
    );
  }

  String _relativeTime(DateTime dt) {
    final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
    final minute = dt.minute.toString().padLeft(2, '0');
    final period = dt.hour >= 12 ? 'PM' : 'AM';
    return '$hour:$minute $period';
  }
}
