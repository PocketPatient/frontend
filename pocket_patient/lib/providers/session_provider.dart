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

    final updated = session.copyWith(
      messages: [...session.messages, studentMsg],
      turnCount: session.turnCount + 1,
    );
    state = AsyncData(updated);
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
  Future<void> refresh() async {
    final session = state.valueOrNull;
    if (session == null) return;
    try {
      final refreshed =
          await ref.read(apiServiceProvider).getSession(session.id);
      state = AsyncData(refreshed);
    } on DioException {
      // Keep existing state on network error — user can retry.
    }
  }
}
