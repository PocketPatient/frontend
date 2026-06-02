import 'package:flutter/material.dart';
import '../../models/course.dart';

/// Chat screen for the student–virtual-patient messaging interface.
///
/// Week 6: UI scaffolding only — no live API connection yet.
/// The real message history and send logic will be wired up in Week 7
/// once Mahir ships the conversation endpoints.
class ChatScreen extends StatefulWidget {
  final Course course;

  const ChatScreen({super.key, required this.course});

  @override
  State<ChatScreen> createState() => _ChatScreenState();
}

class _ChatScreenState extends State<ChatScreen> {
  final _scrollCtrl = ScrollController();
  final _inputCtrl = TextEditingController();
  final _focusNode = FocusNode();

  // Placeholder static messages — will be replaced with live data in Week 7.
  static const _placeholderMessages = [
    _ChatMessage(
      text:
          "Hi there! I've been feeling really down lately and my roommate suggested I reach out.",
      isPatient: true,
      timestamp: '9:04 AM',
    ),
    _ChatMessage(
      text:
          "I'm sorry to hear that. Can you tell me a bit more about what's been going on?",
      isPatient: false,
      timestamp: '9:06 AM',
    ),
    _ChatMessage(
      text:
          "I haven't been sleeping well, I've lost interest in things I used to enjoy, and I just feel exhausted all the time.",
      isPatient: true,
      timestamp: '9:08 AM',
    ),
    _ChatMessage(
      text:
          "How long have you been experiencing these feelings?",
      isPatient: false,
      timestamp: '9:09 AM',
    ),
    _ChatMessage(
      text: "About three weeks now. Maybe a little longer.",
      isPatient: true,
      timestamp: '9:11 AM',
    ),
  ];

  @override
  void dispose() {
    _scrollCtrl.dispose();
    _inputCtrl.dispose();
    _focusNode.dispose();
    super.dispose();
  }

  @override
  Widget build(BuildContext context) {
    final colorScheme = Theme.of(context).colorScheme;

    return Scaffold(
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
              style: const TextStyle(fontSize: 12, fontWeight: FontWeight.w400),
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
      body: Column(
        children: [
          // Message list
          Expanded(
            child: ListView.builder(
              controller: _scrollCtrl,
              padding: const EdgeInsets.fromLTRB(12, 16, 12, 8),
              itemBuilder: (context, index) {
                if (index == _placeholderMessages.length) {
                  return _AwaitingIndicator();
                }
                return _BubbleTile(message: _placeholderMessages[index]);
              },
              // Only add the awaiting indicator when the last message
              // came from the student — i.e., waiting for patient to reply.
              itemCount: _placeholderMessages.isNotEmpty &&
                      !_placeholderMessages.last.isPatient
                  ? _placeholderMessages.length + 1
                  : _placeholderMessages.length,
            ),
          ),

          // Divider between messages and input
          const Divider(height: 1),

          // Input row (disabled in Week 6 — no send API yet)
          _InputBar(
            controller: _inputCtrl,
            focusNode: _focusNode,
            colorScheme: colorScheme,
          ),
        ],
      ),
    );
  }

  void _showCaseInfoSheet(BuildContext context) {
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
              Text(
                widget.course.semester!,
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
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
            const SizedBox(height: 24),
            Text(
              'Note: Full case details and send functionality will be available in a future update.',
              style: TextStyle(
                  color: Colors.grey[500],
                  fontSize: 12,
                  fontStyle: FontStyle.italic),
            ),
          ],
        ),
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Sub-widgets
// ---------------------------------------------------------------------------

class _BubbleTile extends StatelessWidget {
  final _ChatMessage message;

  const _BubbleTile({required this.message});

  @override
  Widget build(BuildContext context) {
    final isPatient = message.isPatient;
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
                      bottomLeft: Radius.circular(isPatient ? 4 : 18),
                      bottomRight: Radius.circular(isPatient ? 18 : 4),
                    ),
                  ),
                  child: Text(
                    message.text,
                    style: TextStyle(
                      color: isPatient ? Colors.black87 : Colors.white,
                      fontSize: 14,
                    ),
                  ),
                ),
                const SizedBox(height: 2),
                Text(
                  message.timestamp,
                  style:
                      TextStyle(color: Colors.grey[500], fontSize: 11),
                ),
              ],
            ),
          ),
          if (!isPatient) const SizedBox(width: 8),
        ],
      ),
    );
  }
}

class _AwaitingIndicator extends StatelessWidget {
  @override
  Widget build(BuildContext context) {
    return Padding(
      padding: const EdgeInsets.symmetric(vertical: 12),
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

class _InputBar extends StatelessWidget {
  final TextEditingController controller;
  final FocusNode focusNode;
  final ColorScheme colorScheme;

  const _InputBar({
    required this.controller,
    required this.focusNode,
    required this.colorScheme,
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
                enabled: false, // disabled until Week 7 API
                minLines: 1,
                maxLines: 4,
                decoration: InputDecoration(
                  hintText: 'Messaging opens during the window…',
                  hintStyle:
                      TextStyle(color: Colors.grey[400], fontSize: 14),
                  filled: true,
                  fillColor: Colors.grey[100],
                  contentPadding: const EdgeInsets.symmetric(
                      horizontal: 16, vertical: 10),
                  border: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide.none,
                  ),
                  enabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[300]!),
                  ),
                  disabledBorder: OutlineInputBorder(
                    borderRadius: BorderRadius.circular(24),
                    borderSide: BorderSide(color: Colors.grey[200]!),
                  ),
                ),
              ),
            ),
            const SizedBox(width: 8),
            FloatingActionButton.small(
              heroTag: 'chat_send',
              onPressed: null, // disabled until Week 7
              backgroundColor: Colors.grey[300],
              foregroundColor: Colors.grey[500],
              elevation: 0,
              child: const Icon(Icons.send),
            ),
          ],
        ),
      ),
    );
  }
}

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
// Data model (static placeholder — replaced by API in Week 7)
// ---------------------------------------------------------------------------

class _ChatMessage {
  final String text;
  final bool isPatient;
  final String timestamp;

  const _ChatMessage({
    required this.text,
    required this.isPatient,
    required this.timestamp,
  });
}
