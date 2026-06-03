import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/chat_session.dart';
import '../../models/course.dart';
import '../../providers/session_provider.dart';

class ChatScreen extends ConsumerStatefulWidget {
  final Course course;

  const ChatScreen({super.key, required this.course});

  @override
  ConsumerState<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends ConsumerState<ChatScreen> {
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();

  // Optimistic / transient send state
  String? _pendingContent; // student message being sent right now
  bool _patientTyping = false;
  bool _sendError = false;

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  void _scrollToBottom({bool animated = true}) {
    WidgetsBinding.instance.addPostFrameCallback((_) {
      if (!_scrollCtrl.hasClients) return;
      if (animated) {
        _scrollCtrl.animateTo(
          _scrollCtrl.position.maxScrollExtent,
          duration: const Duration(milliseconds: 300),
          curve: Curves.easeOut,
        );
      } else {
        _scrollCtrl.jumpTo(_scrollCtrl.position.maxScrollExtent);
      }
    });
  }

  Future<void> _send() async {
    final text = _inputCtrl.text.trim();
    if (text.isEmpty) return;

    _inputCtrl.clear();
    _focusNode.unfocus();

    setState(() {
      _pendingContent = text;
      _patientTyping = false;
      _sendError = false;
    });
    _scrollToBottom();

    // Short delay so the optimistic bubble renders, then show typing.
    await Future.delayed(const Duration(milliseconds: 200));
    if (!mounted) return;
    setState(() => _patientTyping = true);
    _scrollToBottom();

    try {
      await ref.read(sessionProvider(widget.course.id).notifier).sendMessage(text);
      if (!mounted) return;
      setState(() {
        _pendingContent = null;
        _patientTyping = false;
        _sendError = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _patientTyping = false;
        _sendError = true;
      });
    }
  }

  Future<void> _retry() async {
    final text = _pendingContent;
    if (text == null) return;
    setState(() {
      _sendError = false;
      _patientTyping = true;
    });
    try {
      await ref.read(sessionProvider(widget.course.id).notifier).sendMessage(text);
      if (!mounted) return;
      setState(() {
        _pendingContent = null;
        _patientTyping = false;
        _sendError = false;
      });
      _scrollToBottom();
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _patientTyping = false;
        _sendError = true;
      });
    }
  }

  Future<void> _startNewSession() async {
    await ref.read(sessionProvider(widget.course.id).notifier).startNewSession();
    _scrollToBottom(animated: false);
  }

  @override
  Widget build(BuildContext context) {
    final sessionAsync = ref.watch(sessionProvider(widget.course.id));

    return GestureDetector(
      onTap: () => FocusScope.of(context).unfocus(),
      child: Scaffold(
        backgroundColor: Colors.grey[50],
        appBar: AppBar(
          backgroundColor: const Color(0xFFCC0033),
          foregroundColor: Colors.white,
          title: Column(
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              const Text(
                'Virtual Patient',
                style: TextStyle(fontSize: 16, fontWeight: FontWeight.bold),
              ),
              Text(
                widget.course.title,
                style: const TextStyle(
                    fontSize: 12, fontWeight: FontWeight.w400),
                overflow: TextOverflow.ellipsis,
              ),
            ],
          ),
          actions: [
            IconButton(
              icon: const Icon(Icons.info_outline),
              tooltip: 'Case info',
              onPressed: () => _showCaseInfoSheet(context),
            ),
          ],
        ),
        body: sessionAsync.when(
          loading: () =>
              const Center(child: CircularProgressIndicator()),
          error: (e, _) => _ErrorState(onRetry: () => ref
              .invalidate(sessionProvider(widget.course.id))),
          data: (session) => session == null
              ? _NoSessionState(
                  onStart: _startNewSession,
                  courseTitle: widget.course.title,
                )
              : _ChatBody(
                  session: session,
                  scrollCtrl: _scrollCtrl,
                  inputCtrl: _inputCtrl,
                  focusNode: _focusNode,
                  pendingContent: _pendingContent,
                  patientTyping: _patientTyping,
                  sendError: _sendError,
                  onSend: _send,
                  onRetry: _retry,
                ),
        ),
      ),
    );
  }

  void _showCaseInfoSheet(BuildContext context) {
    final session = ref.read(sessionProvider(widget.course.id)).valueOrNull;
    showModalBottomSheet(
      context: context,
      shape: const RoundedRectangleBorder(
        borderRadius: BorderRadius.vertical(top: Radius.circular(20)),
      ),
      builder: (ctx) => Padding(
        padding: const EdgeInsets.fromLTRB(24, 20, 24, 32),
        child: Column(
          mainAxisSize: MainAxisSize.min,
          crossAxisAlignment: CrossAxisAlignment.start,
          children: [
            Center(
              child: Container(
                width: 40,
                height: 4,
                decoration: BoxDecoration(
                  color: Colors.grey[300],
                  borderRadius: BorderRadius.circular(2),
                ),
              ),
            ),
            const SizedBox(height: 20),
            Text(
              widget.course.title,
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            if (widget.course.semester != null) ...[
              const SizedBox(height: 4),
              Text(widget.course.semester!,
                  style:
                      TextStyle(color: Colors.grey[600], fontSize: 13)),
            ],
            const SizedBox(height: 16),
            _InfoRow(
              icon: Icons.schedule,
              label: 'Messaging window',
              value: widget.course.msgWindowStart != null &&
                      widget.course.msgWindowEnd != null
                  ? '${widget.course.msgWindowStart} – ${widget.course.msgWindowEnd}'
                  : 'Not set',
            ),
            const SizedBox(height: 8),
            _InfoRow(
              icon: Icons.language,
              label: 'Timezone',
              value: widget.course.msgTimezone,
            ),
            if (session != null) ...[
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.tag,
                label: 'Turn count',
                value: '${session.turnCount}',
              ),
              const SizedBox(height: 8),
              _InfoRow(
                icon: Icons.circle,
                label: 'Status',
                value: session.status,
              ),
            ],
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Chat body — shown when session exists
// ---------------------------------------------------------------------------

class _ChatBody extends StatelessWidget {
  final ChatSession session;
  final ScrollController scrollCtrl;
  final TextEditingController inputCtrl;
  final FocusNode focusNode;
  final String? pendingContent;
  final bool patientTyping;
  final bool sendError;
  final VoidCallback onSend;
  final VoidCallback onRetry;

  const _ChatBody({
    required this.session,
    required this.scrollCtrl,
    required this.inputCtrl,
    required this.focusNode,
    required this.pendingContent,
    required this.patientTyping,
    required this.sendError,
    required this.onSend,
    required this.onRetry,
  });

  @override
  Widget build(BuildContext context) {
    // Build the combined message list: confirmed + pending + typing indicator
    final confirmed = session.messages;
    final bool showPending = pendingContent != null;
    final bool showLastPatientAwaiting = !showPending &&
        !patientTyping &&
        confirmed.isNotEmpty &&
        !confirmed.last.isPatient;

    // Total item count
    int itemCount = confirmed.length;
    if (showPending) itemCount++; // optimistic student bubble
    if (sendError) itemCount++; // retry row
    if (patientTyping) itemCount++; // typing indicator
    if (showLastPatientAwaiting) itemCount++; // static awaiting

    return Column(
      children: [
        Expanded(
          child: ListView.builder(
            controller: scrollCtrl,
            padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
            itemCount: itemCount,
            itemBuilder: (context, index) {
              // Confirmed messages
              if (index < confirmed.length) {
                return _BubbleTile(message: confirmed[index]);
              }

              int extra = index - confirmed.length;

              // Optimistic pending student message
              if (showPending && extra == 0) {
                return _PendingBubble(content: pendingContent!);
              }
              if (showPending) extra--;

              // Error / retry row
              if (sendError && extra == 0) {
                return _RetryRow(onRetry: onRetry);
              }
              if (sendError) extra--;

              // Patient typing indicator
              if (patientTyping && extra == 0) {
                return const _TypingIndicator();
              }

              // Static awaiting (last confirmed msg was from student)
              if (showLastPatientAwaiting && extra == 0) {
                return const _AwaitingBubble();
              }

              return const SizedBox.shrink();
            },
          ),
        ),
        const Divider(height: 1),
        _InputBar(
          controller: inputCtrl,
          focusNode: focusNode,
          enabled: session.isActive && pendingContent == null && !patientTyping,
          onSend: onSend,
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Empty / error states
// ---------------------------------------------------------------------------

class _NoSessionState extends StatefulWidget {
  final Future<void> Function() onStart;
  final String courseTitle;

  const _NoSessionState(
      {required this.onStart, required this.courseTitle});

  @override
  State<_NoSessionState> createState() => _NoSessionStateState();
}

class _NoSessionStateState extends State<_NoSessionState> {
  bool _loading = false;

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Padding(
        padding: const EdgeInsets.all(32),
        child: Column(
          mainAxisAlignment: MainAxisAlignment.center,
          children: [
            Icon(Icons.chat_bubble_outline,
                size: 64, color: Colors.grey[300]),
            const SizedBox(height: 20),
            Text(
              'No active case',
              style: Theme.of(context)
                  .textTheme
                  .titleMedium
                  ?.copyWith(fontWeight: FontWeight.bold),
            ),
            const SizedBox(height: 8),
            Text(
              'Your virtual patient will reach out when a case is assigned.',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 14),
            ),
            const SizedBox(height: 32),
            // Dev / testing button
            OutlinedButton.icon(
              onPressed: _loading
                  ? null
                  : () async {
                      setState(() => _loading = true);
                      try {
                        await widget.onStart();
                      } catch (e) {
                        if (context.mounted) {
                          ScaffoldMessenger.of(context).showSnackBar(
                            SnackBar(
                                content: Text(
                                    'Could not start case: $e')),
                          );
                        }
                      } finally {
                        if (mounted) setState(() => _loading = false);
                      }
                    },
              icon: _loading
                  ? const SizedBox(
                      width: 16,
                      height: 16,
                      child: CircularProgressIndicator(strokeWidth: 2))
                  : const Icon(Icons.play_arrow_outlined),
              label: const Text('Start New Case'),
              style: OutlinedButton.styleFrom(
                padding: const EdgeInsets.symmetric(
                    horizontal: 20, vertical: 12),
              ),
            ),
            const SizedBox(height: 8),
            Text(
              'Dev/testing only — cases will be auto-assigned in production.',
              textAlign: TextAlign.center,
              style: TextStyle(
                  color: Colors.grey[400],
                  fontSize: 11,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

class _ErrorState extends StatelessWidget {
  final VoidCallback onRetry;

  const _ErrorState({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Center(
      child: Column(
        mainAxisAlignment: MainAxisAlignment.center,
        children: [
          Text('Could not load session',
              style: TextStyle(color: Colors.grey[600])),
          const SizedBox(height: 12),
          OutlinedButton(onPressed: onRetry, child: const Text('Retry')),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Message bubble widgets
// ---------------------------------------------------------------------------

class _BubbleTile extends StatelessWidget {
  final ChatMessage message;

  const _BubbleTile({required this.message});

  @override
  Widget build(BuildContext context) {
    return _Bubble(
      content: message.content,
      isPatient: message.isPatient,
      timestamp: _relativeTime(message.sentAt),
      showCheck: !message.isPatient,
    );
  }
}

class _PendingBubble extends StatelessWidget {
  final String content;

  const _PendingBubble({required this.content});

  @override
  Widget build(BuildContext context) {
    return _Bubble(
      content: content,
      isPatient: false,
      timestamp: 'Sending…',
      showCheck: false,
      dimmed: true,
    );
  }
}

class _Bubble extends StatelessWidget {
  final String content;
  final bool isPatient;
  final String timestamp;
  final bool showCheck;
  final bool dimmed;

  const _Bubble({
    required this.content,
    required this.isPatient,
    required this.timestamp,
    required this.showCheck,
    this.dimmed = false,
  });

  @override
  Widget build(BuildContext context) {
    const scarlet = Color(0xFFCC0033);

    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4),
      child: Row(
        mainAxisAlignment:
            isPatient ? MainAxisAlignment.start : MainAxisAlignment.end,
        crossAxisAlignment: CrossAxisAlignment.end,
        children: [
          if (isPatient) ...[
            CircleAvatar(
              radius: 16,
              backgroundColor: Colors.grey[300],
              child: const Icon(Icons.person_outline,
                  size: 18, color: Colors.white),
            ),
            const SizedBox(width: 8),
          ],
          Flexible(
            child: Opacity(
              opacity: dimmed ? 0.6 : 1.0,
              child: Column(
                crossAxisAlignment: isPatient
                    ? CrossAxisAlignment.start
                    : CrossAxisAlignment.end,
                children: [
                  Container(
                    padding: const EdgeInsets.symmetric(
                        horizontal: 14, vertical: 10),
                    decoration: BoxDecoration(
                      color: isPatient ? Colors.grey[200] : scarlet,
                      borderRadius: BorderRadius.only(
                        topLeft: const Radius.circular(18),
                        topRight: const Radius.circular(18),
                        bottomLeft:
                            Radius.circular(isPatient ? 4 : 18),
                        bottomRight:
                            Radius.circular(isPatient ? 18 : 4),
                      ),
                    ),
                    child: Text(
                      content,
                      style: TextStyle(
                        color:
                            isPatient ? Colors.black87 : Colors.white,
                        fontSize: 14,
                      ),
                    ),
                  ),
                  const SizedBox(height: 2),
                  Row(
                    mainAxisSize: MainAxisSize.min,
                    children: [
                      Text(
                        timestamp,
                        style: TextStyle(
                            color: Colors.grey[500], fontSize: 11),
                      ),
                      if (showCheck) ...[
                        const SizedBox(width: 3),
                        Icon(Icons.check,
                            size: 11, color: Colors.grey[400]),
                      ],
                    ],
                  ),
                ],
              ),
            ),
          ),
          if (!isPatient) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _RetryRow extends StatelessWidget {
  final VoidCallback onRetry;

  const _RetryRow({required this.onRetry});

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 4, horizontal: 8),
      child: Row(
        mainAxisAlignment: MainAxisAlignment.end,
        children: [
          Text('Failed to send — ',
              style:
                  TextStyle(color: Colors.red[400], fontSize: 12)),
          GestureDetector(
            onTap: onRetry,
            child: Text(
              'Tap to retry',
              style: TextStyle(
                color: Colors.red[600],
                fontSize: 12,
                fontWeight: FontWeight.bold,
                decoration: TextDecoration.underline,
              ),
            ),
          ),
        ],
      ),
    );
  }
}

class _TypingIndicator extends StatefulWidget {
  const _TypingIndicator();

  @override
  State<_TypingIndicator> createState() => _TypingIndicatorState();
}

class _TypingIndicatorState extends State<_TypingIndicator>
    with SingleTickerProviderStateMixin {
  late final AnimationController _ctrl;

  @override
  void initState() {
    super.initState();
    _ctrl = AnimationController(
      vsync: this,
      duration: const Duration(milliseconds: 900),
    )..repeat();
  }

  @override
  void dispose() {
    _ctrl.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.person_outline,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 16, vertical: 12),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: List.generate(3, (i) {
                final delay = i / 3;
                return AnimatedBuilder(
                  animation: _ctrl,
                  builder: (_, __) {
                    final t = ((_ctrl.value - delay) % 1.0).abs();
                    final opacity = t < 0.5
                        ? 0.3 + t * 1.4
                        : 1.0 - (t - 0.5) * 1.4;
                    return Padding(
                      padding:
                          const EdgeInsets.symmetric(horizontal: 2),
                      child: Opacity(
                        opacity: opacity.clamp(0.3, 1.0),
                        child: Container(
                          width: 7,
                          height: 7,
                          decoration: BoxDecoration(
                            color: Colors.grey[500],
                            shape: BoxShape.circle,
                          ),
                        ),
                      ),
                    );
                  },
                );
              }),
            ),
          ),
        ],
      ),
    );
  }
}

class _AwaitingBubble extends StatelessWidget {
  const _AwaitingBubble();

  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 8),
      child: Row(
        children: [
          CircleAvatar(
            radius: 16,
            backgroundColor: Colors.grey[300],
            child: const Icon(Icons.person_outline,
                size: 18, color: Colors.white),
          ),
          const SizedBox(width: 8),
          Container(
            padding:
                const EdgeInsets.symmetric(horizontal: 14, vertical: 10),
            decoration: BoxDecoration(
              color: Colors.grey[200],
              borderRadius: const BorderRadius.only(
                topLeft: Radius.circular(18),
                topRight: Radius.circular(18),
                bottomLeft: Radius.circular(4),
                bottomRight: Radius.circular(18),
              ),
            ),
            child: Row(
              mainAxisSize: MainAxisSize.min,
              children: [
                Text(
                  'Awaiting patient reply',
                  style: TextStyle(
                    color: Colors.grey[500],
                    fontSize: 13,
                    fontStyle: FontStyle.italic,
                  ),
                ),
                const SizedBox(width: 6),
                SizedBox(
                  width: 12,
                  height: 12,
                  child: CircularProgressIndicator(
                    strokeWidth: 1.5,
                    color: Colors.grey[400],
                  ),
                ),
              ],
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Input bar
// ---------------------------------------------------------------------------

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final bool enabled;
  final VoidCallback onSend;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.enabled,
    required this.onSend,
  });

  @override
  Widget build(BuildContext context) {
    return SafeArea(
      top: false,
      child: Padding(
        padding: const EdgeInsets.fromLTRB(12, 8, 8, 8),
        child: Row(
          children: [
            Expanded(
              child: TextField(
                controller: controller,
                focusNode: focusNode,
                enabled: enabled,
                minLines: 1,
                maxLines: 4,
                textInputAction: TextInputAction.send,
                onSubmitted: enabled ? (_) => onSend() : null,
                decoration: InputDecoration(
                  hintText: enabled
                      ? 'Type a message…'
                      : 'Waiting for patient…',
                  hintStyle:
                      TextStyle(color: Colors.grey[400], fontSize: 14),
                  filled: true,
                  fillColor:
                      enabled ? Colors.white : Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        BorderSide(color: Colors.grey[300]!),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide:
                        BorderSide(color: Colors.grey[200]!),
                  ),
                  focusedBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: const BorderSide(
                        color: Color(0xFFCC0033), width: 1.5),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: 'chat_send',
              onPressed: enabled ? onSend : null,
              backgroundColor: enabled
                  ? const Color(0xFFCC0033)
                  : Colors.grey[300],
              foregroundColor:
                  enabled ? Colors.white : Colors.grey[500],
              elevation: enabled ? 2 : 0,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Info row (used in case info bottom sheet)
// ---------------------------------------------------------------------------

class _InfoRow extends StatelessWidget {
  final IconData icon;
  final String label;
  final String value;

  const _InfoRow(
      {required this.icon, required this.label, required this.value});

  @override
  Widget build(BuildContext context) {
    return Row(
      children: [
        Icon(icon, size: 16, color: Colors.grey[600]),
        const SizedBox(width: 8),
        Text('$label: ',
            style: TextStyle(
                fontSize: 13,
                color: Colors.grey[700],
                fontWeight: FontWeight.w500)),
        Expanded(
          child: Text(
            value,
            style: TextStyle(fontSize: 13, color: Colors.grey[600]),
            overflow: TextOverflow.ellipsis,
          ),
        ),
      ],
    );
  }
}

// ---------------------------------------------------------------------------
// Helpers
// ---------------------------------------------------------------------------

String _relativeTime(DateTime dt) {
  final diff = DateTime.now().difference(dt);
  if (diff.inMinutes < 1) return 'just now';
  if (diff.inMinutes < 60) return '${diff.inMinutes} min ago';
  // Absolute for > 1 hour
  final hour = dt.hour % 12 == 0 ? 12 : dt.hour % 12;
  final min = dt.minute.toString().padLeft(2, '0');
  final period = dt.hour < 12 ? 'AM' : 'PM';
  return '$hour:$min $period';
}
