// Offline Banner Widget
// Compact animated banner that appears when the device is offline.
// Automatically hides when connectivity is restored.

import 'package:flutter/material.dart';
import 'package:provider/provider.dart';
import '../../constants/app_colors.dart';
import '../../services/connectivity_service.dart';

/// A slim banner that slides in from the top when offline.
///
/// Usage: Place it inside a Column at the top, or use [OfflineAwareScaffold].
///
/// ```dart
/// Column(
///   children: [
///     const OfflineBanner(),
///     Expanded(child: content),
///   ],
/// )
/// ```
class OfflineBanner extends StatelessWidget {
  /// Optional custom message. Defaults to "You are offline".
  final String? message;

  /// If true, show a "Retry" button.
  final VoidCallback? onRetry;

  const OfflineBanner({super.key, this.message, this.onRetry});

  @override
  Widget build(BuildContext context) {
    final connectivity = context.watch<ConnectivityService>();

    return AnimatedSlide(
      duration: const Duration(milliseconds: 300),
      curve: Curves.easeInOut,
      offset: connectivity.isOnline ? const Offset(0, -1) : Offset.zero,
      child: AnimatedSize(
        duration: const Duration(milliseconds: 300),
        child: connectivity.isOnline
            ? const SizedBox.shrink()
            : _buildBanner(context),
      ),
    );
  }

  Widget _buildBanner(BuildContext context) {
    return Container(
      width: double.infinity,
      padding: const EdgeInsets.symmetric(horizontal: 12, vertical: 6),
      decoration: BoxDecoration(
        color: AppColors.warning.withValues(alpha: 0.92),
        boxShadow: [
          BoxShadow(
            color: Colors.black.withValues(alpha: 0.1),
            blurRadius: 4,
            offset: const Offset(0, 2),
          ),
        ],
      ),
      child: SafeArea(
        bottom: false,
        child: Row(
          mainAxisSize: MainAxisSize.min,
          children: [
            const Icon(
              Icons.wifi_off_rounded,
              size: 16,
              color: AppColors.textPrimary,
            ),
            const SizedBox(width: 8),
            Expanded(
              child: Text(
                message ??
                    'You\'re offline — Connect to internet for full access',
                style: const TextStyle(
                  color: AppColors.textPrimary,
                  fontSize: 12,
                  fontWeight: FontWeight.w500,
                  letterSpacing: 0.2,
                ),
              ),
            ),
            if (onRetry != null)
              GestureDetector(
                onTap: onRetry,
                child: const Padding(
                  padding: EdgeInsets.symmetric(horizontal: 8, vertical: 4),
                  child: Text(
                    'Retry',
                    style: TextStyle(
                      color: AppColors.darkBlue,
                      fontSize: 13,
                      fontWeight: FontWeight.w600,
                    ),
                  ),
                ),
              ),
          ],
        ),
      ),
    );
  }
}

/// Convenience wrapper: a Scaffold body with an offline banner on top.
///
/// ```dart
/// OfflineAwareBody(
///   child: ListView(...),
/// )
/// ```
class OfflineAwareBody extends StatelessWidget {
  final Widget child;
  final String? offlineMessage;

  const OfflineAwareBody({super.key, required this.child, this.offlineMessage});

  @override
  Widget build(BuildContext context) {
    return Column(
      children: [
        OfflineBanner(message: offlineMessage),
        Expanded(child: child),
      ],
    );
  }
}
