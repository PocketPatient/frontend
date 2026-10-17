import 'package:dio/dio.dart';
import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import 'package:go_router/go_router.dart';

import '../providers/auth_provider.dart';
import 'privacy_settings_screen.dart';

/// Shown once to new students right after they choose the Student role, so AI
/// consent is asked up front instead of the first time a case is started.
///
/// Consent stays optional: "Not now" continues without it, and every AI path
/// still recovers via the AI_CONSENT_REQUIRED prompt in the chat screen.
class AiConsentScreen extends ConsumerStatefulWidget {
  const AiConsentScreen({super.key});

  @override
  ConsumerState<AiConsentScreen> createState() => _AiConsentScreenState();
}

class _AiConsentScreenState extends ConsumerState<AiConsentScreen> {
  bool _saving = false;

  void _leave() {
    if (context.canPop()) {
      context.pop();
    } else {
      context.go('/home');
    }
  }

  Future<void> _agree() async {
    setState(() => _saving = true);
    try {
      await ref.read(apiServiceProvider).acceptAiConsent();
      ref.invalidate(aiConsentProvider);
      if (mounted) _leave();
    } on DioException {
      if (mounted) {
        ScaffoldMessenger.of(context).showSnackBar(const SnackBar(
          content: Text('Could not save your choice. Please try again.'),
        ));
      }
    } finally {
      if (mounted) setState(() => _saving = false);
    }
  }

  @override
  Widget build(BuildContext context) {
    final textTheme = Theme.of(context).textTheme;
    return PopScope(
      canPop: false, // choose explicitly: Agree or Not now
      child: Scaffold(
        body: SafeArea(
          child: ListView(
            padding: const EdgeInsets.symmetric(horizontal: 28, vertical: 40),
            children: [
              const Icon(Icons.smart_toy_outlined,
                  size: 48, color: Color(0xFFCC0033)),
              const SizedBox(height: 16),
              Text('AI patient responses',
                  style: textTheme.headlineSmall
                      ?.copyWith(fontWeight: FontWeight.bold)),
              const SizedBox(height: 16),
              const Text(
                'Pocket Patient uses AI to play simulated patients. To generate a '
                'patient\'s responses, the case conversation is shared with Google '
                'Gemini.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Do not include personal health information about yourself or any '
                'real person. Simulated cases are for education only and are not '
                'medical advice.',
              ),
              const SizedBox(height: 12),
              const Text(
                'Without your consent, AI patient cases stay disabled.',
              ),
              const SizedBox(height: 20),
              Container(
                padding: const EdgeInsets.all(12),
                decoration: BoxDecoration(
                  color: Colors.grey.shade100,
                  borderRadius: BorderRadius.circular(12),
                ),
                child: const Text.rich(
                  key: Key('ai-consent-change-later'),
                  TextSpan(children: [
                    TextSpan(
                        text: 'You can change this to No at any time: tap the '),
                    WidgetSpan(
                      alignment: PlaceholderAlignment.middle,
                      child: Icon(Icons.shield_outlined, size: 18),
                    ),
                    TextSpan(
                        text: ' icon at the top of the home screen, then turn off '
                            '"Allow simulated AI patient responses".'),
                  ]),
                ),
              ),
              const SizedBox(height: 28),
              FilledButton(
                style: FilledButton.styleFrom(
                  backgroundColor: const Color(0xFFCC0033),
                  padding: const EdgeInsets.symmetric(vertical: 14),
                ),
                onPressed: _saving ? null : _agree,
                child: _saving
                    ? const SizedBox(
                        width: 18,
                        height: 18,
                        child: CircularProgressIndicator(
                            strokeWidth: 2, color: Colors.white))
                    : const Text('I agree'),
              ),
              const SizedBox(height: 8),
              TextButton(
                onPressed: _saving ? null : _leave,
                child: const Text('Not now'),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
