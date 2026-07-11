import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';
import '../../models/completed_session_item.dart';
import '../../models/course.dart';
import '../../providers/auth_provider.dart';

/// A student's own completed cases for a course — the Week 8 gap closed out
/// in Week 13. Reuses TranscriptViewerScreen (built for the professor
/// browser in Week 12) for the read-only transcript.
class CaseHistoryScreen extends ConsumerStatefulWidget {
  final Course course;

  const CaseHistoryScreen({super.key, required this.course});

  @override
  ConsumerState<CaseHistoryScreen> createState() => _CaseHistoryScreenState();
}

class _CaseHistoryScreenState extends ConsumerState<CaseHistoryScreen> {
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
          .getMyCompletedSessions(widget.course.id);
      if (mounted) setState(() => _sessions = result.items);
    } catch (_) {
      if (mounted) setState(() => _error = 'Could not load your case history.');
    } finally {
      if (mounted) setState(() => _loading = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: const Text('Case History'),
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
            Icon(Icons.history_rounded, size: 64, color: Colors.grey[300]),
            const SizedBox(height: 16),
            Text('No completed cases yet.',
                style: TextStyle(color: Colors.grey[500], fontSize: 16)),
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
        itemBuilder: (context, index) {
          final item = sessions[index];
          return ListTile(
            title: Text(item.diseaseName, style: const TextStyle(fontWeight: FontWeight.w500)),
            subtitle: Text(
              '${item.category} • ${item.turnCount} turns • ${_fmtDate(item.startedAt)}',
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
            trailing: item.score != null
                ? _ScoreChip(score: item.score!)
                : null,
            onTap: () => context.push(
              '/case-history/${widget.course.id}/sessions/${item.sessionId}',
              extra: item,
            ),
          );
        },
      ),
    );
  }

  String _fmtDate(DateTime dt) => '${dt.month}/${dt.day}/${dt.year}';
}

class _ScoreChip extends StatelessWidget {
  final double score;

  const _ScoreChip({required this.score});

  @override
  Widget build(BuildContext context) {
    final color = score >= 70 ? Colors.green : (score >= 50 ? Colors.amber[700]! : Colors.red);
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 8, vertical: 4),
      decoration: BoxDecoration(
        color: color.withValues(alpha: 0.12),
        borderRadius: BorderRadius.circular(12),
      ),
      child: Text('${score.round()}%',
          style: TextStyle(color: color, fontSize: 12, fontWeight: FontWeight.w600)),
    );
  }
}
