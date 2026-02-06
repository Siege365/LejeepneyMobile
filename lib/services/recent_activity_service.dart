import 'dart:convert';
import 'package:flutter/foundation.dart';
import 'package:shared_preferences/shared_preferences.dart';
import '../models/recent_activity.dart';

/// Service for tracking and managing user's recent activities
/// Works for both guest and logged-in users (stored locally)
class RecentActivityService {
  static const String _keyPrefix = 'recent_activities';
  static const int _maxActivities = 50; // Keep last 50 activities

  /// Get storage key based on user ID (null for guest)
  static String _getStorageKey(String? userId) {
    return userId != null ? '${_keyPrefix}_$userId' : '${_keyPrefix}_guest';
  }

  /// Add a route calculation activity
  static Future<void> addRouteCalculation({
    required String? userId,
    required String fromLocation,
    required String toLocation,
    String? routeNames,
    double? fare,
  }) async {
    final subtitle = routeNames != null && routeNames.isNotEmpty
        ? '$fromLocation → $toLocation via $routeNames'
        : '$fromLocation → $toLocation';

    await _addActivity(
      userId: userId,
      activity: RecentActivity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ActivityType.routeCalculated,
        title: 'Route Calculated',
        subtitle: subtitle,
        timestamp: DateTime.now(),
        metadata: {
          'from': fromLocation,
          'to': toLocation,
          'routes': routeNames,
          'fare': fare,
        },
      ),
    );
  }

  /// Add a fare calculation activity
  static Future<void> addFareCalculation({
    required String? userId,
    required String fromLocation,
    required String toLocation,
    required double fare,
    String? routeName,
  }) async {
    final subtitle = routeName != null
        ? '₱${fare.toStringAsFixed(2)} - $routeName'
        : '₱${fare.toStringAsFixed(2)}';

    await _addActivity(
      userId: userId,
      activity: RecentActivity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ActivityType.fareCalculated,
        title: 'Fare Calculated',
        subtitle: subtitle,
        timestamp: DateTime.now(),
        metadata: {
          'from': fromLocation,
          'to': toLocation,
          'fare': fare,
          'route': routeName,
        },
      ),
    );
  }

  /// Add a location search activity
  static Future<void> addLocationSearch({
    required String? userId,
    required String searchQuery,
    String? resultName,
  }) async {
    final subtitle = resultName != null
        ? 'Searched for "$searchQuery" → $resultName'
        : 'Searched for "$searchQuery"';

    await _addActivity(
      userId: userId,
      activity: RecentActivity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ActivityType.locationSearch,
        title: 'Location Search',
        subtitle: subtitle,
        timestamp: DateTime.now(),
        metadata: {'query': searchQuery, 'result': resultName},
      ),
    );
  }

  /// Add a route saved activity
  static Future<void> addRouteSaved({
    required String? userId,
    required String routeName,
    String? fromLocation,
    String? toLocation,
  }) async {
    final subtitle = fromLocation != null && toLocation != null
        ? '$fromLocation → $toLocation'
        : routeName;

    await _addActivity(
      userId: userId,
      activity: RecentActivity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ActivityType.routeSaved,
        title: 'Route Saved',
        subtitle: subtitle,
        timestamp: DateTime.now(),
        metadata: {
          'routeName': routeName,
          'from': fromLocation,
          'to': toLocation,
        },
      ),
    );
  }

  /// Add a ticket created activity
  static Future<void> addTicketCreated({
    required String? userId,
    required int ticketId,
    required String subject,
    String? ticketType,
  }) async {
    final subtitle = 'Ticket #$ticketId - $subject';

    await _addActivity(
      userId: userId,
      activity: RecentActivity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ActivityType.ticketCreated,
        title: 'Support Ticket Created',
        subtitle: subtitle,
        timestamp: DateTime.now(),
        metadata: {
          'ticketId': ticketId,
          'subject': subject,
          'type': ticketType,
        },
      ),
    );
  }

  /// Add a ticket replied activity
  static Future<void> addTicketReplied({
    required String? userId,
    required int ticketId,
    required String subject,
    required bool isUserReply,
  }) async {
    final subtitle = isUserReply
        ? 'You replied to Ticket #$ticketId'
        : 'Admin replied to Ticket #$ticketId';

    await _addActivity(
      userId: userId,
      activity: RecentActivity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ActivityType.ticketReplied,
        title: 'Ticket Conversation',
        subtitle: subtitle,
        timestamp: DateTime.now(),
        metadata: {
          'ticketId': ticketId,
          'subject': subject,
          'isUserReply': isUserReply,
        },
      ),
    );
  }

  /// Add a ticket status changed activity
  static Future<void> addTicketStatusChanged({
    required String? userId,
    required int ticketId,
    required String subject,
    required String newStatus,
  }) async {
    final subtitle = 'Ticket #$ticketId status: $newStatus';

    await _addActivity(
      userId: userId,
      activity: RecentActivity(
        id: DateTime.now().millisecondsSinceEpoch.toString(),
        type: ActivityType.ticketStatusChanged,
        title: 'Ticket Status Updated',
        subtitle: subtitle,
        timestamp: DateTime.now(),
        metadata: {
          'ticketId': ticketId,
          'subject': subject,
          'newStatus': newStatus,
        },
      ),
    );
  }

  /// Get all activities for a user
  static Future<List<RecentActivity>> getActivities(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(userId);
      final jsonString = prefs.getString(key);

      if (jsonString == null || jsonString.isEmpty) {
        return [];
      }

      final List<dynamic> jsonList = json.decode(jsonString);
      final activities = jsonList
          .map((json) => RecentActivity.fromJson(json as Map<String, dynamic>))
          .toList();

      // Sort by timestamp (newest first)
      activities.sort((a, b) => b.timestamp.compareTo(a.timestamp));

      return activities;
    } catch (e) {
      debugPrint('Error loading recent activities: $e');
      return [];
    }
  }

  /// Get recent activities (limit to N items)
  static Future<List<RecentActivity>> getRecentActivities(
    String? userId, {
    int limit = 10,
  }) async {
    final activities = await getActivities(userId);
    return activities.take(limit).toList();
  }

  /// Clear all activities for a user
  static Future<void> clearActivities(String? userId) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(userId);
      await prefs.remove(key);
    } catch (e) {
      debugPrint('Error clearing recent activities: $e');
    }
  }

  /// Delete a specific activity
  static Future<void> deleteActivity(String? userId, String activityId) async {
    try {
      final activities = await getActivities(userId);
      activities.removeWhere((activity) => activity.id == activityId);
      await _saveActivities(userId, activities);
    } catch (e) {
      debugPrint('Error deleting activity: $e');
    }
  }

  /// Private method to add an activity
  static Future<void> _addActivity({
    required String? userId,
    required RecentActivity activity,
  }) async {
    try {
      final activities = await getActivities(userId);

      // Add new activity at the beginning
      activities.insert(0, activity);

      // Keep only the most recent activities
      if (activities.length > _maxActivities) {
        activities.removeRange(_maxActivities, activities.length);
      }

      await _saveActivities(userId, activities);
    } catch (e) {
      debugPrint('Error adding activity: $e');
    }
  }

  /// Private method to save activities
  static Future<void> _saveActivities(
    String? userId,
    List<RecentActivity> activities,
  ) async {
    try {
      final prefs = await SharedPreferences.getInstance();
      final key = _getStorageKey(userId);
      final jsonList = activities.map((a) => a.toJson()).toList();
      final jsonString = json.encode(jsonList);
      await prefs.setString(key, jsonString);
    } catch (e) {
      debugPrint('Error saving activities: $e');
    }
  }
}
