import 'dart:async';
import 'package:flutter/foundation.dart';
import 'package:connectivity_plus/connectivity_plus.dart';
import '../database/activity_database.dart';
import '../models/recent_activity_model.dart';
import 'recent_activity_api_service.dart';

/// Manages synchronization between local database and server
class ActivitySyncManager {
  static final ActivitySyncManager _instance = ActivitySyncManager._internal();
  factory ActivitySyncManager() => _instance;
  ActivitySyncManager._internal();

  final RecentActivityApiService _apiService = RecentActivityApiService();
  final Connectivity _connectivity = Connectivity();

  Timer? _syncTimer;
  bool _isSyncing = false;
  int _unsyncedCount = 0;

  /// Sync threshold - sync after this many unsynced activities
  static const int _syncThreshold = 5;

  /// Auto-sync interval in minutes
  static const int _syncIntervalMinutes = 30;

  /// Initialize sync manager and start auto-sync
  Future<void> initialize() async {
    // Start auto-sync timer immediately
    startAutoSync();

    // Sync on connectivity change
    _connectivity.onConnectivityChanged.listen((result) {
      if (result != ConnectivityResult.none) {
        _triggerSync();
      }
    });

    // Defer heavy operations to background
    Future.microtask(() async {
      // Cleanup old activities (non-blocking)
      await ActivityDatabase.cleanupOldActivities();

      // Update unsynced count
      _unsyncedCount = await ActivityDatabase.getUnsyncedCount();

      debugPrint('ActivitySyncManager initialized. Unsynced: $_unsyncedCount');
    });
  }

  /// Start periodic auto-sync
  void startAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = Timer.periodic(
      Duration(minutes: _syncIntervalMinutes),
      (_) => _triggerSync(),
    );
  }

  /// Stop auto-sync
  void stopAutoSync() {
    _syncTimer?.cancel();
    _syncTimer = null;
  }

  /// Track a new activity
  Future<void> track({
    required String activityType,
    required String title,
    String? subtitle,
    String? fromLocation,
    String? toLocation,
    String? routeNames,
    double? fare,
    Map<String, dynamic>? metadata,
  }) async {
    // Create activity model
    final activity = RecentActivityModel(
      activityType: activityType,
      title: title,
      subtitle: subtitle,
      fromLocation: fromLocation,
      toLocation: toLocation,
      routeNames: routeNames,
      fare: fare,
      metadata: metadata,
      createdAt: DateTime.now(),
      isSynced: false,
    );

    // Save to local database
    await ActivityDatabase.insertActivity(activity);

    // Update unsynced count
    _unsyncedCount++;

    // Check if we should trigger sync
    if (_unsyncedCount >= _syncThreshold) {
      _triggerSync();
    }

    debugPrint('Activity tracked: $title');
  }

  /// Trigger sync if conditions are met
  Future<void> _triggerSync() async {
    if (_isSyncing) return;

    // Check connectivity
    final connectivityResult = await _connectivity.checkConnectivity();
    if (connectivityResult == ConnectivityResult.none) {
      debugPrint('No internet connection, skipping sync');
      return;
    }

    await syncToServer();
  }

  /// Sync unsynced activities to server
  Future<bool> syncToServer() async {
    if (_isSyncing) return false;

    try {
      _isSyncing = true;

      // Get unsynced activities
      final unsynced = await ActivityDatabase.getUnsyncedActivities();
      if (unsynced.isEmpty) {
        debugPrint('No activities to sync');
        _unsyncedCount = 0;
        return true;
      }

      debugPrint('Syncing ${unsynced.length} activities to server...');

      // Try batch sync first
      final response = await _apiService.batchSync(unsynced);

      if (response.success && response.data != null) {
        // Mark as synced with server IDs
        final localIds = unsynced.map((a) => a.id!).toList();
        await ActivityDatabase.markAsSynced(localIds, response.data!);

        _unsyncedCount = 0;
        debugPrint('Successfully synced ${unsynced.length} activities');
        return true;
      } else {
        debugPrint('Batch sync failed: ${response.error}');
        debugPrint('Falling back to individual sync...');

        // Fallback: sync activities one by one
        int successCount = 0;
        for (final activity in unsynced) {
          try {
            final individualResponse = await _apiService.createActivity(
              activity,
            );
            if (individualResponse.success && individualResponse.data != null) {
              // Mark this one as synced
              await ActivityDatabase.markAsSynced(
                [activity.id!],
                [individualResponse.data!.serverId!],
              );
              successCount++;
            }
          } catch (e) {
            debugPrint('Failed to sync activity ${activity.id}: $e');
          }
        }

        _unsyncedCount = await ActivityDatabase.getUnsyncedCount();
        debugPrint(
          'Individual sync completed: $successCount/${unsynced.length} successful',
        );
        return successCount > 0;
      }
    } catch (e) {
      debugPrint('Sync error: $e');
      return false;
    } finally {
      _isSyncing = false;
    }
  }

  /// Pull activities from server and merge with local
  Future<bool> pullFromServer() async {
    try {
      // Check if authenticated
      if (!await _apiService.isAuthenticated()) {
        debugPrint('Not authenticated, skipping pull');
        return false;
      }

      debugPrint('Pulling activities from server...');

      final response = await _apiService.getActivities(limit: 50);

      if (response.success && response.data != null) {
        await ActivityDatabase.mergeServerActivities(response.data!);
        debugPrint('Merged ${response.data!.length} activities from server');
        return true;
      } else {
        debugPrint('Pull failed: ${response.error}');
        return false;
      }
    } catch (e) {
      debugPrint('Pull error: $e');
      return false;
    }
  }

  /// Full sync (push then pull)
  Future<void> fullSync() async {
    await syncToServer();
    await pullFromServer();
  }

  /// Get all activities from local database
  Future<List<RecentActivityModel>> getActivities({
    int? limit,
    String? activityType,
  }) async {
    return await ActivityDatabase.getAllActivities(
      limit: limit,
      activityType: activityType,
    );
  }

  /// Delete activity (local and server)
  Future<bool> deleteActivity(int localId, int? serverId) async {
    try {
      // Delete from local
      await ActivityDatabase.deleteActivity(localId);

      // Delete from server if synced
      if (serverId != null) {
        final response = await _apiService.deleteActivity(serverId);
        if (!response.success) {
          debugPrint('Failed to delete from server: ${response.error}');
          // Don't fail - local deletion succeeded
        }
      }

      return true;
    } catch (e) {
      debugPrint('Delete error: $e');
      return false;
    }
  }

  /// Clear all activities (local and server)
  Future<bool> clearAll() async {
    try {
      // Clear local
      await ActivityDatabase.clearAll();

      // Clear server if authenticated
      if (await _apiService.isAuthenticated()) {
        final response = await _apiService.clearAll();
        if (!response.success) {
          debugPrint('Failed to clear server: ${response.error}');
        }
      }

      _unsyncedCount = 0;
      return true;
    } catch (e) {
      debugPrint('Clear error: $e');
      return false;
    }
  }

  /// Get unsynced count
  int get unsyncedCount => _unsyncedCount;

  /// Check if syncing
  bool get isSyncing => _isSyncing;

  /// Dispose resources
  void dispose() {
    stopAutoSync();
  }
}

/// Global instance for easy access
final activityManager = ActivitySyncManager();
