import 'dart:convert';

/// Activity types that can be tracked
enum ActivityType {
  routeCalculated('route_calculated'),
  fareCalculated('fare_calculated'),
  locationSearch('location_search'),
  routeSaved('route_saved');

  final String value;
  const ActivityType(this.value);

  static ActivityType fromString(String value) {
    return ActivityType.values.firstWhere(
      (e) => e.value == value,
      orElse: () => ActivityType.routeCalculated,
    );
  }
}

/// Model for recent activity - supports both local storage and API sync
class RecentActivityModel {
  final int? id;
  final int? serverId; // ID from server, null if not synced
  final String activityType;
  final String title;
  final String? subtitle;
  final String? fromLocation;
  final String? toLocation;
  final String? routeNames;
  final double? fare;
  final Map<String, dynamic>? metadata;
  final DateTime createdAt;
  final bool isSynced;

  RecentActivityModel({
    this.id,
    this.serverId,
    required this.activityType,
    required this.title,
    this.subtitle,
    this.fromLocation,
    this.toLocation,
    this.routeNames,
    this.fare,
    this.metadata,
    required this.createdAt,
    this.isSynced = false,
  });

  /// Create from JSON (API response)
  factory RecentActivityModel.fromJson(Map<String, dynamic> json) {
    // Helper to safely parse int
    int? safeParseInt(dynamic value) {
      if (value == null) return null;
      if (value is int) return value;
      if (value is String) return int.tryParse(value);
      if (value is num) return value.toInt();
      return null;
    }

    // Helper to safely parse double
    double? safeParseDouble(dynamic value) {
      if (value == null) return null;
      if (value is double) return value;
      if (value is int) return value.toDouble();
      if (value is String) return double.tryParse(value);
      if (value is num) return value.toDouble();
      return null;
    }

    return RecentActivityModel(
      id: safeParseInt(json['local_id']),
      serverId: safeParseInt(json['id']),
      activityType: json['activity_type'] as String,
      title: json['title'] as String,
      subtitle: json['subtitle'] as String?,
      fromLocation: json['from_location'] as String?,
      toLocation: json['to_location'] as String?,
      routeNames: json['route_names'] as String?,
      fare: safeParseDouble(json['fare']),
      metadata: json['metadata'] is String
          ? jsonDecode(json['metadata'])
          : json['metadata'] as Map<String, dynamic>?,
      createdAt: json['created_at'] != null
          ? DateTime.parse(json['created_at'])
          : DateTime.now(),
      isSynced: json['is_synced'] == 1 || json['is_synced'] == true,
    );
  }

  /// Convert to JSON (for API)
  Map<String, dynamic> toJson() {
    return {
      'activity_type': activityType,
      'title': title,
      'subtitle': subtitle,
      'from_location': fromLocation,
      'to_location': toLocation,
      'route_names': routeNames,
      'fare': fare,
      'metadata': metadata,
      'created_at': createdAt.toIso8601String(),
    };
  }

  /// Convert to SQLite map (for local storage)
  Map<String, dynamic> toSqlite() {
    return {
      'server_id': serverId,
      'activity_type': activityType,
      'title': title,
      'subtitle': subtitle,
      'from_location': fromLocation,
      'to_location': toLocation,
      'route_names': routeNames,
      'fare': fare,
      'metadata': metadata != null ? jsonEncode(metadata) : null,
      'created_at': createdAt.millisecondsSinceEpoch,
      'is_synced': isSynced ? 1 : 0,
    };
  }

  /// Create from SQLite row
  factory RecentActivityModel.fromSqlite(Map<String, dynamic> row) {
    return RecentActivityModel(
      id: row['id'] as int?,
      serverId: row['server_id'] as int?,
      activityType: row['activity_type'] as String,
      title: row['title'] as String,
      subtitle: row['subtitle'] as String?,
      fromLocation: row['from_location'] as String?,
      toLocation: row['to_location'] as String?,
      routeNames: row['route_names'] as String?,
      fare: row['fare'] != null ? (row['fare'] as num).toDouble() : null,
      metadata: row['metadata'] != null
          ? jsonDecode(row['metadata'] as String)
          : null,
      createdAt: DateTime.fromMillisecondsSinceEpoch(row['created_at'] as int),
      isSynced: row['is_synced'] == 1,
    );
  }

  /// Copy with modifications
  RecentActivityModel copyWith({
    int? id,
    int? serverId,
    String? activityType,
    String? title,
    String? subtitle,
    String? fromLocation,
    String? toLocation,
    String? routeNames,
    double? fare,
    Map<String, dynamic>? metadata,
    DateTime? createdAt,
    bool? isSynced,
  }) {
    return RecentActivityModel(
      id: id ?? this.id,
      serverId: serverId ?? this.serverId,
      activityType: activityType ?? this.activityType,
      title: title ?? this.title,
      subtitle: subtitle ?? this.subtitle,
      fromLocation: fromLocation ?? this.fromLocation,
      toLocation: toLocation ?? this.toLocation,
      routeNames: routeNames ?? this.routeNames,
      fare: fare ?? this.fare,
      metadata: metadata ?? this.metadata,
      createdAt: createdAt ?? this.createdAt,
      isSynced: isSynced ?? this.isSynced,
    );
  }

  /// Get formatted time (e.g., "2h ago", "Yesterday")
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(createdAt);

    if (difference.inMinutes < 1) {
      return 'Just now';
    } else if (difference.inMinutes < 60) {
      return '${difference.inMinutes}m ago';
    } else if (difference.inHours < 24) {
      return '${difference.inHours}h ago';
    } else if (difference.inDays == 1) {
      return 'Yesterday';
    } else if (difference.inDays < 7) {
      return '${difference.inDays}d ago';
    } else {
      return '${createdAt.month}/${createdAt.day}/${createdAt.year}';
    }
  }

  /// Get date header (e.g., "Today", "Yesterday", "This Week")
  String get dateHeader {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activityDate = DateTime(
      createdAt.year,
      createdAt.month,
      createdAt.day,
    );
    final difference = today.difference(activityDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return 'This Week';
    } else if (difference < 30) {
      return 'This Month';
    } else {
      return 'Earlier';
    }
  }

  /// Get short date for compact display
  String get shortDate {
    final months = [
      'Jan',
      'Feb',
      'Mar',
      'Apr',
      'May',
      'Jun',
      'Jul',
      'Aug',
      'Sep',
      'Oct',
      'Nov',
      'Dec',
    ];
    return '${months[createdAt.month - 1]} ${createdAt.day}';
  }

  /// Get icon code point for activity type
  static int getIconCodePoint(String type) {
    switch (type) {
      case 'route_calculated':
        return 0xe548; // Icons.route
      case 'fare_calculated':
        return 0xe1d9; // Icons.calculate
      case 'location_search':
        return 0xe567; // Icons.search
      case 'route_saved':
        return 0xe866; // Icons.bookmark
      case 'support_ticket':
      case 'customer_service':
        return 0xe0e1; // Icons.confirmation_number (ticket icon)
      default:
        return 0xe889; // Icons.history
    }
  }
}
