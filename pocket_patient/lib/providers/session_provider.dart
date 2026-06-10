import 'package:dio/dio.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../models/chat_session.dart';
import '../models/diagnosis_result.dart';
import 'auth_provider.dart';

/// Keyed by courseId. Holds the student's active (or most recently diagnosed)
/// session for that course, or null if no session exists.
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

  /// Sends [content] to the backend (202 response returns the student's own
  /// message). Appends only the student message to local state — the patient
  /// reply arrives asynchronously and becomes visible after [refresh].
  Future<void> sendMessage(String content) async {
    final session = state.valueOrNull;
    if (session == null) throw StateError('No active session');

    final studentMsg =
        await ref.read(apiServiceProvider).sendMessage(session.id, content);

    // Re-read state after the await in case it changed while the request was
    // in-flight (e.g. a concurrent refresh completed).  Merge rather than
    // clobber to avoid losing any messages that arrived in the meantime.
    final latest = state.valueOrNull ?? session;
    final alreadyPresent = latest.messages.any((m) => m.id == studentMsg.id);
    final messages = alreadyPresent
        ? latest.messages
        : [...latest.messages, studentMsg];

    state = AsyncData(latest.copyWith(
      messages: messages,
      turnCount: latest.turnCount + 1,
    ));
  }

  /// Submits a diagnosis. Returns the [DiagnosisResult] from the backend.
  /// If correct, updates state to the diagnosed session. Throws on API error.
  Future<DiagnosisResult> submitDiagnosis(
    String primaryDx,
    List<String> differentials,
    String justification,
  ) async {
    final session = state.valueOrNull;
    if (session == null) throw StateError('No active session');

    final result = await ref.read(apiServiceProvider).submitDiagnosis(
          session.id,
          primaryDx,
          differentials,
          justification,
        );

    if (result.correct) {
      final updated = session.copyWith(
        status: 'diagnosed',
        score: result.score,
        reveal: result.reveal,
      );
      state = AsyncData(updated);
    }

    return result;
  }

  /// Re-fetches the session from the API (used for pull-to-refresh to pick up
  /// async patient replies and status changes).
  ///
  /// Merges server messages with any locally-confirmed messages not yet present
  /// in the server response (e.g. a student message that was just sent but
  /// hasn't propagated into the GET response yet).  This prevents confirmed
  /// messages from vanishing during the round-trip.
  Future<void> refresh() async {
    final current = state.valueOrNull;
    if (current == null) return;
    try {
      final refreshed =
          await ref.read(apiServiceProvider).getSession(current.id);

      final serverIds = {for (final m in refreshed.messages) m.id};
      final localOnly = current.messages
          .where((m) => !serverIds.contains(m.id))
          .toList();

      if (localOnly.isEmpty) {
        state = AsyncData(refreshed);
      } else {
        // Merge locally-confirmed messages back in, sorted by sentAt.
        final merged = [...localOnly, ...refreshed.messages]
          ..sort((a, b) => a.sentAt.compareTo(b.sentAt));
        state = AsyncData(refreshed.copyWith(messages: merged));
      }
    } on DioException {
      // Keep existing state on network error — user can retry.
    }
  }
}
