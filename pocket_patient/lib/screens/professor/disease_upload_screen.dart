import 'package:dio/dio.dart';
import 'package:file_picker/file_picker.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../../models/course.dart';
import '../../models/disease_document_preview.dart';
import '../../providers/auth_provider.dart';

class DiseaseUploadScreen extends ConsumerStatefulWidget {
  final Course course;

  const DiseaseUploadScreen({super.key, required this.course});

  @override
  ConsumerState<DiseaseUploadScreen> createState() =>
      _DiseaseUploadScreenState();
}

class _DiseaseUploadScreenState extends ConsumerState<DiseaseUploadScreen> {
  // ── State ──────────────────────────────────────────────────────────────────
  PlatformFile? _pickedFile;
  bool _uploading = false;
  bool _confirming = false;
  DiseaseDocumentPreview? _preview;

  // ── Actions ────────────────────────────────────────────────────────────────

  Future<void> _pickFile() async {
    final result = await FilePicker.platform.pickFiles(
      type: FileType.custom,
      allowedExtensions: ['json', 'csv'],
      withData: true, // load bytes into memory (required for multipart upload)
    );
    if (result == null || result.files.isEmpty) return;
    setState(() {
      _pickedFile = result.files.first;
      _preview = null; // reset preview if they pick a new file
    });
  }

  Future<void> _upload() async {
    final file = _pickedFile;
    if (file == null || file.bytes == null) return;

    setState(() => _uploading = true);
    try {
      final preview = await ref.read(apiServiceProvider).uploadDiseaseDocument(
            widget.course.id,
            file.bytes!,
            file.name,
          );
      setState(() => _preview = preview);
    } on DioException catch (e) {
      _showError(_extractError(e));
    } catch (e) {
      _showError('Upload failed. Please try again.');
    } finally {
      setState(() => _uploading = false);
    }
  }

  Future<void> _confirm() async {
    setState(() => _confirming = true);
    try {
      final result = await ref
          .read(apiServiceProvider)
          .confirmDiseaseDocument(widget.course.id);
      if (!mounted) return;
      // Success dialog
      await showDialog<void>(
        context: context,
        barrierDismissible: false,
        builder: (_) => AlertDialog(
          title: const Text('Import complete'),
          content: Text(
            '${result.unitsCreated} unit${result.unitsCreated == 1 ? '' : 's'} '
            'and ${result.diseasesCreated} disease${result.diseasesCreated == 1 ? '' : 's'} '
            'imported successfully.',
          ),
          actions: [
            FilledButton(
              onPressed: () {
                Navigator.of(context).pop();
                Navigator.of(context).pop(); // back to course management
              },
              child: const Text('Done'),
            ),
          ],
        ),
      );
    } on DioException catch (e) {
      _showError(_extractError(e));
    } catch (e) {
      _showError('Confirm failed. Please try again.');
    } finally {
      if (mounted) setState(() => _confirming = false);
    }
  }

  void _showError(String message) {
    if (!mounted) return;
    ScaffoldMessenger.of(context)
        .showSnackBar(SnackBar(content: Text(message)));
  }

  String _extractError(DioException e) {
    final data = e.response?.data;
    if (data is Map) {
      final detail = data['detail'];
      if (detail is String) return detail;
      if (detail is Map) return detail['message'] as String? ?? 'Upload error';
    }
    return 'Upload error (${e.response?.statusCode ?? 'network'})';
  }

  // ── Build ──────────────────────────────────────────────────────────────────

  @override
  Widget build(BuildContext context) {
    return Scaffold(
      appBar: AppBar(
        title: Text(_preview == null
            ? 'Upload Disease Document'
            : 'Preview Import'),
        backgroundColor: const Color(0xFFCC0033),
        foregroundColor: Colors.white,
      ),
      body: _preview == null ? _buildUploadView() : _buildPreviewView(),
    );
  }

  // ── Phase 1: file picker + upload ──────────────────────────────────────────

  Widget _buildUploadView() {
    return Padding(
      padding: const EdgeInsets.all(24),
      child: Column(
        crossAxisAlignment: CrossAxisAlignment.stretch,
        children: [
          // Instructions
          Card(
            elevation: 0,
            color: Theme.of(context).colorScheme.surfaceContainerHighest,
            shape:
                RoundedRectangleBorder(borderRadius: BorderRadius.circular(12)),
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Row(
                    children: [
                      const Icon(Icons.info_outline, size: 18),
                      const SizedBox(width: 8),
                      Text('Supported formats',
                          style: Theme.of(context)
                              .textTheme
                              .titleSmall
                              ?.copyWith(fontWeight: FontWeight.bold)),
                    ],
                  ),
                  const SizedBox(height: 8),
                  const Text(
                    '• JSON — structured units/diseases object\n'
                    '• CSV — one row per disease with unit_label column',
                    style: TextStyle(fontSize: 13),
                  ),
                ],
              ),
            ),
          ),

          const SizedBox(height: 24),

          // File picker button
          OutlinedButton.icon(
            onPressed: _uploading ? null : _pickFile,
            icon: const Icon(Icons.folder_open_outlined),
            label: Text(_pickedFile == null
                ? 'Select file…'
                : _pickedFile!.name),
            style: OutlinedButton.styleFrom(
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),

          if (_pickedFile != null) ...[
            const SizedBox(height: 8),
            Text(
              '${(_pickedFile!.size / 1024).toStringAsFixed(1)} KB',
              textAlign: TextAlign.center,
              style: TextStyle(color: Colors.grey[500], fontSize: 12),
            ),
          ],

          const SizedBox(height: 24),

          // Upload button
          FilledButton.icon(
            onPressed:
                (_pickedFile == null || _uploading) ? null : _upload,
            icon: _uploading
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(
                        strokeWidth: 2, color: Colors.white))
                : const Icon(Icons.upload_outlined),
            label: Text(_uploading ? 'Uploading…' : 'Upload & Preview'),
            style: FilledButton.styleFrom(
              backgroundColor: const Color(0xFFCC0033),
              padding: const EdgeInsets.symmetric(vertical: 16),
            ),
          ),
        ],
      ),
    );
  }

  // ── Phase 2: parsed preview + confirm ─────────────────────────────────────

  Widget _buildPreviewView() {
    final preview = _preview!;
    final hasErrors = preview.errors.isNotEmpty;

    return Column(
      children: [
        Expanded(
          child: ListView(
            padding: const EdgeInsets.all(16),
            children: [
              // Error callouts
              if (hasErrors) ...[
                Card(
                  elevation: 0,
                  color: Colors.red[50],
                  shape: RoundedRectangleBorder(
                    borderRadius: BorderRadius.circular(12),
                    side: BorderSide(color: Colors.red[200]!),
                  ),
                  child: Padding(
                    padding: const EdgeInsets.all(12),
                    child: Column(
                      crossAxisAlignment: CrossAxisAlignment.start,
                      children: [
                        Row(
                          children: [
                            Icon(Icons.warning_amber_outlined,
                                color: Colors.red[700], size: 18),
                            const SizedBox(width: 8),
                            Text(
                              '${preview.errors.length} parse error${preview.errors.length == 1 ? '' : 's'}',
                              style: TextStyle(
                                  color: Colors.red[700],
                                  fontWeight: FontWeight.bold),
                            ),
                          ],
                        ),
                        const SizedBox(height: 8),
                        ...preview.errors.map(
                          (e) => Padding(
                            padding: const EdgeInsets.only(top: 4),
                            child: Text(
                              '${e.location}: ${e.message}',
                              style: TextStyle(
                                  color: Colors.red[800], fontSize: 12),
                            ),
                          ),
                        ),
                      ],
                    ),
                  ),
                ),
                const SizedBox(height: 12),
              ],

              // Summary chip
              Row(
                children: [
                  _SummaryChip(
                      label:
                          '${preview.units.length} unit${preview.units.length == 1 ? '' : 's'}'),
                  const SizedBox(width: 8),
                  _SummaryChip(
                      label:
                          '${preview.units.fold(0, (s, u) => s + u.diseaseCount)} disease${preview.units.fold(0, (s, u) => s + u.diseaseCount) == 1 ? '' : 's'}'),
                  const SizedBox(width: 8),
                  _SummaryChip(label: 'v${preview.version}'),
                ],
              ),
              const SizedBox(height: 12),

              // Unit cards
              ...preview.units.map((unit) => _UnitPreviewCard(unit: unit)),
            ],
          ),
        ),

        // Bottom action bar
        SafeArea(
          child: Padding(
            padding: const EdgeInsets.fromLTRB(16, 0, 16, 16),
            child: Row(
              children: [
                Expanded(
                  child: OutlinedButton(
                    onPressed: _confirming
                        ? null
                        : () => setState(() => _preview = null),
                    child: const Text('Back'),
                  ),
                ),
                const SizedBox(width: 12),
                Expanded(
                  flex: 2,
                  child: FilledButton.icon(
                    onPressed:
                        (hasErrors || _confirming) ? null : _confirm,
                    icon: _confirming
                        ? const SizedBox(
                            width: 18,
                            height: 18,
                            child: CircularProgressIndicator(
                                strokeWidth: 2, color: Colors.white))
                        : const Icon(Icons.check_circle_outline),
                    label: Text(
                        _confirming ? 'Importing…' : 'Confirm & Import'),
                    style: FilledButton.styleFrom(
                      backgroundColor: const Color(0xFFCC0033),
                      padding: const EdgeInsets.symmetric(vertical: 14),
                    ),
                  ),
                ),
              ],
            ),
          ),
        ),
      ],
    );
  }
}

// ────────────────────────────────────────────────────────────────────────────
// Helpers
// ────────────────────────────────────────────────────────────────────────────

class _SummaryChip extends StatelessWidget {
  final String label;

  const _SummaryChip({required this.label});

  @override
  Widget build(BuildContext context) {
    return Container(
      padding: const EdgeInsets.symmetric(horizontal: 10, vertical: 4),
      decoration: BoxDecoration(
        color: const Color(0xFFCC0033).withValues(alpha: 0.1),
        borderRadius: BorderRadius.circular(20),
      ),
      child: Text(label,
          style: const TextStyle(
              fontSize: 12,
              color: Color(0xFFCC0033),
              fontWeight: FontWeight.w600)),
    );
  }
}

class _UnitPreviewCard extends StatefulWidget {
  final UnitPreview unit;

  const _UnitPreviewCard({required this.unit});

  @override
  State<_UnitPreviewCard> createState() => _UnitPreviewCardState();
}

class _UnitPreviewCardState extends State<_UnitPreviewCard> {
  bool _expanded = false;

  @override
  Widget build(BuildContext context) {
    return Card(
      elevation: 0,
      margin: const EdgeInsets.only(bottom: 10),
      shape: RoundedRectangleBorder(
        borderRadius: BorderRadius.circular(12),
        side: BorderSide(
            color: Theme.of(context).colorScheme.outlineVariant),
      ),
      child: Column(
        children: [
          ListTile(
            title: Text(widget.unit.label,
                style: const TextStyle(fontWeight: FontWeight.w600)),
            subtitle: Text(
                '${widget.unit.diseaseCount} disease${widget.unit.diseaseCount == 1 ? '' : 's'}'),
            trailing: IconButton(
              icon: Icon(
                  _expanded ? Icons.expand_less : Icons.expand_more),
              onPressed: () =>
                  setState(() => _expanded = !_expanded),
            ),
            onTap: () => setState(() => _expanded = !_expanded),
          ),
          if (_expanded) ...[
            const Divider(height: 1),
            Padding(
              padding: const EdgeInsets.fromLTRB(16, 8, 16, 12),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: widget.unit.diseases
                    .map(
                      (d) => Padding(
                        padding: const EdgeInsets.symmetric(vertical: 3),
                        child: Row(
                          children: [
                            Icon(Icons.circle,
                                size: 6, color: Colors.grey[400]),
                            const SizedBox(width: 8),
                            Expanded(
                                child: Text(d,
                                    style:
                                        const TextStyle(fontSize: 13))),
                          ],
                        ),
                      ),
                    )
                    .toList(),
              ),
            ),
          ],
        ],
      ),
    );
  }
}
