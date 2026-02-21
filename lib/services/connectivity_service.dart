// Connectivity Service
// Reactive connectivity monitor using connectivity_plus.
// Exposes isOnline state and a stream for UI banners.

import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';

/// Monitors network connectivity and notifies listeners on change.
///
/// Usage:
///   - Provider: `ChangeNotifierProvider(create: (_) => ConnectivityService())`
///   - Read: `context.watch<ConnectivityService>().isOnline`
///   - Dispose automatically via Provider lifecycle.
class ConnectivityService extends ChangeNotifier {
  final Connectivity _connectivity = Connectivity();
  StreamSubscription<ConnectivityResult>? _subscription;

  bool _isOnline = true; // assume online until proven otherwise
  bool _initialized = false;

  ConnectivityService() {
    _init();
  }

  // ── Public API ──

  /// Whether the device currently has a network connection.
  bool get isOnline => _isOnline;

  /// Whether the initial check has completed.
  bool get initialized => _initialized;

  // ── Initialization ──

  Future<void> _init() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateStatus(result);
      _initialized = true;
      notifyListeners();
      debugPrint(
        '[Connectivity] Initial status: ${_isOnline ? "online" : "offline"}',
      );
    } catch (e) {
      debugPrint('[Connectivity] Initial check failed: $e');
      _initialized = true;
      notifyListeners();
    }

    // Listen for changes
    _subscription = _connectivity.onConnectivityChanged.listen(
      _updateStatus,
      onError: (e) {
        debugPrint('[Connectivity] Stream error: $e');
      },
    );
  }

  /// Update status from connectivity result.
  void _updateStatus(ConnectivityResult result) {
    final wasOnline = _isOnline;
    _isOnline = result != ConnectivityResult.none;

    if (wasOnline != _isOnline) {
      debugPrint(
        '[Connectivity] Status changed: ${_isOnline ? "online" : "offline"}',
      );
      notifyListeners();
    }
  }

  /// Force a re-check (useful after user toggles WiFi).
  Future<bool> checkNow() async {
    try {
      final result = await _connectivity.checkConnectivity();
      _updateStatus(result);
      return _isOnline;
    } catch (e) {
      debugPrint('[Connectivity] Manual check failed: $e');
      return _isOnline;
    }
  }

  @override
  void dispose() {
    _subscription?.cancel();
    super.dispose();
  }
}
