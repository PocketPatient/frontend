import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/auth_provider.dart';

/// Week 15 Task 2 — push toggle + quiet hours. Seeds its fields from the
/// user object already loaded by AuthNotifier (GET /users/me now returns
/// push_enabled/quiet_hours_* — see backend fix accompanying this feature),
/// so this reflects whatever's actually saved, not defaults.
class NotificationSettingsScreen extends ConsumerStatefulWidget {
  const NotificationSettingsScreen({super.key});

  @override
  ConsumerState<NotificationSettingsScreen> createState() =>
      _NotificationSettingsScreenState();
}

class _NotificationSettingsScreenState
    extends ConsumerState<NotificationSettingsScreen> {
  late bool _pushEnabled;
  TimeOfDay? _quietStart;
  TimeOfDay? _quietEnd;
  bool _saving = false;
  bool _initialized = false;

  void _seedFrom(dynamic user) {
    if (_initialized || user == null) return;
    _pushEnabled = user.pushEnabled as bool;
    _quietStart = user.quietHoursStart as TimeOfDay?;
    _quietEnd = user.quietHoursEnd as TimeOfDay?;
    _initialized = true;
  }

  Future<void> _pickTime(bool isStart) async {
    final initial = (isStart ? _quietStart : _quietEnd) ?? const TimeOfDay(hour: 22, minute: 0);
    final picked = await showTimePicker(context: context, initialTime: initial);
    if (picked == null) return;
    setState(() {
      if (isStart) {
        _quietStart = picked;
      } else {
        _quietEnd = picked;
      }
    });
  }

  void _clearQuietHours() {
    setState(() {
      _quietStart = null;
      _quietEnd = null;
    });
  }

  Future<void> _save() async {
    // Backend requires both-or-neither on quiet hours.
    if ((_quietStart == null) != (_quietEnd == null)) {
      ScaffoldMessenger.of(context).showSnackBar(
        const SnackBar(content: Text('Set both a start and end time, or clear both.')),
      );
      return;
    }

    setState(() => _saving = true);
    try {
      await ref.read(authNotifierProvider.notifier).updateNotificationPreferences(
            pushEnabled: _pushEnabled,
            quietHoursStart: _quietStart,
            quietHoursEnd: _quietEnd,
            clearQuietHours: _quietStart == null,
          );
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Preferences saved.')),
        );
      }
    } catch (_) {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(
          const SnackBar(content: Text('Could not save preferences. Try again.')),
        );
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  String _fmt(TimeOfDay? t) {
    if (t == null) return 'Not set';
    final hour = t.hourOfPeriod == 0 ? 12 : t.hourOfPeriod;
    final minute = t.minute.toString().padLeft(2, '0');
    return '$hour:$minute ${t.period == DayPeriod.am ? 'AM' : 'PM'}';
  }

  @override
  Widget build(BuildContext context) {
    _seedFrom(ref.watch(authNotifierProvider).valueOrNull);

    return Scaffold(
      appBar: AppBar(
        title: const Text('Notifications'),
        backgroundColor: const Color(0xFFCC0033),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            elevation: 0,
            child: SwitchListTile(
              title: const Text('Push notifications'),
              subtitle: const Text(
                  'New patient messages, nudges, and case assignments.'),
              value: _pushEnabled,
              activeThumbColor: const Color(0xFFCC0033),
              onChanged: (v) => setState(() => _pushEnabled = v),
            ),
          ),
          const SizedBox(height: 16),
          Text('Quiet hours',
              style: Theme.of(context)
                  .textTheme
                  .titleSmall
                  ?.copyWith(fontWeight: FontWeight.bold)),
          const SizedBox(height: 4),
          Text(
            'Notifications during this window are held and delivered once quiet hours end.',
            style: TextStyle(color: Colors.grey[600], fontSize: 12),
          ),
          const SizedBox(height: 12),
          Card(
            margin: EdgeInsets.zero,
            shape: RoundedRectangleBorder(
              borderRadius: BorderRadius.circular(14),
              side: BorderSide(color: Colors.grey[200]!),
            ),
            elevation: 0,
            child: Column(
              children: [
                ListTile(
                  leading: const Icon(Icons.bedtime_outlined),
                  title: const Text('Starts'),
                  trailing: Text(_fmt(_quietStart)),
                  onTap: () => _pickTime(true),
                ),
                const Divider(height: 1),
                ListTile(
                  leading: const Icon(Icons.wb_sunny_outlined),
                  title: const Text('Ends'),
                  trailing: Text(_fmt(_quietEnd)),
                  onTap: () => _pickTime(false),
                ),
              ],
            ),
          ),
          if (_quietStart != null || _quietEnd != null) ...[
            const SizedBox(height: 8),
            Align(
              alignment: Alignment.centerRight,
              child: TextButton(
                onPressed: _clearQuietHours,
                child: const Text('Clear quiet hours'),
              ),
            ),
          ],
          const SizedBox(height: 24),
          SizedBox(
            width: double.infinity,
            height: 46,
            child: ElevatedButton(
              onPressed: _saving ? null : _save,
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC0033),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(borderRadius: BorderRadius.circular(14)),
              ),
              child: _saving
                  ? const SizedBox(
                      width: 20, height: 20,
                      child: CircularProgressIndicator(strokeWidth: 2, color: Colors.white))
                  : const Text('Save'),
            ),
          ),
        ],
      ),
    );
  }
}
