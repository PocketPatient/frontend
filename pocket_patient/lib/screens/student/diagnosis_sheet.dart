import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/diagnosis_result.dart';
import '../../providers/session_provider.dart';

/// Shows the diagnosis submission bottom sheet.
/// Returns the [DiagnosisResult] if a valid submission was made, or null
/// if the user dismissed without submitting.
Future<DiagnosisResult?> showDiagnosisSheet(
  BuildContext context,
  WidgetRef ref,
  String courseId,
) {
  return showModalBottomSheet<DiagnosisResult?>(
    context: context,
    isScrollControlled: true,
    useSafeArea: true,
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

  static const int _justificationMin = 50;
  static const int _justificationMax = 2000;
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
      if (mounted) {
        Navigator.of(context).pop(result);
      }
    } on DioException catch (e) {
      final detail = _extractDetail(e);
      setState(() {
        _errorText = detail ?? 'Submission failed. Please try again.';
        _submitting = false;
      });
    } catch (e) {
      setState(() {
        _errorText = 'An unexpected error occurred.';
        _submitting = false;
      });
    }
  }

  String? _extractDetail(DioException e) {
    try {
      final data = e.response?.data;
      if (data is Map) {
        final detail = data['detail'];
        if (detail is String) return detail;
        if (detail is List && detail.isNotEmpty) {
          final first = detail.first;
          if (first is Map) return first['msg']?.toString();
        }
      }
    } catch (_) {}
    return null;
  }

  @override
  Widget build(BuildContext context) {
    final justLen = _justificationCtrl.text.length;
    final justOk = justLen >= _justificationMin;

    return Padding(
      padding: EdgeInsets.only(
        left: 24,
        right: 24,
        top: 20,
        bottom: MediaQuery.of(context).viewInsets.bottom + 24,
      ),
      child: Form(
        key: _formKey,
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
                controller: _primaryCtrl,
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
                      controller: _differentialCtrl,
                      textCapitalization: TextCapitalization.sentences,
                      enabled: _differentials.length < _maxDifferentials,
                      decoration: _fieldDecoration(
                        hint: _differentials.length < _maxDifferentials
                            ? 'e.g. Bipolar II Disorder'
                            : 'Maximum reached',
                      ),
                      onSubmitted: (_) => _addDifferential(),
                    ),
                  ),
                  const SizedBox(width: 8),
                  IconButton.filled(
                    onPressed: _differentials.length < _maxDifferentials
                        ? _addDifferential
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
              if (_differentials.isNotEmpty) ...[
                const SizedBox(height: 8),
                Wrap(
                  spacing: 6,
                  runSpacing: 4,
                  children: _differentials
                      .map((d) => Chip(
                            label: Text(d,
                                style: const TextStyle(fontSize: 13)),
                            deleteIcon:
                                const Icon(Icons.close, size: 16),
                            onDeleted: () => _removeDifferential(d),
                            backgroundColor:
                                const Color(0xFFCC0033).withValues(alpha: 0.08),
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
                      color: justOk ? Colors.green[600] : Colors.grey[500],
                    ),
                  ),
                ],
              ),
              const SizedBox(height: 4),
              Text(
                'Min $_justificationMin characters — describe your reasoning.',
                style: TextStyle(fontSize: 12, color: Colors.grey[500]),
              ),
              const SizedBox(height: 6),
              TextFormField(
                controller: _justificationCtrl,
                maxLines: 5,
                maxLength: _justificationMax,
                textCapitalization: TextCapitalization.sentences,
                decoration: _fieldDecoration(
                  hint:
                      'Describe the symptoms, timeline, and reasoning that led to your diagnosis…',
                  counter: const SizedBox.shrink(),
                ),
                onChanged: (_) => setState(() {}),
                validator: (v) {
                  if (v == null || v.trim().length < _justificationMin) {
                    return 'Justification must be at least $_justificationMin characters';
                  }
                  return null;
                },
              ),

              // Error banner
              if (_errorText != null) ...[
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
                          _errorText!,
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
                  onPressed: _submitting ? null : _submit,
                  style: ElevatedButton.styleFrom(
                    backgroundColor: const Color(0xFFCC0033),
                    foregroundColor: Colors.white,
                    disabledBackgroundColor: Colors.grey[300],
                    shape: RoundedRectangleBorder(
                        borderRadius: BorderRadius.circular(14)),
                  ),
                  child: _submitting
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
                              fontSize: 15, fontWeight: FontWeight.w600),
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
