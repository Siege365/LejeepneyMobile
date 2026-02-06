import 'package:intl/intl.dart';

/// Types of activities that can be tracked
enum ActivityType {
  routeCalculated,
  fareCalculated,
  locationSearch,
  routeSaved,
  ticketCreated,
  ticketReplied,
  ticketStatusChanged,
}

/// Model for a recent activity item
class RecentActivity {
  final String id;
  final ActivityType type;
  final String title;
  final String subtitle;
  final DateTime timestamp;
  final Map<String, dynamic>? metadata;

  RecentActivity({
    required this.id,
    required this.type,
    required this.title,
    required this.subtitle,
    required this.timestamp,
    this.metadata,
  });

  /// Convert to JSON for storage
  Map<String, dynamic> toJson() {
    return {
      'id': id,
      'type': type.toString(),
      'title': title,
      'subtitle': subtitle,
      'timestamp': timestamp.toIso8601String(),
      'metadata': metadata,
    };
  }

  /// Create from JSON
  factory RecentActivity.fromJson(Map<String, dynamic> json) {
    return RecentActivity(
      id: json['id'] as String,
      type: ActivityType.values.firstWhere(
        (e) => e.toString() == json['type'],
        orElse: () => ActivityType.routeCalculated,
      ),
      title: json['title'] as String,
      subtitle: json['subtitle'] as String,
      timestamp: DateTime.parse(json['timestamp'] as String),
      metadata: json['metadata'] as Map<String, dynamic>?,
    );
  }

  /// Get icon for activity type
  static int getIconCodePoint(ActivityType type) {
    switch (type) {
      case ActivityType.routeCalculated:
        return 0xe548; // Icons.route
      case ActivityType.fareCalculated:
        return 0xe1d9; // Icons.calculate
      case ActivityType.locationSearch:
        return 0xe567; // Icons.search
      case ActivityType.routeSaved:
        return 0xe866; // Icons.bookmark
      case ActivityType.ticketCreated:
        return 0xe163; // Icons.add_box
      case ActivityType.ticketReplied:
        return 0xe0ca; // Icons.chat_bubble
      case ActivityType.ticketStatusChanged:
        return 0xe86c; // Icons.update
    }
  }

  /// Format timestamp for display
  String get formattedTime {
    final now = DateTime.now();
    final difference = now.difference(timestamp);

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
      return DateFormat('MMM dd, yyyy').format(timestamp);
    }
  }

  /// Format date header (e.g., "Today", "Yesterday", "July 18, 2024")
  String get dateHeader {
    final now = DateTime.now();
    final today = DateTime(now.year, now.month, now.day);
    final activityDate = DateTime(
      timestamp.year,
      timestamp.month,
      timestamp.day,
    );
    final difference = today.difference(activityDate).inDays;

    if (difference == 0) {
      return 'Today';
    } else if (difference == 1) {
      return 'Yesterday';
    } else if (difference < 7) {
      return DateFormat('EEEE').format(timestamp); // Day name
    } else {
      return DateFormat('MMMM dd, yyyy').format(timestamp);
    }
  }

  /// Short date for compact display (e.g., "Jul 18")
  String get shortDate {
    return DateFormat('MMM dd').format(timestamp);
  }
}
