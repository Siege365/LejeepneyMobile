import '../models/recent_activity_model.dart';
import 'activity_sync_manager.dart';

/// Unified service for tracking and managing user's recent activities
/// Uses SQLite for local storage and syncs with server when online
class RecentActivityServiceV2 {
  static final ActivitySyncManager _syncManager = ActivitySyncManager();

  /// Initialize the service (call on app start)
  static Future<void> initialize() async {
    await _syncManager.initialize();
  }

  /// Add a route calculation activity
  static Future<void> addRouteCalculation({
    required String fromLocation,
    required String toLocation,
    String? routeNames,
    double? fare,
  }) async {
    final subtitle = routeNames != null && routeNames.isNotEmpty
        ? '$fromLocation → $toLocation via $routeNames'
        : '$fromLocation → $toLocation';

    await _syncManager.track(
      activityType: 'route_calculated',
      title: 'Route Calculated',
      subtitle: subtitle,
      fromLocation: fromLocation,
      toLocation: toLocation,
      routeNames: routeNames,
      fare: fare,
      metadata: {
        'from': fromLocation,
        'to': toLocation,
        'routes': routeNames,
        'fare': fare,
      },
    );
  }

  /// Add a fare calculation activity
  static Future<void> addFareCalculation({
    required String fromLocation,
    required String toLocation,
    required double fare,
    String? routeName,
    double? distance,
  }) async {
    final subtitle = routeName != null
        ? '₱${fare.toStringAsFixed(2)} - $routeName'
        : '₱${fare.toStringAsFixed(2)}';

    await _syncManager.track(
      activityType: 'fare_calculated',
      title: 'Fare Calculated',
      subtitle: subtitle,
      fromLocation: fromLocation,
      toLocation: toLocation,
      routeNames: routeName,
      fare: fare,
      metadata: {
        'from': fromLocation,
        'to': toLocation,
        'fare': fare,
        'route': routeName,
        'distance': distance,
      },
    );
  }

  /// Add a location search activity
  static Future<void> addLocationSearch({
    required String searchQuery,
    String? resultName,
    int? resultsCount,
  }) async {
    final subtitle = resultName != null
        ? 'Searched for "$searchQuery" → $resultName'
        : 'Searched for "$searchQuery"';

    await _syncManager.track(
      activityType: 'location_search',
      title: 'Location Search',
      subtitle: subtitle,
      metadata: {
        'query': searchQuery,
        'result': resultName,
        'results_count': resultsCount,
      },
    );
  }

  /// Add a route saved activity
  static Future<void> addRouteSaved({
    required String routeName,
    String? fromLocation,
    String? toLocation,
    int? routeId,
  }) async {
    final subtitle = fromLocation != null && toLocation != null
        ? '$fromLocation → $toLocation'
        : routeName;

    await _syncManager.track(
      activityType: 'route_saved',
      title: 'Route Saved',
      subtitle: subtitle,
      fromLocation: fromLocation,
      toLocation: toLocation,
      routeNames: routeName,
      metadata: {
        'route_name': routeName,
        'from': fromLocation,
        'to': toLocation,
        'route_id': routeId,
      },
    );
  }

  /// Get all activities from local database
  static Future<List<RecentActivityModel>> getActivities({
    int? limit,
    String? activityType,
  }) async {
    return await _syncManager.getActivities(
      limit: limit,
      activityType: activityType,
    );
  }

  /// Get recent activities (convenience method)
  static Future<List<RecentActivityModel>> getRecentActivities({
    int limit = 10,
  }) async {
    return await _syncManager.getActivities(limit: limit);
  }

  /// Delete a specific activity
  static Future<bool> deleteActivity(int localId, {int? serverId}) async {
    return await _syncManager.deleteActivity(localId, serverId);
  }

  /// Clear all activities
  static Future<bool> clearAll() async {
    return await _syncManager.clearAll();
  }

  /// Sync with server
  static Future<void> sync() async {
    await _syncManager.fullSync();
  }

  /// Trigger push sync to server
  static Future<bool> pushToServer() async {
    return await _syncManager.syncToServer();
  }

  /// Pull from server
  static Future<bool> pullFromServer() async {
    return await _syncManager.pullFromServer();
  }

  /// Get unsynced count
  static int get unsyncedCount => _syncManager.unsyncedCount;

  /// Check if currently syncing
  static bool get isSyncing => _syncManager.isSyncing;

  /// Dispose resources
  static void dispose() {
    _syncManager.dispose();
  }
}
