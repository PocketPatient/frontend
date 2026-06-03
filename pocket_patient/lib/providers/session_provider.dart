import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_session.dart';
import 'auth_provider.dart';

/// Keyed by courseId. Holds the student's active session for that course,
/// or null if no active session exists.
final sessionProvider =
    AsyncNotifierProvider.family<SessionNotifier, ChatSession?, String>(
  SessionNotifier.new,
);

class SessionNotifier extends FamilyAsyncNotifier<ChatSession?, String> {
  String get _courseId => arg;

  @override
  Future<ChatSession?> build(String arg) async {
    try {
      return await ref.read(apiServiceProvider).getActiveSession(arg);
    } on DioException catch (e) {
      if (e.response?.statusCode == 404) return null;
      rethrow;
    }
  }

  /// Creates a new session for this course and updates state.
  Future<void> startNewSession() async {
    state = const AsyncLoading();
    state = await AsyncValue.guard(
      () => ref.read(apiServiceProvider).createSession(_courseId),
    );
  }

  /// Sends [content] and appends both the student message (constructed
  /// locally) and the patient reply (from API) to the session.
  /// Throws on API error so the caller can show a retry UI.
  Future<ChatMessage> sendMessage(String content) async {
    final session = state.valueOrNull;
    if (session == null) throw StateError('No active session');

    final patientReply =
        await ref.read(apiServiceProvider).sendMessage(session.id, content);

    // Build a local copy of the student's message so we don't need a
    // second network call to fetch the full session again.
    final studentMsg = ChatMessage(
      id: 'local_${DateTime.now().millisecondsSinceEpoch}',
      role: MessageRole.student,
      content: content,
      sentAt: DateTime.now(),
    );

    final updated = session.copyWith(
      messages: [...session.messages, studentMsg, patientReply],
      turnCount: session.turnCount + 1,
    );
    state = AsyncData(updated);
    return patientReply;
  }
}
