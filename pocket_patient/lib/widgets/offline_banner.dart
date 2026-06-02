import 'package:flutter/material.dart';
import 'package:flutter_riverpod/flutter_riverpod.dart';
import '../providers/connectivity_provider.dart';

/// Wraps [child] with an animated "You're offline" banner at the top whenever
/// the device has no network connectivity.
class OfflineBannerScaffold extends ConsumerWidget {
  final Widget child;

  const OfflineBannerScaffold({super.key, required this.child});

  @override
  Widget build(BuildContext context, WidgetRef ref) {
    final connectivityAsync = ref.watch(connectivityProvider);

    // Default to online while loading to avoid flickering on first frame.
    final isOnline = connectivityAsync.valueOrNull ?? true;

    return Column(
      children: [
        AnimatedSwitcher(
          duration: const Duration(milliseconds: 300),
          child: isOnline
              ? const SizedBox.shrink(key: ValueKey('online'))
              : const _OfflineBanner(key: ValueKey('offline')),
        ),
        Expanded(child: child),
      ],
    );
  }
}

class _OfflineBanner extends StatelessWidget {
  const _OfflineBanner({super.key});

  @override
  Widget build(BuildContext context) {
    return Material(
      color: Colors.grey[800],
      child: const SafeArea(
        bottom: false,
        child: Padding(
          padding: EdgeInsets.symmetric(vertical: 6, horizontal: 16),
          child: Row(
            mainAxisAlignment: MainAxisAlignment.center,
            children: [
              Icon(Icons.cloud_off, size: 16, color: Colors.white70),
              SizedBox(width: 8),
              Text(
                "You're offline — showing cached data",
                style: TextStyle(
                  color: Colors.white,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                ),
              ),
            ],
          ),
        ),
      ),
    );
  }
}
