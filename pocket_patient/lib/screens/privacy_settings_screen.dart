import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';

import '../models/ai_consent_status.dart';
import '../providers/auth_provider.dart';

final aiConsentProvider = FutureProvider<AiConsentStatus>((ref) async {
  return ref.read(apiServiceProvider).getAiConsent();
});

class PrivacySettingsScreen extends ConsumerStatefulWidget {
  const PrivacySettingsScreen({super.key});

  @override
  ConsumerState<PrivacySettingsScreen> createState() =>
      _PrivacySettingsScreenState();
}

class _PrivacySettingsScreenState extends ConsumerState<PrivacySettingsScreen> {
  bool _savingConsent = false;
  bool _deleting = false;

  Future<void> _setConsent(bool grant) async {
    setState(() => _savingConsent = true);
    try {
      if (grant) {
        await ref.read(apiServiceProvider).acceptAiConsent();
      } else {
        await ref.read(apiServiceProvider).revokeAiConsent();
      }
      ref.invalidate(aiConsentProvider);
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(SnackBar(
          content: Text(grant
              ? 'AI consent saved.'
              : 'AI consent withdrawn. AI patient responses are unavailable.'),
        ));
      }
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not update AI consent. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _savingConsent = false);
    }
  }

  Future<void> _confirmDeletion() async {
    final confirmed = await showDialog<bool>(
      context: context,
      builder: (context) => AlertDialog(
        title: const Text('Delete account and data?'),
        content: const Text(
          'This permanently removes your Pocket Patient account and associated '
          'application data. This action cannot be undone.',
        ),
        actions: [
          TextButton(
            onPressed: () => Navigator.pop(context, false),
            child: const Text('Cancel'),
          ),
          FilledButton(
            style: FilledButton.styleFrom(backgroundColor: Colors.red),
            onPressed: () => Navigator.pop(context, true),
            child: const Text('Delete account'),
          ),
        ],
      ),
    );
    if (confirmed != true) return;

    setState(() => _deleting = true);
    try {
      final status = await ref.read(apiServiceProvider).deleteMyAccount();
      await ref.read(authNotifierProvider.notifier).signOut();
      if (mounted && status == 202) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Your app data was deleted. Sign-in identity cleanup is retrying automatically.'),
        ));
      }
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text(
              'Account deletion could not be completed. Your account was not deleted.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _deleting = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final consent = ref.watch(aiConsentProvider);
    return Scaffold(
      appBar: AppBar(
        title: const Text('Privacy and account'),
        backgroundColor: const Color(0xFFCC0033),
        foregroundColor: Colors.white,
      ),
      body: ListView(
        padding: const EdgeInsets.all(16),
        children: [
          Card(
            child: Padding(
              padding: const EdgeInsets.all(16),
              child: Column(
                crossAxisAlignment: CrossAxisAlignment.start,
                children: [
                  Text('Educational simulation',
                      style: Theme.of(context).textTheme.titleMedium),
                  const SizedBox(height: 8),
                  const Text(
                    'Pocket Patient uses simulated cases for education. It is not '
                    'medical advice and must not be used for personal diagnosis, '
                    'treatment, or emergency decisions. Consult a qualified clinician '
                    'for medical decisions.',
                  ),
                ],
              ),
            ),
          ),
          const SizedBox(height: 16),
          Text('AI data sharing',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'With your permission, the case conversation needed to generate a '
            'simulated patient response is shared with Google Gemini. Do not include '
            'personal health information about yourself or another real person.',
          ),
          const SizedBox(height: 10),
          consent.when(
            loading: () => const Center(
                child: Padding(
                    padding: EdgeInsets.all(16),
                    child: CircularProgressIndicator())),
            error: (_, __) => Card(
              child: ListTile(
                leading: const Icon(Icons.cloud_off_outlined),
                title: const Text('AI consent is unavailable'),
                subtitle: const Text(
                    'The service must be updated before AI consent can be managed.'),
                trailing: TextButton(
                  onPressed: () => ref.invalidate(aiConsentProvider),
                  child: const Text('Retry'),
                ),
              ),
            ),
            data: (status) => SwitchListTile(
              contentPadding: EdgeInsets.zero,
              title: const Text('Allow simulated AI patient responses'),
              subtitle: Text(status.active
                  ? 'Consent recorded for version ${status.acceptedVersion ?? status.requiredVersion}.'
                  : 'AI patient responses stay disabled until you agree.'),
              value: status.active,
              activeThumbColor: const Color(0xFFCC0033),
              onChanged: _savingConsent ? null : _setConsent,
            ),
          ),
          const Divider(height: 32),
          Text('Privacy policy',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const SelectableText(
            'The published privacy policy and web account-deletion page must be linked '
            'here before store submission. This screen describes the in-app controls.',
          ),
          const Divider(height: 32),
          Text('Account deletion',
              style: Theme.of(context).textTheme.titleMedium),
          const SizedBox(height: 6),
          const Text(
            'Delete your Pocket Patient account and associated application data. '
            'Some security or backup records may be retained only as described in the privacy policy.',
          ),
          const SizedBox(height: 12),
          OutlinedButton.icon(
            onPressed: _deleting ? null : _confirmDeletion,
            icon: _deleting
                ? const SizedBox(
                    width: 18,
                    height: 18,
                    child: CircularProgressIndicator(strokeWidth: 2))
                : const Icon(Icons.delete_forever_outlined),
            style: OutlinedButton.styleFrom(foregroundColor: Colors.red),
            label: Text(
                _deleting ? 'Deleting account...' : 'Delete account and data'),
          ),
        ],
      ),
    );
  }
}
