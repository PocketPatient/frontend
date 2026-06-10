import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/diagnosis_result.dart';
import '../../providers/session_provider.dart';

/// Shows the diagnosis submission bottom sheet.
/// Returns a [DiagnosisResult] only when the user explicitly dismisses after
/// seeing the result (correct OR incorrect).  Returns null if the sheet was
/// closed without a submission, or if the session was stale (404).
Future<DiagnosisResult?> showDiagnosisSheet(
  BuildContext context,
  WidgetRef ref,
  String courseId,
) {
  return showModalBottomSheet<DiagnosisResult?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
    isDismissible: true,
    shape: const RoundedRectangleBorder(
      borderRadius: BorderRadius.vertical(top: Radius.circular(24)),
    ),
    builder: (ctx) => _DiagnosisSheet(courseId: courseId),
  );
}

// ---------------------------------------------------------------------------

class _DiagnosisSheet extends ConsumerStatefulWidget {
  final String courseId;

  const _DiagnosisSheet({required this.courseId});

  @override
  ConsumerState<_DiagnosisSheet> createState() => _DiagnosisSheetState();
}

class _DiagnosisSheetState extends ConsumerState<_DiagnosisSheet> {
  final _formKey = GlobalKey<FormState>();
  final _primaryCtrl = TextEditingController();
  final _differentialCtrl = TextEditingController();
  final _justificationCtrl = TextEditingController();

  final List<String> _differentials = [];
  bool _submitting = false;
  String? _errorText;

  /// Set when the API returns correct=false — switches the sheet to the
  /// feedback view instead of the form.
  DiagnosisResult? _incorrectResult;

  static const int _maxDifferentials = 3;

  @override
  void dispose() {
    _primaryCtrl.dispose();
    _differentialCtrl.dispose();
    _justificationCtrl.dispose();
    super.dispose();
  }

  void _addDifferential() {
    final text = _differentialCtrl.text.trim();
    if (text.isEmpty) return;
    if (_differentials.length >= _maxDifferentials) return;
    if (_differentials.contains(text)) return;
    setState(() {
      _differentials.add(text);
      _differentialCtrl.clear();
    });
  }

  void _removeDifferential(String item) {
    setState(() => _differentials.remove(item));
  }

  Future<void> _submit() async {
    if (!_formKey.currentState!.validate()) return;

    setState(() {
      _submitting = true;
      _errorText = null;
    });

    try {
      final result = await ref
          .read(sessionProvider(widget.courseId).notifier)
          .submitDiagnosis(
            _primaryCtrl.text.trim(),
            List.unmodifiable(_differentials),
            _justificationCtrl.text.trim(),
          );

      if (!mounted) return;

      if (result.correct) {
        // Correct — pop immediately so caller can navigate to result screen.
        Navigator.of(context).pop(result);
      } else {
        // Incorrect — stay open and show feedback inline.
        setState(() {
          _incorrectResult = result;
          _submitting = false;
        });
      }
    } on DioException catch (e) {
      if (!mounted) return;
      final status = e.response?.statusCode;
      if (status == 404) {
        // Stale session — reset provider and dismiss silently.
        ref.invalidate(sessionProvider(widget.courseId));
        Navigator.of(context).pop(null);
        return;
      }
      final detail = _extractDetail(e);
      setState(() {
        _errorText = detail ?? 'Submission failed. Please try again.';
        _submitting = false;
      });
    } catch (_) {
      if (!mounted) return;
      setState(() {
        _errorText = 'An unexpected error occurred.';
        _submitting = false;
      });
    }
  }

  String? _extractDetail(DioException e) {
    final status = e.response?.statusCode;
    try {
      final data = e.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is String && detail.isNotEmpty) {
          if (detail == 'Not Found' || detail == 'Session not found') {
            return null;
          }
          return detail;
        }
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map) return first['msg']?.toString();
        }
      }
    } catch (_) {}
    if (status == 409) return 'This case is no longer active.';
    if (status == 422) return 'Please check your inputs and try again.';
    return null;
  }

  @override
  Widget build(BuildContext context) {
    // If we have an incorrect result, show the feedback view instead.
    if (_incorrectResult != null) {
      return _IncorrectFeedbackView(
        result: _incorrectResult!,
        onContinue: () => Navigator.of(context).pop(_incorrectResult),
      );
    }

    return _FormView(
      formKey: _formKey,
      primaryCtrl: _primaryCtrl,
      differentialCtrl: _differentialCtrl,
      justificationCtrl: _justificationCtrl,
      differentials: _differentials,
      submitting: _submitting,
      errorText: _errorText,
      onAddDifferential: _addDifferential,
      onRemoveDifferential: _removeDifferential,
      onJustificationChanged: () => setState(() {}),
      onSubmit: _submit,
    );
  }
}

// ---------------------------------------------------------------------------
// Incorrect feedback view — replaces the form when diagnosis is wrong
// ---------------------------------------------------------------------------

class _IncorrectFeedbackView extends StatelessWidget {
  final DiagnosisResult result;
  final VoidCallback onContinue;

  const _IncorrectFeedbackView({
    required this.result,
    required this.onContinue,
  });

  @override
  Widget build(BuildContext context) {
    final hint = result.hint;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 32,
      ),
      child: Column(
        mainAxisSize: MainAxisSize.min,
        children: [
          // Handle bar
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
          const SizedBox(height: 28),

          // X icon
          Container(
            width: 72,
            height: 72,
            decoration: BoxDecoration(
              color: Colors.orange[50],
              shape: BoxShape.circle,
              border: Border.all(color: Colors.orange[200]!, width: 2),
            ),
            child: Icon(Icons.close_rounded, size: 40, color: Colors.orange[700]),
          ),
          const SizedBox(height: 16),

          Text(
            'Incorrect Diagnosis',
            style: Theme.of(context).textTheme.titleLarge?.copyWith(
                  fontWeight: FontWeight.bold,
                  color: Colors.orange[800],
                ),
          ),
          const SizedBox(height: 8),
          Text(
            'Keep interviewing the patient and try again.',
            textAlign: TextAlign.center,
            style: TextStyle(color: Colors.grey[600], fontSize: 14),
          ),

          if (hint != null && hint.isNotEmpty) ...[
            const SizedBox(height: 20),
            Container(
              width: double.infinity,
              padding: const EdgeInsets.all(16),
              decoration: BoxDecoration(
                color: Colors.orange[50],
                borderRadius: BorderRadius.circular(14),
                border: Border.all(color: Colors.orange[200]!),
              ),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      Icon(Icons.lightbulb_outline,
                          size: 16, color: Colors.orange[700]),
                      const SizedBox(width: 6),
                      Text(
                        'Hint',
                        style: TextStyle(
                          fontWeight: FontWeight.bold,
                          fontSize: 13,
                          color: Colors.orange[800],
                        ),
                      ),
                    ],
                  ),
                  const SizedBox(height: 8),
                  Text(
                    hint,
                    style: TextStyle(
                      fontSize: 14,
                      color: Colors.orange[900],
                      height: 1.45,
                    ),
                  ),
                ],
              ),
            ),
          ],

          const SizedBox(height: 24),

          SizedBox(
            width: double.infinity,
            height: 50,
            child: ElevatedButton.icon(
              onPressed: onContinue,
              icon: const Icon(Icons.chat_bubble_outline, size: 18),
              label: const Text(
                'Continue Interviewing',
                style: TextStyle(fontSize: 15, fontWeight: FontWeight.w600),
              ),
              style: ElevatedButton.styleFrom(
                backgroundColor: const Color(0xFFCC0033),
                foregroundColor: Colors.white,
                shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(14)),
              ),
            ),
          ),
        ],
      ),
    );
  }
}

// ---------------------------------------------------------------------------
// Form view — the normal submission UI
// ---------------------------------------------------------------------------

class _FormView extends StatelessWidget {
  final GlobalKey<FormState> formKey;
  final TextEditingController primaryCtrl;
  final TextEditingController differentialCtrl;
  final TextEditingController justificationCtrl;
  final List<String> differentials;
  final bool submitting;
  final String? errorText;
  final VoidCallback onAddDifferential;
  final void Function(String) onRemoveDifferential;
  final VoidCallback onJustificationChanged;
  final VoidCallback onSubmit;

  static const int _justificationMin = 50;
  static const int _justificationMax = 2000;
  static const int _maxDifferentials = 3;

  const _FormView({
    required this.formKey,
    required this.primaryCtrl,
    required this.differentialCtrl,
    required this.justificationCtrl,
    required this.differentials,
    required this.submitting,
    required this.errorText,
    required this.onAddDifferential,
    required this.onRemoveDifferential,
    required this.onJustificationChanged,
    required this.onSubmit,
  });

  @override
  Widget build(BuildContext context) {
    final justLen = justificationCtrl.text.length;
    final justOk = justLen >= _justificationMin;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: formKey,
        child: SingleChildScrollView(
          child: Column(
            mainAxisSize: MainAxisSize.min,
            crossAxisAlignment: CrossAxisAlignment.start,
            children: [
              // Handle bar
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
              const SizedBox(height: 16),

              // Title
              Row(
                children: [
                  const Icon(Icons.local_hospital_outlined,
                      color: Color(0xFFCC0033), size: 22),
                  const SizedBox(width: 8),
                  Text(
                    'Submit Diagnosis',
                    style: Theme.of(context)
                        .textTheme
                        .titleLarge
                        ?.copyWith(fontWeight: FontWeight.bold),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'You must correctly identify the diagnosis to complete this case.',
                style: TextStyle(color: Colors.grey[600], fontSize: 13),
              ),
              const SizedBox(height: 20),

              // Primary diagnosis
              Text('Primary Diagnosis *',
                  style: TextStyle(
                      fontWeight: FontWeight.w600,
                      fontSize: 13,
                      color: Colors.grey[800])),
              const SizedBox(height: 6),
              TextFormField(
                controller: primaryCtrl,
                textCapitalization: TextCapitalization.sentences,
                maxLength: 255,
                decoration: _fieldDecoration(
                  hint: 'e.g. Major Depressive Disorder',
                ),
                validator: (v) {
                  if (v == null || v.trim().isEmpty) {
                    return 'Primary diagnosis is required';
                  }
                  return null;
                },
              ),
              const SizedBox(height: 16),

              // Differentials
              Text(
                'Differential Diagnoses (up to $_maxDifferentials)',
                style: TextStyle(
                    fontWeight: FontWeight.w600,
                    fontSize: 13,
                    color: Colors.grey[800]),
              ),
              const SizedBox(height: 6),
              Row(
                children: [
                  Expanded(
                    child: TextField(
                      controller: differentialCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: differentials.length < _maxDifferentials,
                      decoration: _fieldDecoration(
                        hint: differentials.length < _maxDifferentials
                            ? 'e.g. Bipolar II Disorder'
                            : 'Maximum reached',
                      ),
                      onSubmitted: (_) => onAddDifferential(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: differentials.length < _maxDifferentials
                        ? onAddDifferential
                        : null,
                    icon: const Icon(Icons.add),
                    style: IconButton.styleFrom(
                      backgroundColor: const Color(0xFFCC0033),
                      foregroundColor: Colors.white,
                      disabledBackgroundColor: Colors.grey[300],
                      disabledForegroundColor: Colors.grey[500],
                    ),
                  ),
                ],
              ),
              if (differentials.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: differentials
                      .map((d) => Chip(
                            label: Text(d,
                                style: const TextStyle(fontSize: 13)),
                            deleteIcon:
                                const Icon(Icons.close, size: 16),
                            onDeleted: () => onRemoveDifferential(d),
                            backgroundColor: const Color(0xFFCC0033)
                                .withValues(alpha: 0.08),
                            side: const BorderSide(
                                color: Color(0xFFCC0033), width: 0.8),
                            labelStyle: const TextStyle(
                                color: Color(0xFFCC0033)),
                            deleteIconColor: const Color(0xFFCC0033),
                            visualDensity: VisualDensity.compact,
                          ))
                      .toList(),
                ),
              ],
              const SizedBox(height: 16),

              // Justification
              Row(
                children: [
                  Text('Clinical Justification *',
                      style: TextStyle(
                          fontWeight: FontWeight.w600,
                          fontSize: 13,
                          color: Colors.grey[800])),
                  const Spacer(),
                  Text(
                    '$justLen / $_justificationMax',
                    style: TextStyle(
                      fontSize: 11,
                      color:
                          justOk ? Colors.green[600] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Min $_justificationMin characters — describe your reasoning.',
                style:
                    TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: justificationCtrl,
                maxLines: 5,
                maxLength: _justificationMax,
                textCapitalization: TextCapitalization.sentences,
                decoration: _fieldDecoration(
                  hint:
                      'Describe the symptoms, timeline, and reasoning that led to your diagnosis…',
                  counter: const SizedBox.shrink(),
                ),
                onChanged: (_) => onJustificationChanged(),
                validator: (v) {
                  if (v == null ||
                      v.trim().length < _justificationMin) {
                    return 'Justification must be at least $_justificationMin characters';
                  }
                  return null;
                },
              ),

              // API error banner
              if (errorText != null) ...[
                const SizedBox(height: 12),
                Container(
                  padding: const EdgeInsets.symmetric(
                      horizontal: 14, vertical: 10),
                  decoration: BoxDecoration(
                    color: Colors.red[50],
                    borderRadius: BorderRadius.circular(10),
                    border: Border.all(color: Colors.red[200]!),
                  ),
                  child: Row(
                    children: [
                      Icon(Icons.error_outline,
                          size: 16, color: Colors.red[700]),
                      const SizedBox(width: 8),
                      Expanded(
                        child: Text(
                          errorText!,
                          style: TextStyle(
                              fontSize: 13, color: Colors.red[800]),
                        ),
                      ),
                    ],
                  ),
                ),
              ],
              const SizedBox(height: 20),

              // Submit button
              SizedBox(
                width: double.infinity,
                height: 50,
                child: ElevatedButton(
                  onPressed: submitting ? null : onSubmit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCC0033),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: submitting
                      ? const SizedBox(
                          width: 22,
                          height: 22,
                          child: CircularProgressIndicator(
                            strokeWidth: 2.5,
                            color: Colors.white,
                          ),
                        )
                      : const Text(
                          'Submit Diagnosis',
                          style: TextStyle(
                              fontSize: 15,
                              fontWeight: FontWeight.w600),
                        ),
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }

  InputDecoration _fieldDecoration({
    required String hint,
    Widget? counter,
  }) {
    return InputDecoration(
      hintText: hint,
      hintStyle: TextStyle(color: Colors.grey[400], fontSize: 14),
      filled: true,
      fillColor: Colors.grey[50],
      counterText: '',
      counter: counter,
      contentPadding:
          const EdgeInsets.symmetric(horizontal: 14, vertical: 12),
      border: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      enabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[300]!),
      ),
      focusedBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide:
            const BorderSide(color: Color(0xFFCC0033), width: 1.5),
      ),
      errorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red),
      ),
      focusedErrorBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: const BorderSide(color: Colors.red, width: 1.5),
      ),
      disabledBorder: OutlineInputBorder(
        borderRadius: BorderRadius.circular(12),
        borderSide: BorderSide(color: Colors.grey[200]!),
      ),
    );
  }
}
