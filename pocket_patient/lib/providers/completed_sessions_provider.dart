import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/chat_session.dart';
import 'auth_provider.dart';

/// Keyed by courseId.
/// Caches diagnosed session IDs in SharedPreferences and fetches full session
/// data from the API on demand. Because the backend has no list endpoint for
/// completed sessions, we track IDs locally and resolve them individually.
final completedSessionsProvider = AsyncNotifierProvider.family<
    CompletedSessionsNotifier, List<ChatSession>, String>(
  CompletedSessionsNotifier.new,
);

class CompletedSessionsNotifier
    extends FamilyAsyncNotifier<List<ChatSession>, String> {
  String get _courseId => arg;
  static const _keyPrefix = 'completed_sessions_v1_';

  String get _prefsKey => '$_keyPrefix$_courseId';

  @override
  Future<List<ChatSession>> build(String arg) => _loadFromCache();

  Future<List<ChatSession>> _loadFromCache() async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsKey) ?? [];
    if (ids.isEmpty) return const [];

    final api = ref.read(apiServiceProvider);
    final sessions = <ChatSession>[];
    for (final id in ids) {
      try {
        final session = await api.getSession(id);
        sessions.add(session);
      } catch (_) {
        // Skip sessions that can no longer be fetched (deleted, forbidden, etc.)
      }
    }
    // Sort newest-first by startedAt
    sessions.sort((a, b) => b.startedAt.compareTo(a.startedAt));
    return sessions;
  }

  /// Called after a student submits a correct diagnosis.
  /// Persists [sessionId] and refreshes the list.
  Future<void> addSession(String sessionId) async {
    final prefs = await SharedPreferences.getInstance();
    final ids = prefs.getStringList(_prefsKey) ?? [];
    if (!ids.contains(sessionId)) {
      ids.add(sessionId);
      await prefs.setStringList(_prefsKey, ids);
    }
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadFromCache);
  }

  Future<void> refresh() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(_loadFromCache);
  }
}
